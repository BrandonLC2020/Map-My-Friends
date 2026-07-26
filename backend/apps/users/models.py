# UserProfile now lives in Firestore (see repositories.py). The post_save
# signals that auto-created it are gone with it: profile creation is lazy,
# handled by UserProfileRepository.get_or_create on first read.
#
# django.contrib.auth.User remains until ClickUp 86bb3eu64 (Auth0 -> GCIP)
# removes the need for a relational identity table.
