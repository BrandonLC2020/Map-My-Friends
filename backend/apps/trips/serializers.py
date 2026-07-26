from rest_framework import serializers

STATUS_CHOICES = ["DRAFT", "BOOKED", "CANCELLED"]
TRANSPORT_CHOICES = ["FLIGHT", "TRAIN", "BUS", "CAR"]


class TripStopSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    trip = serializers.CharField(source="trip_id", read_only=True)
    sequence_order = serializers.IntegerField(min_value=0)
    lat = serializers.FloatField(required=False, allow_null=True)
    lng = serializers.FloatField(required=False, allow_null=True)
    people = serializers.ListField(
        source="person_ids", child=serializers.CharField(), required=False
    )
    airport = serializers.IntegerField(source="airport_id", required=False, allow_null=True)
    station = serializers.IntegerField(source="station_id", required=False, allow_null=True)
    snapshot_address = serializers.CharField(read_only=True, allow_blank=True)
    snapshot_metadata = serializers.DictField(read_only=True)


class TripLegSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    trip = serializers.CharField(source="trip_id", read_only=True)
    departure_stop = serializers.CharField(source="departure_stop_id", read_only=True)
    arrival_stop = serializers.CharField(source="arrival_stop_id", read_only=True)
    departure_time = serializers.DateTimeField(required=False, allow_null=True)
    arrival_time = serializers.DateTimeField(required=False, allow_null=True)
    transport_type = serializers.ChoiceField(choices=TRANSPORT_CHOICES, required=False)
    booking_reference = serializers.CharField(max_length=100, required=False, allow_blank=True)
    ticket_data = serializers.DictField(required=False)


class TripSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=255)
    date = serializers.DateField()
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    status = serializers.ChoiceField(choices=STATUS_CHOICES, required=False)
    user = serializers.CharField(source="owner_key", read_only=True)
