from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APITestCase

from apps.common.testing import FirestoreTestMixin
from apps.users.repositories import UserProfileRepository


class UserProfileRepositoryTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["user_profiles"]

    def test_get_or_create_is_idempotent(self):
        repo = UserProfileRepository()
        first = repo.get_or_create("owner-a")
        second = repo.get_or_create("owner-a")
        self.assertEqual(first.owner_key, second.owner_key)

    def test_defaults_applied(self):
        profile = UserProfileRepository().get_or_create("owner-a")
        self.assertEqual(profile.pin_color, "#2196F3")
        self.assertEqual(profile.distance_unit, "metric")

    def test_update_persists(self):
        repo = UserProfileRepository()
        repo.get_or_create("owner-a")
        updated = repo.update("owner-a", {"city": "Chicago", "distance_unit": "imperial"})
        self.assertEqual(updated.city, "Chicago")
        self.assertEqual(updated.distance_unit, "imperial")

    def test_profiles_are_isolated_by_key(self):
        repo = UserProfileRepository()
        repo.update("owner-a", {"city": "Chicago"})
        self.assertEqual(repo.get_or_create("owner-b").city, "")


class UserProfileEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["user_profiles"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")

    def test_requires_authentication(self):
        self.assertEqual(self.client.get("/api/user/profile/").status_code, 401)

    def test_get_creates_profile_lazily(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get("/api/user/profile/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["pin_color"], "#2196F3")

    def test_patch_updates_profile(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.patch(
            "/api/user/profile/", {"city": "Chicago"}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["city"], "Chicago")
