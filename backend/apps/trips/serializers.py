from rest_framework import serializers

STATUS_CHOICES = ["DRAFT", "BOOKED", "CANCELLED"]
TRANSPORT_CHOICES = ["FLIGHT", "TRAIN", "BUS", "CAR"]


class PointField(serializers.Field):
    """GeoJSON Point <-> flat lat/lng, replacing rest_framework_gis's GeometryField.

    Firestore stores plain `lat`/`lng` numbers, but the API contract is a
    GeoJSON Point and the Flutter client depends on it in both directions:
    TripStop.toJson sends {'type': 'Point', 'coordinates': [lng, lat]} and
    TripStop.fromJson reads json['location']['coordinates'] with no fallback.
    Coordinates are [longitude, latitude] per the GeoJSON spec.
    """

    def get_attribute(self, instance):
        # The field spans two source attributes, so take the record itself.
        return instance

    def to_representation(self, instance):
        lat = getattr(instance, "lat", None)
        lng = getattr(instance, "lng", None)
        if lat is None or lng is None:
            return None
        return {"type": "Point", "coordinates": [lng, lat]}

    def to_internal_value(self, data):
        if not isinstance(data, dict):
            raise serializers.ValidationError(
                "Expected a GeoJSON Point object, e.g. "
                '{"type": "Point", "coordinates": [lng, lat]}.'
            )
        coordinates = data.get("coordinates")
        if not isinstance(coordinates, (list, tuple)) or len(coordinates) != 2:
            raise serializers.ValidationError(
                "coordinates must be a two-element [longitude, latitude] list."
            )
        try:
            lng, lat = float(coordinates[0]), float(coordinates[1])
        except (TypeError, ValueError):
            raise serializers.ValidationError("coordinates must be numbers.")
        if not -90 <= lat <= 90 or not -180 <= lng <= 180:
            raise serializers.ValidationError(
                "coordinates out of range; expected [longitude, latitude]."
            )
        return {"lat": lat, "lng": lng}


class TripStopSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    trip = serializers.CharField(source="trip_id", read_only=True)
    sequence_order = serializers.IntegerField(min_value=0)
    location = PointField()
    people = serializers.ListField(
        source="person_ids", child=serializers.CharField(), required=False
    )
    airport = serializers.IntegerField(
        source="airport_id", required=False, allow_null=True
    )
    station = serializers.IntegerField(
        source="station_id", required=False, allow_null=True
    )
    snapshot_address = serializers.CharField(read_only=True, allow_blank=True)
    snapshot_metadata = serializers.DictField(read_only=True)

    def to_internal_value(self, data):
        ret = super().to_internal_value(data)
        # DRF propagates root.partial into nested serializers, so on PATCH the
        # required=True on `location` is skipped. A stop persisted without
        # coordinates comes back as location: null, and TripStop.fromJson
        # dereferences it unguarded — one bad stop breaks the whole Trips tab.
        location = ret.pop("location", None)
        if not location:
            raise serializers.ValidationError({"location": ["This field is required."]})
        ret.update(location)
        return ret


class TripLegSerializer(serializers.Serializer):
    # Writable so update payloads can address a leg by id, but stripped before
    # the write so it never lands in the document (the doc id is the id).
    id = serializers.CharField(required=False, allow_null=True)
    trip = serializers.CharField(source="trip_id", read_only=True)
    departure_stop = serializers.CharField(source="departure_stop_id", read_only=True)
    arrival_stop = serializers.CharField(source="arrival_stop_id", read_only=True)
    departure_time = serializers.DateTimeField(required=False, allow_null=True)
    arrival_time = serializers.DateTimeField(required=False, allow_null=True)
    transport_type = serializers.ChoiceField(choices=TRANSPORT_CHOICES, required=False)
    booking_reference = serializers.CharField(
        max_length=100, required=False, allow_blank=True
    )
    ticket_data = serializers.DictField(required=False)


class TripSerializer(serializers.Serializer):
    """Trips carry their stops and legs inline.

    The pre-migration ModelSerializer nested both, created stops on POST and
    replaced them on PUT/PATCH. Flutter's Trip.fromJson reads json['stops']
    with no null guard, so a flat trip payload breaks the Trips tab outright.
    """

    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=255)
    date = serializers.DateField()
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    status = serializers.ChoiceField(choices=STATUS_CHOICES, required=False)
    user = serializers.CharField(source="owner_key", read_only=True)
    stops = TripStopSerializer(many=True, required=False)
    legs = TripLegSerializer(many=True, required=False)
