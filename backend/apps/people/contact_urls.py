from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ContactLogViewSet

# Mounted at its own top-level prefix (api/contact-logs/) rather than under the
# people router, whose r'' registration would otherwise treat 'contact-logs' as
# a person primary key.
router = DefaultRouter()
router.register(r"", ContactLogViewSet, basename="contactlog")

urlpatterns = [
    path("", include(router.urls)),
]
