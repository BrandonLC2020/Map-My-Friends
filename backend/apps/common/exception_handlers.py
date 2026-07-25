"""Central mapping of Firestore transport errors to DRF responses.

Handled here rather than per-view so every endpoint degrades identically.
"""

from google.api_core import exceptions as gcloud_exceptions
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler


def firestore_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is not None:
        return response

    if isinstance(
        exc, (gcloud_exceptions.ServiceUnavailable, gcloud_exceptions.DeadlineExceeded)
    ):
        return Response(
            {"error": "Data store temporarily unavailable. Please retry."},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    if isinstance(exc, gcloud_exceptions.NotFound):
        return Response({"error": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    # PermissionDenied indicates misconfigured credentials, never a user-facing
    # condition. Returning None lets Django produce a 500 and log the trace.
    return None
