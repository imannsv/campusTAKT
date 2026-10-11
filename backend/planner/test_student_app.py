import io
import json
from datetime import timedelta

from django.core.cache import cache
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from . import models as m


@override_settings(DEBUG=True)
class StudentAppTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed_demo", password="TestCampuszeit2026!", stdout=io.StringIO())
        cls.group = m.Group.objects.get(code="A1")
        cls.other = m.Group.objects.get(code="A2")
        cls.institution = cls.group.institution
        cls.admin = m.Membership.objects.get(institution=cls.institution).user

    def setUp(self):
        cache.clear()
        self.manager = APIClient()
        self.manager.force_authenticate(self.admin)
        self.client = APIClient()
        self.credentials = self.create_access(group=self.group.id)

    def create_access(self, **scope):
        response = self.manager.post(
            "/api/student-app/accesses/",
            {"server": "https://campus.example.org", **scope},
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def sign_in(self, credentials=None, qr=False):
        credentials = credentials or self.credentials
        payload = (
            json.loads(credentials["qr_payload"])
            if qr
            else {"code": credentials["code"], "password": credentials["password"]}
        )
        if qr:
            payload = {key: payload[key] for key in ("access", "key")}
        response = self.client.post(
            "/api/student-app/v1/login/", payload, format="json"
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + response.data["token"])
        return response.data

    def feed(self, **extra):
        return self.client.get(
            "/api/student-app/v1/feed/",
            {"start": "2026-10-01", "end": "2026-11-01", **extra},
        )

    def test_manual_and_qr_login_store_only_hashes_and_no_admin_permissions(self):
        manual = self.sign_in()
        access = m.StudentAccess.objects.get(pk=self.credentials["id"])
        self.assertNotIn(self.credentials["password"], access.password_hash)
        self.assertNotEqual(
            m.StudentDeviceSession.objects.first().token_hash, manual["token"]
        )
        self.assertTrue(self.credentials["qr_svg"].startswith("<?xml"))
        self.assertEqual(self.client.get("/api/bootstrap/").status_code, 403)
        self.assertEqual(
            self.client.post(
                "/api/student-app/notices/", {"title": "No"}, format="json"
            ).status_code,
            403,
        )
        self.sign_in(qr=True)
        self.assertEqual(m.StudentDeviceSession.objects.count(), 2)

    def test_scope_cannot_be_changed_and_private_data_is_absent(self):
        self.sign_in()
        response = self.feed(group=self.other.id)
        self.assertEqual(response.status_code, 200)
        names = {row["name"] for row in response.data["rows"]}
        self.assertIn("Programmierung · A1", names)
        self.assertNotIn("Programmierung · A2", names)
        self.assertIn("Mathematik I", names)
        serialized = json.dumps(response.data, default=str)
        for private in (
            "learner_ids",
            "password_hash",
            "qr_hash",
            "overview_scope",
            "room_allocations",
        ):
            self.assertNotIn(private, serialized)
        for person in m.Person.objects.filter(kind="learner"):
            self.assertNotIn(person.name, serialized)

    def test_only_published_data_but_live_cancellations(self):
        self.sign_in()
        before = self.feed().data["rows"]
        session = m.Session.objects.filter(course__name="Programmierung · A1").first()
        session.name = "Noch nicht veröffentlicht"
        session.cancelled = True
        session.save()
        after = self.feed().data["rows"]
        self.assertEqual(
            [row["name"] for row in before], [row["name"] for row in after]
        )
        self.assertTrue(
            next(row for row in after if row["id"].endswith(f":{session.id}"))[
                "cancelled"
            ]
        )

    def test_cohort_access_and_notice_audiences(self):
        cohort = self.create_access(cohort=self.group.cohort_id)
        for title, scope in [
            ("Alle", {}),
            ("Jahrgang", {"cohort": self.group.cohort_id}),
            ("A1", {"group": self.group.id}),
            ("A2", {"group": self.other.id}),
        ]:
            self.assertEqual(
                self.manager.post(
                    "/api/student-app/notices/",
                    {"title": title, "body": "Hinweis", **scope},
                    format="json",
                ).status_code,
                201,
            )
        self.sign_in()
        self.assertEqual(
            {row["title"] for row in self.feed().data["notices"]},
            {"Alle", "Jahrgang", "A1"},
        )
        notice = m.StudentNotice.objects.get(title="A1")
        self.manager.post(f"/api/student-app/notices/{notice.id}/withdraw/")
        self.assertNotIn("A1", {row["title"] for row in self.feed().data["notices"]})
        self.sign_in(cohort)
        self.assertIn(
            "Programmierung · A2", {row["name"] for row in self.feed().data["rows"]}
        )

    def test_disable_expiry_and_logout_revoke_sessions(self):
        self.sign_in()
        self.client.post("/api/student-app/v1/logout/")
        self.assertEqual(self.feed().status_code, 401)
        self.sign_in(qr=True)
        m.StudentDeviceSession.objects.update(
            expires=timezone.now() - timedelta(seconds=1)
        )
        self.assertEqual(self.feed().status_code, 401)
        self.sign_in()
        self.manager.post(
            f"/api/student-app/accesses/{self.credentials['id']}/disable/"
        )
        self.assertEqual(self.feed().status_code, 401)
        self.client.credentials()
        response = self.client.post(
            "/api/student-app/v1/login/",
            {
                "code": self.credentials["code"],
                "password": self.credentials["password"],
            },
            format="json",
        )
        self.assertEqual(response.status_code, 401)

    def test_invalid_scope_dates_credentials_and_tenant_isolation(self):
        foreign = m.Institution.objects.create(name="Fremd", slug="fremd")
        program = m.Program.objects.create(institution=foreign, name="Fremd", code="F")
        cohort = m.Cohort.objects.create(
            institution=foreign, program=program, name="Fremd", code="F"
        )
        response = self.manager.post(
            "/api/student-app/accesses/",
            {"server": "https://campus.example.org", "cohort": cohort.id},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        response = self.client.post(
            "/api/student-app/v1/login/",
            {"code": self.credentials["code"], "password": "falsch"},
            format="json",
        )
        self.assertEqual(response.status_code, 401)
        self.sign_in()
        self.assertEqual(self.feed(start="nicht-ein-datum").status_code, 400)
        self.assertEqual(self.feed(end="2027-12-01").status_code, 400)
        listing = str(self.manager.get("/api/student-app/accesses/").data)
        self.assertNotIn(self.credentials["password"], listing)
        self.assertNotIn("qr_payload", listing)

    def test_freddy_recognizes_student_app_without_secrets(self):
        response = self.manager.get("/api/campusai/context/", {"page": "student-app"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["view"]["label"], "Studierenden-App")
        self.assertNotIn(self.credentials["password"], str(response.data))
