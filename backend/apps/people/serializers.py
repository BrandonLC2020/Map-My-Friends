from rest_framework import serializers
from django.contrib.gis.geos import Point
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Person, ContactLog
from apps.airports import reference as airport_reference
from apps.stations import reference as station_reference
from apps.airports.serializers import AirportSerializer
from apps.stations.serializers import StationSerializer


class ContactLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContactLog
        fields = (
            'id',
            'person',
            'channel',
            'contacted_at',
            'note',
            'created_at',
        )
        read_only_fields = ('created_at',)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            self.fields['person'].queryset = Person.objects.filter(owner=request.user)


class PersonSerializer(GeoFeatureModelSerializer):
    preferred_airport = serializers.IntegerField(allow_null=True, required=False)
    preferred_station = serializers.IntegerField(allow_null=True, required=False)
    preferred_airport_detail = serializers.SerializerMethodField()
    preferred_station_detail = serializers.SerializerMethodField()

    # Recency summary powering the Keep-in-Touch roster. Read-only; derived
    # from the person's most recent ContactLog so the client can color-code
    # without fetching every log.
    last_contacted_at = serializers.SerializerMethodField()
    last_contact_channel = serializers.SerializerMethodField()

    class Meta:
        model = Person
        geo_field = "location"
        fields = (
            'id',
            'owner',
            'first_name',
            'last_name',
            'tag',
            'city',
            'state',
            'country',
            'street',
            'birthday',
            'phone_number',
            'profile_image',
            'location',
            'timezone',
            'pin_color',
            'pin_style',
            'pin_icon_type',
            'pin_emoji',
            'contact_cadence_days',
            'last_contacted_at',
            'last_contact_channel',
            'preferred_airport',
            'preferred_station',
            'preferred_airport_detail',
            'preferred_station_detail',
        )
        read_only_fields = ('location', 'timezone', 'owner')

    def _latest_log(self, obj):
        # Reads from the prefetched `contact_logs` cache (see PersonViewSet's
        # prefetch_related) so the roster loads without an N+1 query. The
        # related manager's default ordering is '-contacted_at', so element 0
        # is the most recent touchpoint.
        if not hasattr(obj, '_cached_latest_log'):
            logs = list(obj.contact_logs.all())
            obj._cached_latest_log = logs[0] if logs else None
        return obj._cached_latest_log

    def get_last_contacted_at(self, obj):
        log = self._latest_log(obj)
        return log.contacted_at.isoformat() if log else None

    def get_last_contact_channel(self, obj):
        log = self._latest_log(obj)
        return log.channel if log else None

    def get_preferred_airport_detail(self, obj):
        if obj.preferred_airport is None:
            return None
        airport = airport_reference.get_by_id(obj.preferred_airport)
        return AirportSerializer(airport).data if airport else None

    def get_preferred_station_detail(self, obj):
        if obj.preferred_station is None:
            return None
        station = station_reference.get_by_id(obj.preferred_station)
        return StationSerializer(station).data if station else None

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        is_authenticated = request and request.user and request.user.is_authenticated
        if not is_authenticated:
            if 'properties' in ret:
                ret['properties'].pop('last_contacted_at', None)
                ret['properties'].pop('last_contact_channel', None)
            else:
                ret.pop('last_contacted_at', None)
                ret.pop('last_contact_channel', None)
        return ret
