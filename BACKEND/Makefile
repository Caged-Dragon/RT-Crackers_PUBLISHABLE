.PHONY: compile test docker-up docker-down migrate
compile:
	python -m compileall -q app tests alembic worker.py

test:
	pytest -q

docker-up:
	docker compose up -d --build

docker-down:
	docker compose down

migrate:
	alembic upgrade head
