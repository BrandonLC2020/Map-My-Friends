"""Request-to-Firestore-owner mapping.

Shared by people and trips. Lives here rather than in either app's views so
neither app depends on the other's view module for an auth concern.
"""


def owner_key_for(request):
    """Firestore ownership key for a request; None means the public dataset."""
    user = request.user
    if user and user.is_authenticated:
        return user.username
    return None
