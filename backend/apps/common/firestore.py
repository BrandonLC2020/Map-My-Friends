"""Firestore client singleton.

firebase-admin detects FIRESTORE_EMULATOR_HOST itself and routes to the
emulator when it is set, so no application code branches on environment.
That is what makes local behaviour a faithful predictor of production.
"""

from __future__ import annotations

import os
import threading

import firebase_admin
from django.core.exceptions import ImproperlyConfigured
from google.cloud import firestore

_lock = threading.Lock()
_client = None


def _check_configuration() -> None:
    from django.conf import settings

    if settings.DEBUG and not os.environ.get("FIRESTORE_EMULATOR_HOST"):
        raise ImproperlyConfigured(
            "FIRESTORE_EMULATOR_HOST is not set while DEBUG=True. Start the "
            "emulator with `make up` (or `docker compose up firestore`), which "
            "sets FIRESTORE_EMULATOR_HOST=firestore:8080 for the api service."
        )


def get_client():
    """Return the process-wide Firestore client, initialising it on first use."""
    global _client
    if _client is None:
        with _lock:
            if _client is None:
                from django.conf import settings

                _check_configuration()
                if not firebase_admin._apps:
                    firebase_admin.initialize_app(
                        options={"projectId": settings.FIRESTORE_PROJECT_ID}
                    )
                # google.cloud.firestore.Client checks FIRESTORE_EMULATOR_HOST
                # itself and substitutes anonymous credentials when it is set
                # (see firestore_v1.base_client.BaseClient.__init__). Using it
                # directly, rather than firebase_admin.firestore.client(),
                # matters because that wrapper unconditionally resolves
                # Application Default Credentials before this check ever
                # happens, which fails outside a real GCP environment. This
                # is the single call path for both the emulator and
                # production Firestore.
                _client = firestore.Client(project=settings.FIRESTORE_PROJECT_ID)
    return _client


def collection(name: str):
    """Shorthand for get_client().collection(name)."""
    return get_client().collection(name)
