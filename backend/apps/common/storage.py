"""File storage helpers.

Django's ImageField previously handled naming, saving and URL generation. With
the models gone those steps become explicit. Everything routes through
`default_storage`, so the STORAGES setting alone decides between the local
filesystem and Cloud Storage — no code branches on environment.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from django.core.files.storage import default_storage


def save_upload(uploaded_file, prefix: str) -> str:
    """Persist an uploaded file under `prefix/`, returning its storage name.

    A UUID stem prevents collisions between users uploading identically named
    files, mirroring what Django's upload_to + suffixing used to provide.
    """
    suffix = Path(uploaded_file.name).suffix.lower()
    name = f"{prefix}/{uuid.uuid4().hex}{suffix}"
    return default_storage.save(name, uploaded_file)


def upload_url(name: str | None, request=None) -> str | None:
    """Absolute URL for a stored file name, or None when unset."""
    if not name:
        return None
    url = default_storage.url(name)
    if request is not None:
        return request.build_absolute_uri(url)
    return url
