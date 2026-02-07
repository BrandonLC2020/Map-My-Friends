# Map My Friends

A personal geospatial application to track and visualize friends' locations in relation to each other. This project uses a "Batteries Included" approach with **GeoDjango** for complex spatial queries and **Flutter** for a cross-platform mobile experience, all orchestrated via **Docker**.

## 🚀 Tech Stack

### Backend (The Geo-Engine)
* **Framework:** Django 6.0 + Django REST Framework
* **Database:** PostgreSQL 16 + PostGIS (Geospatial extension)
* **Dependency Manager:** Poetry 2.0+
* **Infrastructure:** Docker & Docker Compose
* **Hosting Goal:** AWS (App Runner/ECS)

### Frontend (The Map)
* **Framework:** Flutter (iOS/Android)
* **Map Rendering:** `flutter_map` (Leaflet based)
* **Map Data:** OpenStreetMap (OSM)
* **Geospatial Math:** `latlong2`

---

## 🛠 Prerequisites

1.  **Docker Desktop:** Required to run the backend and database.
2.  **Flutter SDK:** Required for running the mobile app locally.
3.  **Git:** To clone the repo.

---

## ⚡️ Quick Start

### 1. Backend Setup (Docker)
The backend is fully containerized. You do **not** need to install Python, GDAL, or PostGIS on your local machine.

```bash
# 1. Clone the repo
git clone [https://github.com/brandonlc2020/map-my-friends.git](https://github.com/brandonlc2020/map-my-friends.git)
cd map-my-friends

# 2. Build and Start the Containers
# This installs all Python dependencies (GDAL, etc.) inside the container.
docker compose up --build

```

Once running:

* **API Root:** [http://localhost:8000](https://www.google.com/search?q=http://localhost:8000)
* **Django Admin:** [http://localhost:8000/admin](https://www.google.com/search?q=http://localhost:8000/admin)

### 2. Frontend Setup (Flutter)

Open a **new terminal** tab (leave Docker running in the first one).

```bash
cd frontend

# 1. Install Dart dependencies
flutter pub get

# 2. Run the App (Select your Simulator/Emulator)
flutter run

```

---

## 🕹 Development Workflow & Commands

Since the backend runs inside a Docker container, you cannot simply type `python manage.py ...` in your local terminal. You must execute commands *inside* the container.

### Using the Makefile (Recommended)

A `Makefile` is included to shortcut these long commands:

| Action | Command | Actual Docker Command |
| --- | --- | --- |
| **Start Server** | `make up` | `docker compose up` |
| **Stop Server** | `make down` | `docker compose down` |
| **Run Migrations** | `make mig` | `docker compose exec api python manage.py makemigrations && ... migrate` |
| **Create Superuser** | `make user` | `docker compose exec api python manage.py createsuperuser` |
| **Open Python Shell** | `make shell` | `docker compose exec api python manage.py shell` |

### Manual Docker Commands

If you prefer running commands manually or need to run something custom:

**Apply Migrations:**

```bash
docker compose exec api python manage.py migrate

```

**Create New Migrations (after changing models):**

```bash
docker compose exec api python manage.py makemigrations

```

**Access the Container's Bash Shell:**

```bash
docker compose exec api /bin/bash

```

---

## 📂 Project Structure

```text
map-my-friends/
├── docker-compose.yml       # Orchestrates Django (api) and PostGIS (db)
├── Makefile                 # Shortcuts for Docker commands
├── backend/                 # Django Monolith
│   ├── Dockerfile           # Defines the Python environment (w/ GDAL)
│   ├── pyproject.toml       # Poetry dependencies
│   ├── manage.py
│   ├── config/              # Core Django settings
│   └── api/                 # Main application logic
└── frontend/                # Flutter App
    ├── lib/
    ├── pubspec.yaml
    └── ...

```

---

## ⚠️ Important Notes

### Apple Silicon (M1/M2/M3) Users

You may see a warning in the Docker logs:

> *The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)...*

**This is normal.** The official PostGIS Docker image does not yet have a native ARM64 build. Docker uses Rosetta emulation to run the Intel image. It is stable for development purposes, just slightly slower on startup.

### Database Connection

* **Internal (Docker):** The Django app talks to the DB via the hostname `db`.
* **External (GUI):** You can connect to the database using a tool like DBeaver or TablePlus:
* **Host:** `localhost`
* **Port:** `5432`
* **User:** `mapuser`
* **Password:** `password`
* **Database:** `mapfriends_db`
