import hashlib
from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from . import models as m


@override_settings(
    APNS_ENABLED=True,
    APNS_TEAM_ID="TEAM",
    APNS_KEY_ID="KEY",
    APNS_KEY_PATH="test-only.p8",
    APNS_TOPIC="de.campuszeit.students",
    APNS_ENVIRONMENT="sandbox",
)
class StudentPushTests(TestCase):
    def setUp(self):
        self.institution = m.Institution.objects.create(name="Campus", slug="campus")
        program = m.Program.objects.create(
            institution=self.institution, code="P", name="P"
        )
        self.cohort = m.Cohort.objects.create(
            institution=self.institution, program=program, code="C", name="C"
        )
        self.group = m.Group.objects.create(
            institution=self.institution, cohort=self.cohort, code="G", name="G"
        )
        self.access = m.StudentAccess.objects.create(
            institution=self.institution, group=self.group, code="access"
        )
        self.session = m.StudentDeviceSession.objects.create(
            access=self.access,
            token_hash=hashlib.sha256(b"test-bearer").hexdigest(),
            expires=timezone.now() + timedelta(days=1),
        )
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION="Bearer test-bearer")

    def register(self, token="ab" * 32):
        return self.client.post(
            "/api/student-app/v1/push/",
            {
                "token": token,
                "environment": "sandbox",
                "topic": "de.campuszeit.students",
            },
            format="json",
        )

    def notice(self, **scope):
        return m.StudentNotice.objects.create(
            institution=self.institution, title="Test", body="Private details", **scope
        )

    def test_registration_is_authenticated_validated_and_idempotent(self):
        self.client.credentials()
        self.assertEqual(self.register().status_code, 401)
        self.client.credentials(HTTP_AUTHORIZATION="Bearer test-bearer")
        for token in ("not-a-token", "a" * 63, "a" * 514):
            self.assertEqual(self.register(token).status_code, 400)
        result = self.register()
        self.assertEqual(result.status_code, 200)
        self.assertEqual(self.register().data, result.data)
        self.session.refresh_from_db()
        self.assertEqual(self.session.push_token, "ab" * 32)
        self.assertNotIn(self.session.push_token, str(result.data))
        self.assertEqual(
            self.client.delete("/api/student-app/v1/push/").status_code, 204
        )
        self.session.refresh_from_db()
        self.assertIsNone(self.session.push_token)

    @override_settings(APNS_ENABLED=False)
    def test_disabled_server_does_not_claim_push_is_ready(self):
        self.assertEqual(self.register().status_code, 503)

    def test_queue_matches_feed_audience_and_never_backfills_old_notices(self):
        from .student_push import queue_notice_push

        self.notice()
        self.register()
        self.assertFalse(m.StudentPushDelivery.objects.exists())
        notice = self.notice(group=self.group)
        queue_notice_push(notice)
        queue_notice_push(notice)
        self.assertEqual(m.StudentPushDelivery.objects.count(), 1)
        other = m.Group.objects.create(
            institution=self.institution, cohort=self.cohort, code="G2", name="G2"
        )
        queue_notice_push(self.notice(group=other))
        self.assertEqual(m.StudentPushDelivery.objects.count(), 1)
        queue_notice_push(self.notice(cohort=self.cohort))
        queue_notice_push(self.notice())
        self.assertEqual(m.StudentPushDelivery.objects.count(), 3)
        foreign = m.Institution.objects.create(name="Other", slug="other")
        queue_notice_push(
            m.StudentNotice.objects.create(institution=foreign, title="Other")
        )
        self.assertEqual(m.StudentPushDelivery.objects.count(), 3)
        self.session.expires = timezone.now() - timedelta(seconds=1)
        self.session.save()
        queue_notice_push(self.notice())
        self.assertEqual(m.StudentPushDelivery.objects.count(), 3)

    def test_group_notice_also_reaches_its_cohort_access(self):
        from .student_push import queue_notice_push

        self.register()
        access = m.StudentAccess.objects.create(
            institution=self.institution, cohort=self.cohort, code="cohort-access"
        )
        cohort_device = m.StudentDeviceSession.objects.create(
            access=access,
            token_hash="cohort-token-hash",
            push_token="cd" * 32,
            expires=timezone.now() + timedelta(days=1),
        )
        queue_notice_push(self.notice(group=self.group))
        self.assertEqual(
            set(m.StudentPushDelivery.objects.values_list("device_id", flat=True)),
            {self.session.id, cohort_device.id},
        )

    def test_rotation_revocation_and_withdrawal_suppress_queued_pushes(self):
        from .student_push import deliver_pending_pushes, queue_notice_push

        self.register()
        notice = self.notice()
        queue_notice_push(notice)
        self.register("cd" * 32)
        with patch("planner.student_push.send_apns") as send:
            deliver_pending_pushes()
            send.assert_not_called()
        withdrawn = self.notice()
        queue_notice_push(withdrawn)
        withdrawn.active = False
        withdrawn.save()
        with patch("planner.student_push.send_apns") as send:
            deliver_pending_pushes()
            send.assert_not_called()
        queue_notice_push(self.notice())
        self.access.active = False
        self.access.save()
        with patch("planner.student_push.send_apns") as send:
            deliver_pending_pushes()
            send.assert_not_called()

    def test_token_moves_to_latest_session_and_logout_deletes_deliveries(self):
        from .student_push import queue_notice_push

        self.register()
        previous = self.session.push_binding
        queue_notice_push(self.notice())
        second = m.StudentDeviceSession.objects.create(
            access=self.access,
            token_hash=hashlib.sha256(b"second").hexdigest(),
            expires=timezone.now() + timedelta(days=1),
        )
        self.client.credentials(HTTP_AUTHORIZATION="Bearer second")
        self.assertEqual(self.register().status_code, 200)
        self.session.refresh_from_db()
        second.refresh_from_db()
        self.assertIsNone(self.session.push_token)
        self.assertNotEqual(second.push_binding, previous)
        queue_notice_push(self.notice())
        self.client.post("/api/student-app/v1/logout/")
        self.assertFalse(m.StudentPushDelivery.objects.filter(device=second).exists())

    def test_registration_rejects_wrong_environment_and_topic(self):
        for environment, topic in (
            ("production", "de.campuszeit.students"),
            ("sandbox", "other.app"),
        ):
            response = self.client.post(
                "/api/student-app/v1/push/",
                {
                    "token": "ab" * 32,
                    "environment": environment,
                    "topic": topic,
                },
                format="json",
            )
            self.assertEqual(response.status_code, 400)
        self.session.refresh_from_db()
        self.assertIsNone(self.session.push_token)

    def test_queued_delivery_rolls_back_with_notice(self):
        from django.db import transaction

        from .student_push import queue_notice_push

        self.register()
        with transaction.atomic():
            queue_notice_push(self.notice())
            self.assertEqual(m.StudentPushDelivery.objects.count(), 1)
            transaction.set_rollback(True)
        self.assertFalse(m.StudentPushDelivery.objects.exists())
        self.assertFalse(m.StudentNotice.objects.exists())

    def test_apns_request_uses_es256_and_contains_no_private_message(self):
        import json
        import tempfile
        from pathlib import Path

        import httpx
        import jwt
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric import ec

        from .student_push import provider_token, queue_notice_push, send_apns

        self.register()
        queue_notice_push(self.notice())
        delivery = m.StudentPushDelivery.objects.select_related(
            "device", "notice"
        ).get()
        private_key = ec.generate_private_key(ec.SECP256R1())

        def apple(request):
            self.assertEqual(request.url.host, "api.sandbox.push.apple.com")
            self.assertEqual(request.headers["apns-topic"], "de.campuszeit.students")
            self.assertEqual(request.headers["apns-push-type"], "alert")
            signed = request.headers["authorization"].removeprefix("bearer ")
            self.assertEqual(jwt.get_unverified_header(signed)["kid"], "KEY")
            claims = jwt.decode(signed, private_key.public_key(), algorithms=["ES256"])
            self.assertEqual(claims["iss"], "TEAM")
            payload = json.loads(request.content)
            self.assertEqual(payload["binding"], str(delivery.binding))
            self.assertEqual(payload["notice_id"], delivery.notice_id)
            self.assertNotIn("Private details", request.content.decode())
            self.assertLess(len(request.content), 4096)
            return httpx.Response(200)

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.p8"
            path.write_bytes(
                private_key.private_bytes(
                    serialization.Encoding.PEM,
                    serialization.PrivateFormat.PKCS8,
                    serialization.NoEncryption(),
                )
            )
            with (
                override_settings(APNS_KEY_PATH=str(path)),
                httpx.Client(transport=httpx.MockTransport(apple)) as client,
            ):
                self.assertEqual(send_apns(client, delivery), (200, ""))
        provider_token.cache_clear()

    def test_transient_error_retries_and_success_is_not_sent_twice(self):
        from .student_push import deliver_pending_pushes, queue_notice_push

        self.register()
        queue_notice_push(self.notice())
        with patch(
            "planner.student_push.send_apns", return_value=(503, "ServiceUnavailable")
        ):
            deliver_pending_pushes()
        delivery = m.StudentPushDelivery.objects.get()
        self.assertEqual(delivery.attempts, 1)
        self.assertIsNone(delivery.finished)
        self.assertGreater(delivery.next_attempt, timezone.now())
        m.StudentPushDelivery.objects.update(next_attempt=timezone.now())
        with patch("planner.student_push.send_apns", return_value=(200, "")) as send:
            deliver_pending_pushes()
            deliver_pending_pushes()
            self.assertEqual(send.call_count, 1)
        delivery.refresh_from_db()
        self.assertIsNotNone(delivery.finished)
        self.assertEqual(delivery.result, "accepted")

    def test_invalid_token_is_removed_without_logging_secrets(self):
        from .student_push import deliver_pending_pushes, queue_notice_push

        self.register()
        queue_notice_push(self.notice())
        with patch(
            "planner.student_push.send_apns", return_value=(410, "Unregistered")
        ):
            deliver_pending_pushes()
        self.session.refresh_from_db()
        self.assertIsNone(self.session.push_token)
        self.assertEqual(m.StudentPushDelivery.objects.get().result, "Unregistered")

    def test_network_failure_is_bounded_and_does_not_lose_the_notice(self):
        import httpx

        from .student_push import deliver_pending_pushes, queue_notice_push

        self.register()
        queue_notice_push(self.notice())
        m.StudentPushDelivery.objects.update(attempts=7)
        with patch(
            "planner.student_push.send_apns", side_effect=httpx.ConnectError("offline")
        ):
            deliver_pending_pushes()
        delivery = m.StudentPushDelivery.objects.get()
        self.assertEqual(delivery.attempts, 8)
        self.assertIsNotNone(delivery.finished)
        self.assertTrue(delivery.notice.active)
        self.assertEqual(delivery.result, "TransportOrConfigurationError")
