from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import TripLegViewSet, TripViewSet

router = DefaultRouter()
router.register(r"legs", TripLegViewSet, basename="tripleg")
router.register(r"", TripViewSet, basename="trip")

urlpatterns = [
    path("", include(router.urls)),
]
