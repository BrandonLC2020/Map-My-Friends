# Makefile
up:
	docker compose up

# Debug mode: starts the stack with debugpy on port 5678 for VS Code attach.
# Use "Django: Attach (Docker)" in VS Code after running this.
debug:
	docker compose -f docker-compose.yml -f docker-compose.debug.yml up --build

build:
	docker compose build

down:
	docker compose down

mig:
	docker compose exec api python manage.py makemigrations
	docker compose exec api python manage.py migrate

user:
	docker compose exec api python manage.py createsuperuser

airports:
	docker compose exec api python manage.py import_airports

stations:
	@read -p "JSON File Path (default: train_stations.json): " file_path; \
	docker compose exec api python manage.py import_stations $${file_path:-train_stations.json}

shell:
	docker compose exec api python manage.py shell

emulator:
	docker compose up firestore

ui:
	@echo "Emulator UI: http://localhost:4000"

test:
	docker compose exec api python manage.py test 2>&1 | tee .gemini/last_test_results.txt

# Poetry helpers
install:
	docker compose exec api poetry install

add:
	@read -p "Package name: " package; \
	docker compose exec api poetry add $$package

update:
	docker compose exec api poetry update
