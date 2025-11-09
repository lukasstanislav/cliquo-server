#!/bin/bash
# ============================================
# Prepares a project on local machine
# ============================================
# Description:
#   - requires the dir and db already to be cloned
# ============================================

# ---------- CONFIGURATION ----------
CONTAINER_NAME="klomadmiral"
DB_NAME="klomadmiral"
DIR="/root/docker/klomadmiral"
DOMAINS="klom-admiral.cz www.klom-admiral.cz wchs-c-2023.klom-admiral.cz"

# usualy no need to change
DB_DOCKER_CONTAINER="cliquo_mysql"
DB_USER="root"
DB_PASS="gdkZS6S6_Sf2ss9ss6556"
NETWORK_NAME="cliquo_net"
CERTBOT_SERVICE="cliquo_certbot"
NGINX_CONFIG_DIR="$(dirname "$0")/../config/nginx"
SERVER_IP="83.167.224.194"
DNS_SERVER="1.1.1.1"

# ---------- CHECKS ----------

echo "Docker network '$NETWORK_NAME'"
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo " ... ❌ Network '$NETWORK_NAME' not found. Run make init first."
    exit 1
else
    echo " ... ✅ Exists."
fi

# check that local db in the mysql container exists
echo "Database '$DB_NAME'"
if ! docker exec "$DB_DOCKER_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
    echo " ... ❌ Database '$DB_NAME' not found. Use cloning script first"
    exit 1
else
    echo " ... ✅ Exists."
fi

# check that local dirs exists
echo "Directory '$DIR'"
if [ ! -d "$DIR" ]; then
    echo " ... ❌ Directory '$DIR' does not exist. Use cloning script first"
    exit 1
else
    echo " ... ✅ Exists."
fi

echo "All checks passed successfully ✅"


# ---------- Build the container if not exists ----------
DIR_DOCKER="$DIR/.docker"
echo "Directory $DIR_DOCKER"
if [ ! -d "$DIR_DOCKER" ]; then
    echo " ... ✨ Creating one"
    cp -r "$(dirname "$0")/../template/.docker" $DIR_DOCKER
    echo " ... ✅ Created"
else
    echo " ... ✅ Exists"
fi

echo "Container $CONTAINER_NAME"
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo " ... ✨ Building and running container"
    cd "$DIR"
    docker build --file ./.docker/Dockerfile --tag $CONTAINER_NAME .
    docker run -d --name $CONTAINER_NAME --network cliquo_net --restart unless-stopped -v "$(pwd)/:/app" $CONTAINER_NAME
else
    echo " ... ✅ Exists"
fi


# ---------- Nginx certificate ----------
FIRST_DOMAIN=$(echo "$DOMAINS" | awk '{print $1}')
CERTNAME=$FIRST_DOMAIN
NGINX_CONF="$NGINX_CONFIG_DIR/$CONTAINER_NAME.conf"

echo "Domain DNS"
if ! command -v dig >/dev/null 2>&1; then
    echo " ... ❌ 'dig' command not found. Please install 'dnsutils' or 'bind9-dnsutils'."
    exit 1
fi
resolved_list=$( (dig +short @"$DNS_SERVER" A "$FIRST_DOMAIN"; dig +short @"$DNS_SERVER" AAAA "$FIRST_DOMAIN") | sort -u )
if echo "$resolved_list" | grep -qx "$SERVER_IP"; then
    echo " ... ✅ DNS OK ($FIRST_DOMAIN → $SERVER_IP)"
else
    echo " ... ❌ DNS mismatch for '$FIRST_DOMAIN'."
    echo "     Resolved IPs (fresh): ${resolved_list:-<none>}"
    echo "     Expected:              $SERVER_IP"
    echo "     Fix DNS and wait for propagation before running again."
    exit 1
fi

echo "Certificate for '$CERTNAME'"
CERT_PATH="$(dirname "$0")/../data/certs/live/$CERTNAME"
if [ ! -d "$CERT_PATH" ]; then
    echo " ... ✨ Prepare the minimalistic nginx config"
    cp "$(dirname "$0")/../template/nginx/vhost_80.conf" $NGINX_CONF
    sed -i -e "s/%DOMAINS%/$DOMAINS/g" $NGINX_CONF
    echo " ... ✨ Reloading nginx"
    docker exec cliquo_proxy nginx -s reload
    echo " ... ✨ Creating new certificate"
    docker compose run --rm $CERTBOT_SERVICE certonly --webroot \
        -w /var/www/certbot \
        --email stanislav@cliquo.cz \
        --agree-tos \
        --no-eff-email \
        $(for domain in $DOMAINS; do echo -n "-d $domain "; done)

    # Double-check certificate file actually exists
    if [ ! -d "$CERT_PATH" ]; then
        echo " ... ❌ Certificate file not found after creation attempt!"
        exit 1
    fi

    echo " ... ✅ Certificate created (if no errors occurred)."
    echo " ... ✨ Prepare the full nginx config"
    cp "$(dirname "$0")/../template/nginx/vhost_443.conf" $NGINX_CONF
    sed -i -e "s/%DOMAINS%/$DOMAINS/g" $NGINX_CONF
    sed -i -e "s/%CERTNAME%/$CERTNAME/g" $NGINX_CONF
    sed -i -e "s/%CONTAINER_NAME%/$CONTAINER_NAME/g" $NGINX_CONF
    echo " ... ✨ Reloading nginx"
    docker exec cliquo_proxy nginx -s reload
else
    echo " ... ✅ Already exists."
fi

echo "-------------------------------------"
echo "1. Make sure the core config DB is set correctly, see README.md"
echo "2. Consider updating the CLIQUO Engine, see README.md"