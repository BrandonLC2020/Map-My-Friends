from django.test import SimpleTestCase

from apps.common.testing import FirestoreTestMixin
from apps.people.repositories import ContactLogRepository, PersonRepository

PERSON_DATA = {
    "tag": "FRIEND",
    "first_name": "Ada",
    "last_name": "Lovelace",
    "city": "London",
    "state": "England",
    "country": "UK",
    "lat": 51.5074,
    "lng": -0.1278,
}


class PersonRepositoryTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.people = PersonRepository()

    def test_create_assigns_string_id(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertIsInstance(person.id, str)
        self.assertTrue(person.id)

    def test_create_sets_owner_key(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertEqual(person.owner_key, "owner-a")

    def test_list_returns_only_own_people(self):
        self.people.create("owner-a", PERSON_DATA)
        self.people.create("owner-b", PERSON_DATA)
        self.assertEqual(len(self.people.list_for_owner("owner-a")), 1)

    def test_list_for_none_owner_returns_public_people(self):
        self.people.create(None, PERSON_DATA)
        self.people.create("owner-a", PERSON_DATA)
        public = self.people.list_for_owner(None)
        self.assertEqual(len(public), 1)
        self.assertIsNone(public[0].owner_key)

    def test_get_for_wrong_owner_returns_none(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertIsNone(self.people.get_for_owner(person.id, "owner-b"))

    def test_get_for_correct_owner_returns_record(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertEqual(self.people.get_for_owner(person.id, "owner-a").id, person.id)

    def test_update_applies_changes(self):
        person = self.people.create("owner-a", PERSON_DATA)
        updated = self.people.update(person.id, "owner-a", {"first_name": "Grace"})
        self.assertEqual(updated.first_name, "Grace")

    def test_update_by_wrong_owner_returns_none(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertIsNone(
            self.people.update(person.id, "owner-b", {"first_name": "Nope"})
        )

    def test_delete_removes_document(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertTrue(self.people.delete(person.id, "owner-a"))
        self.assertIsNone(self.people.get_for_owner(person.id, "owner-a"))

    def test_delete_by_wrong_owner_is_refused(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertFalse(self.people.delete(person.id, "owner-b"))
        self.assertIsNotNone(self.people.get_for_owner(person.id, "owner-a"))


class ContactLogRepositoryTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.people = PersonRepository()
        self.logs = ContactLogRepository()
        self.person_a = self.people.create("owner-a", PERSON_DATA)
        self.person_b = self.people.create("owner-b", PERSON_DATA)

    def test_create_log_for_own_person(self):
        log = self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.assertEqual(log.person_id, self.person_a.id)

    def test_cannot_create_log_for_another_owners_person(self):
        log = self.logs.create(
            "owner-a",
            self.person_b.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.assertIsNone(log)

    def test_list_is_scoped_to_owner(self):
        self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.logs.create(
            "owner-b",
            self.person_b.id,
            {"channel": "VIDEO", "contacted_at": "2026-07-02T12:00:00+00:00"},
        )
        self.assertEqual(len(self.logs.list_for_owner("owner-a")), 1)

    def test_person_filter_scoped_to_owner(self):
        self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        # Filtering by another owner's person yields nothing, not a leak.
        self.assertEqual(
            self.logs.list_for_owner("owner-a", person_id=self.person_b.id), []
        )

    def test_logs_ordered_most_recent_first(self):
        self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "VIDEO", "contacted_at": "2026-07-05T12:00:00+00:00"},
        )
        logs = self.logs.list_for_owner("owner-a", person_id=self.person_a.id)
        self.assertEqual(logs[0].channel, "VIDEO")

    def test_person_carries_recency_summary(self):
        self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "VIDEO", "contacted_at": "2026-07-05T12:00:00+00:00"},
        )
        person = self.people.get_for_owner(self.person_a.id, "owner-a")
        self.assertEqual(person.last_contact_channel, "VIDEO")
        self.assertTrue(person.last_contacted_at.startswith("2026-07-05"))


class OwnershipReassignmentTests(FirestoreTestMixin, SimpleTestCase):
    """owner_key must never be writable from caller-supplied data.

    The serializer marks it read-only, but the repository is the security
    boundary in its own right: a caller passing {"owner_key": ...} must not be
    able to claim another owner's record or hand away their own.
    """

    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.people = PersonRepository()

    def test_create_ignores_owner_key_in_data(self):
        person = self.people.create("owner-a", {**PERSON_DATA, "owner_key": "owner-b"})
        self.assertEqual(person.owner_key, "owner-a")

    def test_update_cannot_reassign_ownership(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.people.update(person.id, "owner-a", {"owner_key": "owner-b"})

        # Still owned by owner-a, and never visible to owner-b.
        self.assertEqual(
            self.people.get_for_owner(person.id, "owner-a").owner_key, "owner-a"
        )
        self.assertIsNone(self.people.get_for_owner(person.id, "owner-b"))

    def test_update_cannot_make_record_public(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.people.update(person.id, "owner-a", {"owner_key": None})
        self.assertEqual(self.people.list_for_owner(None), [])


class ContactLogCrossOwnerTests(FirestoreTestMixin, SimpleTestCase):
    """get/update/delete on logs must refuse another owner, not just create."""

    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.people = PersonRepository()
        self.logs = ContactLogRepository()
        self.person_a = self.people.create("owner-a", PERSON_DATA)
        self.log_a = self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )

    def test_get_for_wrong_owner_returns_none(self):
        self.assertIsNone(self.logs.get_for_owner(self.log_a.id, "owner-b"))

    def test_update_by_wrong_owner_returns_none_and_does_not_write(self):
        self.assertIsNone(
            self.logs.update(self.log_a.id, "owner-b", {"channel": "VIDEO"})
        )
        self.assertEqual(
            self.logs.get_for_owner(self.log_a.id, "owner-a").channel, "CALL"
        )

    def test_delete_by_wrong_owner_is_refused(self):
        self.assertFalse(self.logs.delete(self.log_a.id, "owner-b"))
        self.assertIsNotNone(self.logs.get_for_owner(self.log_a.id, "owner-a"))
