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
```
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

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOTW0FWvnGzbfHfju1+bPn6K8ms73iFosBeuQCnVzQa root@cliquolite
```

## 1. Migrace FS

Nastav potřebné údaje do úvodních proměnných v `/root/docker/bin/fs_clone.sh` a spusť. Běh bude trvat do minuty.

## 2. Migrace DB

Nastav potřebné údaje do úvodních proměnných v `/root/docker/bin/db_clone.sh` a spusť. Běh bude trvat minuty až desítky minut.

## 3. konfigurace a spuštění

Přidej složku .docker

Nastartuj kontejner webu:
```
cd /root/docker/licard
docker build --file ./.docker/Dockerfile --tag licard .
docker run -d \
  --name licard \
  --network cliquo_net \
  --restart unless-stopped \
  -v "$(pwd)/:/app" \
  licard
```

Nastav proxy vytvořením konfigurace (**SPRÁVNĚ POJMENUJ SOUBOR!**):
```
cd /root/docker/cliquo-proxy/config
cp host_prod.conf.example licard.conf
```

Uprav konfiguraci a restartuj proxy:
```
cd /root/docker/cliquo-proxy && make restart
```

## 4. Doména

Přenastav DNS na `83.167.224.194`

Zatím poběží jen port 80 (http), protože jsme nevystavili certifikát. Port 80 by měl mít přesměrování na 443, takže pokud o request skončí chybou.

```
cd /root/docker/cliquo_proxy
docker compose run certbot certonly --webroot -w /var/www/certbot --email stanislav@cliquo.cz --agree-tos --no-eff-email \
    -d licard-liberec.cz -d www.licard-liberec.cz
```

```
docker exec cliquo_proxy nginx -s reload
```

Nastav core config (databáze)

# Shared MySQL Database

* Host: `cliquo_mysql`
* Port: `3306`
* User: `root`
* Password: `gdkZS6S6_Sf2ss9ss6556`
