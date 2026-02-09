# Makefile
up:
	docker compose up

build:
	docker compose build

down:
	docker compose down

mig:
	docker compose exec api poetry run python manage.py makemigrations
	docker compose exec api poetry run python manage.py migrate

user:
	docker compose exec api poetry run python manage.py createsuperuser

shell:
	docker compose exec api poetry run python manage.py shell

db:
	docker compose exec db psql -U mapuser -d mapfriends_db

test:
	docker compose exec api poetry run python manage.py test

# Poetry helpers
install:
	docker compose exec api poetry install

add:
	@read -p "Package name: " package; \
	docker compose exec api poetry add $$package

update:
	docker compose exec api poetry update
