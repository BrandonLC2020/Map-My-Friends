"""Populate the Firestore emulator with representative sample data.

There is no production data to migrate, so local development seeds rather than
imports. Refuses to run against a real Firestore instance.
"""

import os

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError

from apps.people.repositories import ContactLogRepository, PersonRepository
from apps.trips.repositories import TripRepository
from apps.users.repositories import UserProfileRepository

DEMO_USERNAME = "demo"
DEMO_PASSWORD = "demo12345!"

SAMPLE_PEOPLE = [
    {
        "tag": "FRIEND",
        "first_name": "Ada",
        "last_name": "Lovelace",
        "city": "London",
        "state": "England",
        "country": "UK",
        "lat": 51.5074,
        "lng": -0.1278,
        "timezone": "Europe/London",
        "pin_color": "#F44336",
        "contact_cadence_days": 30,
    },
    {
        "tag": "FAMILY",
        "first_name": "Grace",
        "last_name": "Hopper",
        "city": "New York",
        "state": "NY",
        "country": "USA",
        "lat": 40.7128,
        "lng": -74.0060,
        "timezone": "America/New_York",
        "pin_color": "#2196F3",
        "contact_cadence_days": 14,
    },
    {
        "tag": "FRIEND",
        "first_name": "Alan",
        "last_name": "Turing",
        "city": "Chicago",
        "state": "IL",
        "country": "USA",
        "lat": 41.8781,
        "lng": -87.6298,
        "timezone": "America/Chicago",
        "pin_color": "#4CAF50",
        "contact_cadence_days": 60,
    },
]


class Command(BaseCommand):
    help = "Seed the Firestore emulator with sample data."

    def handle(self, *args, **options):
        if not os.environ.get("FIRESTORE_EMULATOR_HOST"):
            raise CommandError(
                "FIRESTORE_EMULATOR_HOST is not set. Refusing to seed what may be "
                "a real Firestore database. Start the emulator with `make up`."
            )

        user, created = User.objects.get_or_create(
            username=DEMO_USERNAME,
            defaults={"email": "demo@example.com"},
        )
        if created:
            user.set_password(DEMO_PASSWORD)
            user.save()
            self.stdout.write(
                f"Created Django user '{DEMO_USERNAME}' (password: {DEMO_PASSWORD})"
            )

        owner_key = user.username
        people_repo = PersonRepository()
        logs_repo = ContactLogRepository()

        UserProfileRepository().get_or_create(owner_key)

        created_people = []
        for data in SAMPLE_PEOPLE:
            person = people_repo.create(owner_key, data)
            created_people.append(person)
            self.stdout.write(f"  person: {person.first_name} {person.last_name}")

        logs_repo.create(
            owner_key,
            created_people[0].id,
            {
                "channel": "CALL",
                "contacted_at": "2026-07-10T18:00:00+00:00",
                "note": "Caught up",
            },
        )
        logs_repo.create(
            owner_key,
            created_people[1].id,
            {
                "channel": "VIDEO",
                "contacted_at": "2026-07-20T15:30:00+00:00",
                "note": None,
            },
        )

        trip = TripRepository().create(
            owner_key,
            {
                "name": "Summer visit",
                "date": "2026-08-01",
                "start_date": "2026-08-01",
                "end_date": "2026-08-10",
                "status": "DRAFT",
            },
        )
        self.stdout.write(f"  trip: {trip.name}")

        self.stdout.write(self.style.SUCCESS("Seed complete."))
