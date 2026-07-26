from django.test import SimpleTestCase

from apps.common.testing import FirestoreTestMixin
from apps.trips.repositories import DuplicateSequenceOrder, TripRepository

TRIP_DATA = {
    "name": "Summer trip",
    "date": "2026-08-01",
    "start_date": "2026-08-01",
    "end_date": "2026-08-10",
    "status": "DRAFT",
}


class TripRepositoryTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["trips"]

    def setUp(self):
        super().setUp()
        self.trips = TripRepository()

    def test_create_assigns_string_id_and_owner(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertIsInstance(trip.id, str)
        self.assertEqual(trip.owner_key, "owner-a")

    def test_list_is_owner_scoped(self):
        self.trips.create("owner-a", TRIP_DATA)
        self.trips.create("owner-b", TRIP_DATA)
        self.assertEqual(len(self.trips.list_for_owner("owner-a")), 1)

    def test_get_for_wrong_owner_returns_none(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertIsNone(self.trips.get_for_owner(trip.id, "owner-b"))

    def test_dates_default_from_legacy_date_field(self):
        trip = self.trips.create("owner-a", {"name": "T", "date": "2026-09-01", "status": "DRAFT"})
        self.assertEqual(trip.start_date, "2026-09-01")
        self.assertEqual(trip.end_date, "2026-09-01")

    def test_add_stop_persists(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        stop = self.trips.add_stop(
            trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0}
        )
        self.assertEqual(stop.sequence_order, 1)

    def test_duplicate_sequence_order_rejected(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        with self.assertRaises(DuplicateSequenceOrder):
            self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 3.0, "lng": 4.0})

    def test_add_stop_for_wrong_owner_returns_none(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertIsNone(
            self.trips.add_stop(trip.id, "owner-b", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        )

    def test_generate_legs_links_consecutive_stops(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 2, "lat": 3.0, "lng": 4.0})
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 3, "lat": 5.0, "lng": 6.0})

        legs = self.trips.generate_legs(trip.id, "owner-a")
        self.assertEqual(len(legs), 2)

    def test_generate_legs_is_idempotent(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 2, "lat": 3.0, "lng": 4.0})

        self.trips.generate_legs(trip.id, "owner-a")
        legs = self.trips.generate_legs(trip.id, "owner-a")
        self.assertEqual(len(legs), 1)

    def test_snapshot_on_draft_to_booked(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(
            trip.id,
            "owner-a",
            {"sequence_order": 1, "lat": 1.0, "lng": 2.0, "airport_id": 1},
        )
        self.trips.update(trip.id, "owner-a", {"status": "BOOKED"})

        stops = self.trips.list_stops(trip.id, "owner-a")
        self.assertTrue(stops[0].snapshot_address)
        self.assertIn("hub", stops[0].snapshot_metadata)

    def test_delete_removes_trip_and_children(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        self.assertTrue(self.trips.delete(trip.id, "owner-a"))
        self.assertIsNone(self.trips.get_for_owner(trip.id, "owner-a"))

    def test_delete_by_wrong_owner_refused(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertFalse(self.trips.delete(trip.id, "owner-b"))


from django.contrib.auth.models import User
from rest_framework.test import APITestCase


class TripEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["trips"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")
        self.other = User.objects.create_user(username="owner-b", password="pw12345!")
        self.client.force_authenticate(user=self.user)

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        self.assertEqual(self.client.get("/api/trips/").status_code, 401)

    def test_create_and_list(self):
        created = self.client.post("/api/trips/", TRIP_DATA, format="json")
        self.assertEqual(created.status_code, 201)
        self.assertEqual(len(self.client.get("/api/trips/").data), 1)

    def test_trip_data_isolation(self):
        self.client.post("/api/trips/", TRIP_DATA, format="json")
        self.client.force_authenticate(user=self.other)
        self.assertEqual(len(self.client.get("/api/trips/").data), 0)

    def test_cannot_retrieve_another_owners_trip(self):
        created = self.client.post("/api/trips/", TRIP_DATA, format="json")
        self.client.force_authenticate(user=self.other)
        response = self.client.get(f"/api/trips/{created.data['id']}/")
        self.assertEqual(response.status_code, 404)

    def test_duplicate_sequence_order_returns_400(self):
        created = self.client.post("/api/trips/", TRIP_DATA, format="json")
        trip_id = created.data["id"]
        stop = {"sequence_order": 1, "lat": 1.0, "lng": 2.0}
        self.client.post(f"/api/trips/{trip_id}/stops/", stop, format="json")
        second = self.client.post(f"/api/trips/{trip_id}/stops/", stop, format="json")
        self.assertEqual(second.status_code, 400)
