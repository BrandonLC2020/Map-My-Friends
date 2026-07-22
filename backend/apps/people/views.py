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
    # Prefetch contact logs so the recency summary fields on PersonSerializer
    # resolve from cache instead of firing a query per person.
    queryset = Person.objects.prefetch_related('contact_logs').all()
    serializer_class = PersonSerializer

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
    Person. List/retrieve are public (mirroring PersonViewSet); creating,
    editing, and deleting a log require authentication.

    Supports `?person=<id>` to scope the list to a single person.
    """
    serializer_class = ContactLogSerializer

    def get_queryset(self):
        queryset = ContactLog.objects.select_related('person').all()
        person_id = self.request.query_params.get('person')
        if person_id is not None:
            queryset = queryset.filter(person_id=person_id)
        return queryset

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            permission_classes = [AllowAny]
        else:
            permission_classes = [IsAuthenticated]
        return [permission() for permission in permission_classes]
