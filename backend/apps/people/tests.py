from unittest.mock import patch

from django.contrib.auth.models import User
from rest_framework.test import APITestCase

from apps.common.testing import FirestoreTestMixin

PERSON_PAYLOAD = {
    "tag": "FRIEND",
    "first_name": "Ada",
    "last_name": "Lovelace",
    "city": "London",
    "state": "England",
    "country": "UK",
}


@patch(
    "apps.people.views.geocode_address",
    return_value=(51.5074, -0.1278, "Europe/London"),
)
class PersonEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")
        self.other = User.objects.create_user(username="owner-b", password="pw12345!")

    def test_list_is_public(self, _geocode):
        response = self.client.get("/api/people/")
        self.assertEqual(response.status_code, 200)

    def test_create_requires_auth(self, _geocode):
        response = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")
        self.assertEqual(response.status_code, 401)

    def test_create_returns_geojson_feature(self, _geocode):
        self.client.force_authenticate(user=self.user)
        response = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["type"], "Feature")
        # GeoJSON is [longitude, latitude] — order is load-bearing for the client.
        self.assertEqual(response.data["geometry"]["coordinates"], [-0.1278, 51.5074])

    def test_owner_isolation_on_list(self, _geocode):
        self.client.force_authenticate(user=self.user)
        self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=self.other)
        response = self.client.get("/api/people/")
        self.assertEqual(len(response.data["features"]), 0)

    def test_cannot_retrieve_another_owners_person(self, _geocode):
        self.client.force_authenticate(user=self.user)
        created = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=self.other)
        response = self.client.get(f"/api/people/{created.data['id']}/")
        self.assertEqual(response.status_code, 404)

    def test_cannot_delete_another_owners_person(self, _geocode):
        self.client.force_authenticate(user=self.user)
        created = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=self.other)
        response = self.client.delete(f"/api/people/{created.data['id']}/")
        self.assertEqual(response.status_code, 404)

    def test_recency_fields_hidden_from_anonymous(self, _geocode):
        self.client.force_authenticate(user=self.user)
        self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=None)
        response = self.client.get("/api/people/")
        for feature in response.data["features"]:
            self.assertNotIn("last_contacted_at", feature["properties"])


class ContactLogEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")
        self.other = User.objects.create_user(username="owner-b", password="pw12345!")

        from apps.people.repositories import PersonRepository

        self.person = PersonRepository().create(
            "owner-a",
            {**PERSON_PAYLOAD, "lat": 51.5074, "lng": -0.1278},
        )

    def test_requires_auth(self):
        self.assertEqual(self.client.get("/api/contact-logs/").status_code, 401)

    def test_create_and_list(self):
        self.client.force_authenticate(user=self.user)
        created = self.client.post(
            "/api/contact-logs/",
            {"person": self.person.id, "channel": "CALL",
             "contacted_at": "2026-07-01T12:00:00Z"},
            format="json",
        )
        self.assertEqual(created.status_code, 201)
        self.assertEqual(len(self.client.get("/api/contact-logs/").data), 1)

    def test_cannot_create_log_for_other_users_person(self):
        self.client.force_authenticate(user=self.other)
        response = self.client.post(
            "/api/contact-logs/",
            {"person": self.person.id, "channel": "CALL",
             "contacted_at": "2026-07-01T12:00:00Z"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)

    def test_log_isolation_on_list(self):
        self.client.force_authenticate(user=self.user)
        self.client.post(
            "/api/contact-logs/",
            {"person": self.person.id, "channel": "CALL",
             "contacted_at": "2026-07-01T12:00:00Z"},
            format="json",
        )
        self.client.force_authenticate(user=self.other)
        self.assertEqual(len(self.client.get("/api/contact-logs/").data), 0)
