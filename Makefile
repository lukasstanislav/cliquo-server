init:
	@bin/docker_check.sh
	docker network inspect cliquo_net >/dev/null 2>&1 || docker network create --driver bridge cliquo_net

up:
	docker compose up -d --build

down:
	docker compose down

restart:
	make down up

domains:
	@grep -R "server_name" config/ | sed 's/.*server_name//' | sed 's/;//' | tr ' ' '\n' | grep -v '^$$' | awk '!seen[$$0]++'

crontab:
	@crontab -l | grep -v '^#'

certbot-renew:
	@docker compose run cliquo_certbot renew 2>&1 | grep -v "Found orphan containers"
