import json
from datetime import datetime

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from . import models as m
from .services import attendance, plan_rows


class LearnerAdministrationTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.institution = m.Institution.objects.create(
            name="Testhochschule", slug="learners"
        )
        cls.user = get_user_model().objects.create_user("learner-manager")
        m.Membership.objects.create(user=cls.user, institution=cls.institution)
        cls.program = cls.make(m.Program, "PROGRAM")
        cls.cohort = cls.make(m.Cohort, "2026", program=cls.program, entry_year=2026)
        cls.other_cohort = cls.make(
            m.Cohort, "2025", program=cls.program, entry_year=2025
        )
        cls.group = cls.make(m.Group, "A1", cohort=cls.cohort, size=10)
        cls.second_group = cls.make(m.Group, "A2", cohort=cls.cohort, size=12)
        cls.other_group = cls.make(m.Group, "B1", cohort=cls.other_cohort)

    @classmethod
    def make(cls, model, code, **values):
        return model.objects.create(
            institution=cls.institution, code=code, name=code, **values
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def learner(self, code, *groups):
        person = self.make(m.Person, code, kind="learner")
        person.groups.set(groups)
        return person

    def test_assistant_context_accepts_learner_administration(self):
        response = self.client.get("/api/campusai/context/?page=learners")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["view"]["label"], "Schüler & Studierende")
        self.assertIn(
            "learners", [action["id"] for action in response.data["proactive"]["actions"]]
        )

    def test_create_edit_assign_multiple_groups_and_remove_assignment(self):
        response = self.client.post(
            "/api/people/",
            {
                "code": "STUDENT-01",
                "name": "Alex Beispiel",
                "kind": "learner",
                "groups": [self.group.id],
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.data)
        person = m.Person.objects.get(pk=response.data["id"])
        self.assertEqual(person.institution, self.institution)
        response = self.client.patch(
            f"/api/people/{person.id}/",
            {
                "name": "Alex Neuer Name",
                "groups": [self.group.id, self.second_group.id],
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(
            set(response.data["groups"]), {self.group.id, self.second_group.id}
        )
        response = self.client.patch(
            f"/api/people/{person.id}/", {"groups": []}, format="json"
        )
        self.assertEqual(response.status_code, 200, response.data)
        person.refresh_from_db()
        self.assertEqual(person.name, "Alex Neuer Name")
        self.assertFalse(person.groups.exists())
        self.group.refresh_from_db()
        self.assertEqual(self.group.size, 10)
        self.institution.refresh_from_db()
        self.assertEqual(self.institution.revision, 3)

    def test_same_name_allowed_but_duplicate_code_rejected(self):
        for code, status in [("SAME-1", 201), ("SAME-2", 201), ("SAME-1", 400)]:
            response = self.client.post(
                "/api/people/",
                {"code": code, "name": "Alex Beispiel", "kind": "learner"},
                format="json",
            )
            self.assertEqual(response.status_code, status, response.data)
        self.assertEqual(m.Person.objects.filter(name="Alex Beispiel").count(), 2)

    def test_group_assignment_and_records_are_tenant_isolated(self):
        other = m.Institution.objects.create(
            name="Andere Einrichtung", slug="other-learners"
        )
        program = m.Program.objects.create(institution=other, code="P", name="Andere")
        cohort = m.Cohort.objects.create(
            institution=other, code="C", name="Andere", program=program
        )
        group = m.Group.objects.create(
            institution=other, code="G", name="Andere", cohort=cohort
        )
        private = m.Person.objects.create(
            institution=other, code="PRIVATE", name="Fremde Person"
        )
        person = self.learner("LOCAL", self.group)
        response = self.client.patch(
            f"/api/people/{person.id}/", {"groups": [group.id]}, format="json"
        )
        self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(
            list(person.groups.values_list("id", flat=True)), [self.group.id]
        )
        self.assertEqual(self.client.get(f"/api/people/{private.id}/").status_code, 404)
        listing = self.client.get(
            "/api/people/", {"kind": "learner", "cohort": cohort.id}
        )
        self.assertEqual(listing.data["count"], 0)

    def test_cohort_filter_deduplicates_people_before_pagination(self):
        first = self.learner("FIRST", self.group, self.second_group)
        second = self.learner("SECOND", self.second_group)
        self.learner("OTHER", self.other_group)
        self.learner("UNASSIGNED")
        self.make(m.Person, "TEACHER", kind="teacher").groups.add(self.group)
        query = {"kind": "learner", "cohort": self.cohort.id, "page_size": 1}
        response = self.client.get("/api/people/", query)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["count"], 2)
        self.assertEqual([row["id"] for row in response.data["results"]], [first.id])
        response = self.client.get("/api/people/", {**query, "page": 2})
        self.assertEqual([row["id"] for row in response.data["results"]], [second.id])
        response = self.client.get("/api/people/", {**query, "groups": self.group.id})
        self.assertEqual(response.data["count"], 1)

    def test_unassigned_filter_keeps_kind_search_and_pagination(self):
        first = self.learner("UNASSIGNED-1")
        second = self.learner("UNASSIGNED-2")
        self.learner("UNASSIGNED-NAME-BUT-ASSIGNED", self.group)
        self.make(m.Person, "UNASSIGNED-TEACHER", kind="teacher")
        query = {
            "kind": "learner",
            "unassigned": 1,
            "search": "UNASSIGNED",
            "page_size": 1,
        }
        response = self.client.get("/api/people/", query)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["count"], 2)
        self.assertEqual(response.data["results"][0]["id"], first.id)
        response = self.client.get("/api/people/", {**query, "page": 2})
        self.assertEqual(response.data["results"][0]["id"], second.id)

    def test_invalid_cohort_filter_is_rejected(self):
        for cohort in ["invalid", "0", "-1"]:
            with self.subTest(cohort=cohort):
                self.assertEqual(
                    self.client.get("/api/people/", {"cohort": cohort}).status_code, 400
                )

    def test_public_and_student_app_never_expose_learner_names_or_ids(self):
        person = self.learner("PRIVATE-LEARNER-NAME", self.group)
        period = self.make(m.Period, "PERIOD", start="2026-10-01", end="2026-11-01")
        plan = self.make(m.Plan, "PLAN", period=period, area=self.make(m.Area, "AREA"))
        course = self.make(m.Course, "COURSE", plan=plan)
        course.groups.set([self.group])
        self.assertIn(person.id, attendance(course)[0])
        m.Session.objects.create(
            institution=self.institution,
            plan=plan,
            course=course,
            start=datetime.fromisoformat("2026-10-14T08:00:00+02:00"),
            end=datetime.fromisoformat("2026-10-14T10:00:00+02:00"),
        )
        m.Publication.objects.create(
            institution=self.institution, plan=plan, number=1, snapshot=plan_rows(plan)
        )
        display = self.make(m.Display, "DISPLAY")
        display.plans.set([plan])
        anonymous = APIClient()
        response = anonymous.get(f"/api/public/{display.token}/")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(len(response.data["rows"]), 1)
        self.assertNotIn(person.name, json.dumps(response.data, default=str))
        self.assertNotIn("learner_ids", json.dumps(response.data, default=str))
        self.assertEqual(anonymous.get("/api/people/").status_code, 403)
        cache.clear()
        access = self.client.post(
            "/api/student-app/accesses/",
            {"group": self.group.id, "server": "https://campus.example.org"},
            format="json",
        )
        self.assertEqual(access.status_code, 201, access.data)
        login = anonymous.post(
            "/api/student-app/v1/login/",
            {"code": access.data["code"], "password": access.data["password"]},
            format="json",
        )
        self.assertEqual(login.status_code, 200, login.data)
        anonymous.credentials(HTTP_AUTHORIZATION="Bearer " + login.data["token"])
        response = anonymous.get(
            "/api/student-app/v1/feed/", {"start": "2026-10-12", "end": "2026-10-19"}
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(len(response.data["rows"]), 1)
        self.assertNotIn(person.name, json.dumps(response.data, default=str))
        self.assertNotIn("learner_ids", json.dumps(response.data, default=str))
        self.assertEqual(anonymous.get("/api/people/").status_code, 403)
