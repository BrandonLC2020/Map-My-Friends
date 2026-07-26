from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase

from apps.common.storage import save_upload, upload_url


class StorageTests(SimpleTestCase):
    def test_save_upload_returns_prefixed_name(self):
        upload = SimpleUploadedFile("avatar.png", b"fake-image-bytes", content_type="image/png")
        name = save_upload(upload, prefix="profile_images")
        self.assertTrue(name.startswith("profile_images/"))
        self.assertTrue(name.endswith(".png"))

    def test_saved_names_do_not_collide(self):
        first = save_upload(
            SimpleUploadedFile("a.png", b"one", content_type="image/png"),
            prefix="profile_images",
        )
        second = save_upload(
            SimpleUploadedFile("a.png", b"two", content_type="image/png"),
            prefix="profile_images",
        )
        self.assertNotEqual(first, second)

    def test_upload_url_returns_media_url(self):
        name = save_upload(
            SimpleUploadedFile("b.png", b"bytes", content_type="image/png"),
            prefix="profile_images",
        )
        self.assertIn("/media/profile_images/", upload_url(name))

    def test_upload_url_of_none_is_none(self):
        self.assertIsNone(upload_url(None))
