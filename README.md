# O tomto serveru

Jde o finální řešení pro dožití projektů ClIQUO. Koncipované je tak, aby měl každý projekt vlastní docker kontejner a tak byla zaručena kompatibilita OS i do budoucna.

## Uspořádání

* `/root/docker` - vše je v této složce.
* `/root/docker/cliquo-server` - správa serveru (proxy, databáze, certbot, adminer)
* `/root/docker/cliquo-server/bin` - skripty pro migrace sem na server
* `/root/docker/...` - samotné weby

## Databáze

Adminer je k dispozici na adrese [s4.cliquo.cz](https://s4.cliquo.cz/), heslo je centrální pro root

## Docker

Vše je propojeno pomocí docker network `cliquo_net` v režimu bridge. Jednotlivé kontejnery se tedy vzájemně vidí pod svými jmény.

Build probíhá lokálně, protože každý projekt bude mít nejspíše speciální konfiguraci.

Tipy a triky:
```bash
# Seznam běžících kontejnerů:
docker ps

# Vstup do kontejneru
docker exec -it licard /bin/bash

# Zastavení kontejneru:
docker stop licard
```

# Migrace webu sem

## 0. SSH přístup (pokud ještě není)

Pro migrace je nutné zavést na vzdálený server lokální SSH public key:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOTW0FWvnGzbfHfju1+bPn6K8ms73iFosBeuQCnVzQa root@cliquolite
```

## 1. Migrace FS a DB

Nastav potřebné údaje do úvodních proměnných v `/root/docker/bin/fs_clone.sh` a spusť. Běh bude trvat do minuty.

Nastav potřebné údaje do úvodních proměnných v `/root/docker/bin/db_clone.sh` a spusť. Běh bude trvat minuty až desítky minut.

## 2. Spuštění kontejneru

Přidej složku `.docker` z jiného projektu (není potřeba v ní nic upravovat)

Nastartuj kontejner webu:
```bash
cd /root/docker/licard
docker build --file ./.docker/Dockerfile --tag licard .
docker run -d \
  --name grindl \
  --network cliquo_net \
  --restart unless-stopped \
  -v "$(pwd)/:/app" \
  grindl
```

## 3. Proxy

1. Najdi jaké domény budou potřeba v `core/config`

Nastav proxy vytvořením konfigurace v `config/nginx/`, převezmi ale pouze první část na portu 80.

Uprav Restartuj proxy:
```bash
docker exec cliquo_proxy nginx -s reload
```

Přenastav DNS na `83.167.224.194`
```bash
docker compose run cliquo_certbot certonly --webroot -w /var/www/certbot --email stanislav@cliquo.cz --agree-tos --no-eff-email \
    -d licard-liberec.cz -d www.licard-liberec.cz
```

Restart proxy znovu:
```bash
docker exec cliquo_proxy nginx -s reload
```

Nastav core config (databáze)
```xml
<variable id="host">cliquo_mysql</variable>
<variable id="user">root</variable>
<variable id="password">gdkZS6S6_Sf2ss9ss6556</variable>
```

V případě potřeby proveď update CLIQUO Engine:
```bash
wget -q -O cq_upd.sh https://repo.cliquo.cz/cdn/source/update.sh && chmod +x cq_upd.sh && ./cq_upd.sh
```

# Shared MySQL Database

* Host: `cliquo_mysql`
* Port: `3306`
* User: `root`
* Password: `gdkZS6S6_Sf2ss9ss6556`
