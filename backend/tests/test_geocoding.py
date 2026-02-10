from django.utils import timezone
from apps.people.models import Person
from django.contrib.gis.geos import Point
import sys

# Test 1: Successful Geocoding
print("Test 1: Creating person with valid address...")
try:
    p1 = Person(
        first_name="Test",
        last_name="User",
        tag="FRIEND",
        city="Chicago",
        state="IL",
        country="USA"
    )
    p1.save()
    if p1.location:
        print(f"SUCCESS: Person created with location: {p1.location}")
    else:
        print("FAILURE: Person created but location is None (should not happen due to validation)")
except Exception as e:
    print(f"FAILURE: Exception raised: {e}")

# Test 2: Failed Geocoding
print("\nTest 2: Creating person with invalid address...")
try:
    p2 = Person(
        first_name="Bad",
        last_name="Address",
        tag="FAMILY",
        city="NowhereCity12345",
        state="ZZ",
        country="Mars"
    )
    p2.save()
    print("FAILURE: Person created with invalid address (should have raised ValidationError)")
except Exception as e:
    print(f"SUCCESS: Exception raised as expected: {e}")
