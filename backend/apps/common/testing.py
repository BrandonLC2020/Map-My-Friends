"""Test support for emulator-backed tests.

Tests run against the real Firestore emulator rather than mocks, so state must
be purged between them. Mocking would only verify assumptions about Firestore
rather than Firestore itself.
"""

from __future__ import annotations

from apps.common import firestore as fs


def purge_collection(name: str, batch_size: int = 200) -> None:
    """Recursively delete every document in a collection, including subcollections."""
    collection = fs.collection(name)
    while True:
        docs = list(collection.limit(batch_size).stream())
        if not docs:
            return
        for doc in docs:
            for sub in doc.reference.collections():
                for sub_doc in sub.stream():
                    sub_doc.reference.delete()
            doc.reference.delete()


class FirestoreTestMixin:
    """Purges the named collections before each test.

    Usage:
        class MyTests(FirestoreTestMixin, APITestCase):
            collections_to_purge = ["people", "trips"]
    """

    collections_to_purge: list[str] = ["people", "trips", "user_profiles"]

    def setUp(self):
        for name in self.collections_to_purge:
            purge_collection(name)
        super().setUp()
