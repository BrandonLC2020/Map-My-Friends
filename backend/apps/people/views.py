from rest_framework import viewsets
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import UserRateThrottle

from .models import Person, ContactLog
from .serializers import PersonSerializer, ContactLogSerializer


class PersonViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing Person objects.
    List and retrieve are public, create/update/delete require authentication.
    """
    serializer_class = PersonSerializer

    def get_queryset(self):
        user = self.request.user
        if user and user.is_authenticated:
            return Person.objects.filter(owner=user).prefetch_related('contact_logs')
        return Person.objects.filter(owner__isnull=True).prefetch_related('contact_logs')

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            permission_classes = [AllowAny]
        else:
            permission_classes = [IsAuthenticated]
        return [permission() for permission in permission_classes]

    def get_throttles(self):
        if self.action == 'create':
            # Stricter throttling for creating people due to geocoding costs
            return [UserRateThrottle()]
        return super().get_throttles()


class ContactLogViewSet(viewsets.ModelViewSet):
    """
    ViewSet for logging touchpoints (calls, video chats, messages) with a
    Person. All actions require authentication.

    Supports `?person=<id>` to scope the list to a single person.
    """
    serializer_class = ContactLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = ContactLog.objects.filter(person__owner=self.request.user).select_related('person')
        person_id = self.request.query_params.get('person')
        if person_id is not None:
            queryset = queryset.filter(person_id=person_id)
        return queryset
