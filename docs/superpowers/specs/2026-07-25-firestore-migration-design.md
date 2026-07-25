# Design Spec: Local Database Transition to Google Cloud Firestore + Emulator

**Date:** 2026-07-25
**Status:** Approved
**ClickUp:** [86bb077ur](https://app.clickup.com/t/86bb077ur) — "transition local database to Google Cloud Firestore and use the Emulator"
**Goal:** Replace the local PostgreSQL/PostGIS database with Google Cloud Firestore, backed by the Firebase Emulator Suite for local development, as the first step of an AWS-to-GCP migration.

## 1. Problem Statement

The application currently runs Django + GeoDjango against a PostgreSQL/PostGIS container, deployed on EC2 via Terraform (`infra/ec2.tf`) with `docker-compose.prod.yml` running Postgres beside the app on a single VM.

The project is migrating from AWS to GCP, optimizing for low cost with no established user base. The cheap GCP compute analog is Cloud Run, which is **stateless and scales to zero** — it cannot host a database container the way the current EC2 box does. That forces a choice:

- **Cloud SQL for PostgreSQL** — retains PostGIS and every line of existing code, but has no free tier and bills 24/7 even at zero traffic.
- **Firestore** — has a free tier and costs nothing at idle, but is a document store with no Django ORM support and no geospatial query support.

Firestore is the correct choice for a pre-revenue application. This spec defines how to get there without losing capability.

### 1.1 Constraints Discovered During Design

Three findings shaped the design and are recorded here because they are non-obvious:

1. **The Django ORM cannot target Firestore.** There is no database engine to swap in `settings.DATABASES`. Migrations, `ModelSerializer`, `ModelViewSet`, `select_related`, and `post_save` signals have no document-store equivalent. This is a persistence-layer rewrite, not a configuration change.

2. **Radius queries exist only on reference data.** `Distance()` and `distance_lte` appear solely in `apps/airports/views.py:43`, `apps/stations/views.py:50`, and the two `get_nearby()` classmethods. `Person.location` and `TripStop.location` are stored and serialized but **never** radius-queried — they are map-display coordinates. Therefore user data needs no spatial engine at all.

3. **Django's own framework tables still require SQL.** `django.contrib.auth`, `admin`, `sessions`, and `contenttypes` are backed by tables Django manages itself. Because the Auth0-to-GCIP migration is deferred (§8), `apps/users/auth.py` still calls `User.objects.get_or_create`, so a relational store remains **required** in this scope.

## 2. Scope

This spec covers three of four identified workstreams. The fourth is deferred (§8).

| # | Workstream | Included |
|---|---|---|
| A | User data → Firestore repository layer | Yes |
| B | Airports/Stations → in-memory index, drop PostGIS | Yes |
| C | Firebase Emulator Suite in local development | Yes |
| D | Auth0 → Google Cloud Identity Platform | **No — sibling task** |

These are separable because the project has **no production user base**. Ownership keys are the only coupling point between A and D, and with no real data there is nothing to re-key — the database can be wiped and reseeded when D lands.

## 3. Target Architecture

```
Flutter (dio, REST)
      │  Bearer JWT  ── Auth0 today; GCIP after task D
      ▼
Django 6 + DRF        ── stateless, Cloud Run-ready
      ├── repositories/   ─→ firebase-admin ─→ Firestore    (user data)
      ├── reference/      ─→ in-memory index                (airports, stations)
      ├── storage         ─→ Django STORAGES                (media; §7)
      └── SQLite          ─→ contrib.auth/admin/sessions/contenttypes only
```

Each store has exactly one responsibility. Firestore owns user data. An in-memory index owns static geodata. A small SQLite file owns Django's framework tables until task D removes the need for it.

### 3.1 Data Access Approach

An **explicit repository layer** — not an ORM shim and not a third-party Firestore-Django package.

Each app gains a `repositories.py` exposing intention-revealing, owner-scoped methods (`list_for_owner`, `get_for_owner`, `create`, `update`, `delete`). Domain objects become frozen `@dataclass` instances. Views drop from `ModelViewSet` to `ViewSet`; serializers drop from `ModelSerializer` to plain `Serializer`.

**Rationale:** the ownership isolation asserted by `tests/test_api_security.py` is currently enforced by ORM filters such as `ContactLog.objects.filter(person__owner=self.request.user)` (`apps/people/views.py:52`). Firestore has no joins, so that traversal must be rewritten regardless. A repository whose only public read method *requires* an owner key makes the isolation structural — there is no method that omits the filter, so it cannot be forgotten. The rewrite becomes a safety improvement rather than a hazard.

An ORM shim was rejected because it would mean maintaining a homemade ORM that still cannot support `ModelSerializer`, while hiding Firestore's real constraints (no joins, no `unique_together`, per-document write limits) in the layer where hiding them is most dangerous. Third-party packages were rejected because the mature option (`djangae`) targets Datastore on App Engine, and Firestore-specific packages are largely unmaintained.

### 3.2 Dependency and Image Changes

**Removed:** `psycopg2-binary`, `djangorestframework-gis`, `dj-database-url` (its only purpose was parsing the `DATABASE_URL` PostGIS connection string; the SQLite path is configured directly).
**Added:** `firebase-admin`.

`backend/Dockerfile` drops `gdal-bin`, `libgdal-dev`, `python3-gdal`, `libproj-dev`, `binutils`, and `libpq-dev`, along with the `CPLUS_INCLUDE_PATH` / `C_INCLUDE_PATH` GDAL workarounds. These are the slowest layers in the current image build.

`django.contrib.gis` and `rest_framework_gis` leave `INSTALLED_APPS`.

## 4. Firestore Data Model

```
people/{personId}                     owner_key: string|null   ← null = public demo person
  └── contact_logs/{logId}
trips/{tripId}                        owner_key: string
  ├── stops/{stopId}
  └── legs/{legId}
user_profiles/{ownerKey}              document ID *is* the owner key
```

`people` is a **top-level** collection rather than nested under a user, specifically to preserve the behavior in `apps/people/views.py:19` where unauthenticated list requests return `owner__isnull=True` public people. That becomes `where owner_key == null`, which nesting under a user document would make impossible.

Contact logs and trip children are **subcollections**, which makes the `?person=` filter natural and scopes ownership through the parent document.

### 4.1 Field Mapping

| Relational construct | Firestore representation | Note |
|---|---|---|
| `PointField location` | `lat`, `lng` number fields | GeoJSON envelope rebuilt at serializer (§4.3) |
| `TripStop.people` M2M | `person_ids: []` array | queryable via `array-contains` |
| `unique_together(trip, sequence_order)` | none | enforced in a repository transaction |
| integer PK | Firestore auto-ID string | see §4.2 |
| FK `preferred_airport` / `preferred_station` | `preferred_airport_id: int` | points at in-memory reference data |
| `auto_now_add` / `auto_now` | set explicitly in repository | no ORM hooks exist |
| `ImageField` | URL string field | file handled via storage layer (§7) |

`owner_key` currently equals Django's `User.username` (Auth0-derived, e.g. `auth0_123456`). After task D it becomes the GCIP `uid`.

### 4.1.1 Removed ORM Machinery

Because all six application models leave the ORM, the following are deleted rather than ported:

- **All `@admin.register` entries** — `Person`, `ContactLog` (`apps/people/admin.py`), `Trip` (`apps/trips/admin.py`), `Station`, `Airport`, `UserProfile`. Django admin survives but manages only the built-in `User` and `Group`. **Data inspection moves to the Emulator UI (`localhost:4000`) locally and the Firestore Console in production.** This is an accepted, deliberate loss.
- **The `UserProfile` signals** — `create_user_profile` and `save_user_profile` in `apps/users/models.py` fire on `User.post_save` and cannot reach Firestore. Profile creation becomes lazy, which `UserProfileView` (`apps/users/views.py:31`) already handles by creating a profile when one is absent.
- **`Person.save()` geocoding** — extracted into an explicit service function (`apps/people/services.py`) that the repository calls on create and update. Behavior is unchanged, including the Nominatim retry loop and the `ValidationError` raised when geocoding fails. Making the call explicit rather than an implicit `save()` side effect also makes it testable in isolation.

### 4.2 Document IDs

Firestore document IDs are strings, replacing integer primary keys. The Flutter client is largely tolerant of this already:

- Already string-safe: `person.dart:76` (`as String`), `person.dart:116`, `contact_log.dart:44`, `trip.dart:95` (all `.toString()`), `station.dart:28` (dynamic).
- **Hard breaks requiring change:** `trip.dart:178` and `trip.dart:264` cast `json['id'] as int?` for `TripLeg` and `TripStop`.

Airports and Stations retain integer IDs because the project controls that data directly, so `airport.dart:48` is unaffected.

**This means the task is not strictly backend-only** — it requires loosening two casts in `frontend/lib/models/trip.dart`.

### 4.3 GeoJSON API Contract

`PersonSerializer` is currently a `GeoFeatureModelSerializer`, emitting a GeoJSON **Feature** envelope which `person.dart:110` parses via `Person.fromGeoJson`, reading coordinates as `[longitude, latitude]`.

Since `rest_framework_gis` is being removed, a small hand-rolled `GeoFeatureSerializer` base class must reproduce that envelope exactly:

```json
{
  "id": "<doc-id>",
  "type": "Feature",
  "geometry": {"type": "Point", "coordinates": [lng, lat]},
  "properties": { ... }
}
```

Failing to preserve this would cause every person to silently disappear from the map rather than raising an error.

### 4.4 Ownership Validation

`apps/people/serializers.py:26` narrows `self.fields['person'].queryset` to the requesting user's people. This is the control asserted by `test_cannot_create_log_for_other_user_person` (added in commit e81891d). With no ORM querysets available, it becomes an **explicit ownership check in the repository**: creating a contact log must verify the target person's `owner_key` matches the requesting user before the write.

### 4.5 Indexes

Composite indexes are required for `owner_key` combined with any `order by` (e.g. contact logs ordered by `contacted_at` descending, mirroring the existing `people_contactlog_recent_idx`). These must be declared in `firestore.indexes.json`. **Missing composite indexes fail at query time, not at deploy time** — so index coverage is part of the acceptance criteria, verified against the emulator.

## 5. Reference Data as an In-Memory Index

`apps/airports/reference.py` and `apps/stations/reference.py` each load a bundled JSON file once into a module-level singleton of frozen dataclasses, retaining existing integer IDs.

`get_nearby(lat, lng, radius_km=None, count=10)` keeps its current signature and ordering semantics, implemented as a Haversine sweep. At 4,551 airports this is well under a millisecond — faster than the PostGIS query it replaces, since there is no network round trip. If the station dataset proves large enough to matter, a 1°-cell bucket index reduces the scan to neighboring cells; **measure before adding that complexity.**

The `Airport` and `Station` Django models, their migrations, and their admin registrations are deleted.

### 5.1 Data Pipelines

Both datasets become fully reproducible, committed artifacts with symmetric pipelines.

**Airports (existing, to be simplified).** `import_airports.py:10` downloads the OurAirports CSV from `raw.githubusercontent.com/davidmegginson/ourairports-data/main/airports.csv` and filters to `large_airport`/`medium_airport` entries possessing an IATA code, yielding the current 4,551 records. `airports_export.json` is a flattened export retaining `name/iata/type/city/country/lat/lon`.

**Stations (new).** A `fetch_stations` command queries the public Overpass API (no API key) for US railway stations and halts, applies the existing categorization logic from `import_stations.py` — Amtrak/`uic_ref` → `major_station`, subway/metro/BART/PATH → `subway_station`, LIRR/Metro-North/NJ Transit/MBTA/Caltrain/Metra/SEPTA/Metrolink → `commuter_rail_station` — and writes `stations_export.json` in the same flattened shape.

US scope is inferred from the existing importer: `country` defaults to `'USA'`, `MAJOR_NAMES` is entirely US stations, and every commuter network listed is American.

**Pipeline simplification:** both datasets collapse from three phases (download → load into PostGIS → export JSON) to two (**fetch → write committed JSON**), with no database involved.

**Overpass caveat:** the API rate-limits and can time out on large area queries. The fetch needs a generous timeout and likely state-by-state chunking. This is acceptable because the output is committed — the script runs when fresher data is wanted, not on every build.

## 6. Local Development and the Emulator

`firebase.json`, `firestore.rules`, and `firestore.indexes.json` are added at the repository root.

The `db` service (`postgis/postgis:16-3.4`) is removed from `docker-compose.yml` and replaced by a `firebase-emulator` service. The emulator image requires a JRE, since the Firestore emulator is a Java process — this is the one non-obvious piece of the compose work.

**`FIRESTORE_EMULATOR_HOST` is the key mechanism:** `firebase-admin` detects this environment variable and routes to the emulator automatically, so **no application code branches on environment**. This is what makes local development a trustworthy predictor of production behavior; an `if DEBUG:` in application code would invalidate that.

The Auth emulator is configured in `firebase.json` at the same time. It is unused until task D, but costs one config block now and avoids revisiting the file later.

**Makefile changes:** `make db` (psql shell) is removed; `make mig` narrows to Django's auth/admin tables only; `make seed` is added to populate the emulator with sample data.

**Seeding, not migration.** There is no production data to move. `make seed` writes representative sample data directly into the emulator.

## 7. Media and File Storage

`Person.profile_image` and `UserProfile.profile_image` are `ImageField`s. Django's `ImageField` is what accepts the upload, writes it to storage, generates the filename from `upload_to`, and produces `.url` — **all of which leaves with the model.** `UserProfileView` (`apps/users/views.py:24`) wires up `MultiPartParser` specifically for image upload, and would break outright.

The **storage abstraction is therefore in scope**; only the GCS backend is deferred.

Django's `STORAGES` setting (available in Django 6) makes this environment configuration rather than code branching — the same property that makes `FIRESTORE_EMULATOR_HOST` clean. Repositories call `default_storage.save()` and `default_storage.url()` and never name a filesystem or a bucket.

**Local development.** `STORAGES["default"]` → `FileSystemStorage` writing to `MEDIA_ROOT`, served by the `static()` call already present in `config/urls.py`. No new dependencies, works fully offline, behaves as it does today.

The Firebase **Storage emulator** was considered and rejected for this task: pointing `google-cloud-storage` at it via `STORAGE_EMULATOR_HOST` is fiddly and it adds a second Java process to compose. The storage abstraction — not the emulator — is what provides production parity here.

**Production (deferred to the deployment task).** `STORAGES["default"]` → `GoogleCloudStorage` from `django-storages[google]`, against a Cloud Storage bucket, authenticating via the Cloud Run service account rather than a key file.

This is forced by the platform, not optional: `docker-compose.prod.yml` persists uploads to a `media_data` Docker volume, and **Cloud Run has an ephemeral filesystem with no volume equivalent** — anything written to local disk dies when the instance recycles. Because the abstraction ships in this task, that later change is a settings swap rather than a code change.

Cloud Storage's free tier comfortably covers profile images at pre-revenue scale, though current free-tier terms should be verified when billing is set up.

## 8. Out of Scope

- **Task D — Auth0 → Google Cloud Identity Platform.** To be filed as a sibling ClickUp task. GCIP (the consumer CIAM product built on Firebase Authentication) is *not* Cloud Identity, the per-seat Workspace employee directory. When D lands it retires `RegisterView`, `PasswordResetRequestView`, `PasswordResetConfirmView`, `rest_framework_simplejwt`, `apps/users/auth.py`, `apps/users/throttles.py`, and the Flutter `register_screen.dart` / `forgot_password_screen.dart`. It also resolves the SQLite durability question (§9).
- **Cloud Run deployment and GCP Terraform.**
- **GCS storage backend wiring** (§7) — abstraction ships here, backend ships with deployment.
- **Firestore security rules beyond deny-all placeholders.** Django uses the Admin SDK, which bypasses rules entirely. They become load-bearing only if Flutter ever talks to Firestore directly.

## 9. Risks and Open Items

| Risk | Assessment |
|---|---|
| `unique_together(trip, sequence_order)` loss | Sharpest risk. Transactional enforcement in the repository is correct but genuinely weaker than a database constraint. |
| Missing composite indexes | Fail at query time, not deploy time. Mitigated by emulator-backed tests (§10). |
| **SQLite durability on Cloud Run** | SQLite is ephemeral on Cloud Run, so JIT-provisioned users would vanish on instance recycle. Acceptable for local development; **must be resolved by task D before any production deploy.** |
| `frontend/lib/models/trip.dart` casts | Two-line change; means this task is not purely backend. |
| Overpass rate limits | Mitigated by committed output and chunked fetching. |
| Geocoding on write | `Person.save()` calls Nominatim synchronously. Behavior is preserved verbatim as it moves to `apps/people/services.py` (§4.1.1), including the retry loop and `ValidationError` on failure. |
| Loss of Django admin | All six models leave the ORM, so admin manages only `User`/`Group` (§4.1.1). Accepted; Emulator UI and Firestore Console replace it. |

## 10. Error Handling

Firestore failures surface as `google.api_core.exceptions` and are mapped **centrally** rather than per-view:

- `ServiceUnavailable` / `DeadlineExceeded` → HTTP 503
- `NotFound` → HTTP 404
- `PermissionDenied` → HTTP 500 (a misconfiguration, never a user-facing condition)

A missing emulator produces an explicit startup error naming `FIRESTORE_EMULATOR_HOST`, rather than a bare connection-refused traceback.

The `sequence_order` uniqueness transaction retries on contention. Existing geocoding `ValidationError` behavior is preserved.

## 11. Testing Strategy

**Tests run against the emulator, not mocks.** Mocking Firestore would verify assumptions about Firestore rather than Firestore itself, defeating the purpose of having an emulator.

**Acceptance bar: all 395 lines of `tests/test_api_security.py` must pass with their assertions unchanged.** These encode the ownership isolation from commit e81891d — `test_trip_data_isolation`, `test_contact_logs_isolation`, `test_contact_logs_person_filter_isolation`, `test_cannot_create_log_for_other_user_person`, `test_person_recency_fields_public_gating`. They are the safety net for the repository rewrite and **must not be weakened to accommodate it.**

Rewrites required:

- `apps/airports/tests.py` (76 lines) and `apps/stations/tests.py` (36 lines) — currently construct `Point` objects; retarget at the in-memory index.
- `apps/trips/tests.py` (391 lines) — heaviest lift.
- `apps/people/tests.py` (113 lines).
- `apps/users/tests.py` (43 lines) and `JWTAuthTests` — largely unaffected, since auth remains on SQLite.

Collection purging between tests is implemented as a `TestCase` mixin invoked from `setUp`, matching the project's existing Django test runner conventions (`make test` runs `manage.py test`; tests subclass DRF's `APITestCase`). The project does not use pytest.

## 12. Success Criteria

1. `make up` starts Django and the Firebase emulator with **no PostgreSQL container**.
2. `make seed` populates the emulator with sample data.
3. The full test suite passes against the emulator, with `tests/test_api_security.py` assertions unchanged.
4. `airports_export.json` and `stations_export.json` are both committed and reproducible via their fetch commands.
5. No `django.contrib.gis` / `rest_framework_gis` imports remain.
6. `backend/Dockerfile` contains no GDAL/PROJ/PostGIS system dependencies.
7. The Flutter app runs against the local backend with map pins, trips, and contact logs functioning.
