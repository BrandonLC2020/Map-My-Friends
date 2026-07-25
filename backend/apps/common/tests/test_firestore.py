from django.test import SimpleTestCase

from apps.common import firestore as fs
from apps.common.testing import FirestoreTestMixin


class FirestoreClientTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["_smoke"]

    def test_client_is_singleton(self):
        self.assertIs(fs.get_client(), fs.get_client())

    def test_round_trip_document(self):
        ref = fs.collection("_smoke").document("doc1")
        ref.set({"value": 42})
        self.assertEqual(ref.get().to_dict()["value"], 42)

    def test_purge_between_tests_leaves_collection_empty(self):
        # The mixin purges in setUp, so the document written by the previous
        # test must not be visible here.
        self.assertEqual(len(list(fs.collection("_smoke").stream())), 0)
