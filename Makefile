init:
	@bin/docker_check.sh
	docker network inspect cliquo_net >/dev/null 2>&1 || docker network create --driver bridge cliquo_net

up:
	docker compose up -d --build

down:
	docker compose down

restart:
	make down up