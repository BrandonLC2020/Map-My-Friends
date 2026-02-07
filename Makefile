# Makefile
up:
	docker compose up

down:
	docker compose down

mig:
	docker compose exec api python manage.py makemigrations
	docker compose exec api python manage.py migrate

user:
	docker compose exec api python manage.py createsuperuser

shell:
	docker compose exec api python manage.py shell
