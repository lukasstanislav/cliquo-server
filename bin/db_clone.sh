#!/bin/bash
# =============================================================
# Clone Remote MySQL DB -> Local MySQL in Docker (streamed)
# =============================================================
# - Uses SSH (remote mysqldump)
# - Streams dump directly into `docker exec ... mysql`
# - Recreates the local database before import
# - Safe defaults for InnoDB (single-transaction, etc.)
# =============================================================

set -Eeuo pipefail

# --------- CONFIG (edit these) --------------------------------

# SSH to remote
SSH_USER="root"
SSH_HOST="cliquo.cz"
SSH_PORT=20008

# Remote DB credentials & DB name
REMOTE_DB_HOST="localhost"
REMOTE_DB_USER="root2"
REMOTE_DB_PASS="kT96yo52sbq"
REMOTE_DB_NAME="licard"

# Local Docker MySQL target
LOCAL_DOCKER_CONTAINER="cliquo_mysql"
LOCAL_DB_NAME="licard"
LOCAL_DB_USER="root"
LOCAL_DB_PASS="gdkZS6S6_Sf2ss9ss6556"

# Compression (speeds network; set to "true" or "false")
USE_GZIP=true

# Extra mysqldump options (safe for InnoDB; includes routines/triggers/events)
DUMP_OPTS="--single-transaction --quick --routines --triggers --events --default-character-set=utf8mb4 --set-gtid-purged=OFF"

# ---------------------------------------------------------------

# Small helper to print status
log() { printf "\n[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# Validate docker container is running
ensure_container_running() {
  if ! docker inspect -f '{{.State.Running}}' "$LOCAL_DOCKER_CONTAINER" >/dev/null 2>&1; then
    echo "ERROR: Docker container '$LOCAL_DOCKER_CONTAINER' not found or not running." >&2
    exit 1
  fi
}

# Execute a MySQL statement inside the container
mysql_exec() {
  local sql="$1"
  docker exec -e MYSQL_PWD="${LOCAL_DB_PASS}" -i "$LOCAL_DOCKER_CONTAINER" \
    mysql -u "${LOCAL_DB_USER}" -e "$sql"
}

# Import a stream into the local DB
mysql_import_stream() {
  if [ "${USE_GZIP}" = true ]; then
    gunzip -c | docker exec -i "$LOCAL_DOCKER_CONTAINER" sh -c \
      "MYSQL_PWD='${LOCAL_DB_PASS}' mysql -u '${LOCAL_DB_USER}' '${LOCAL_DB_NAME}'"
  else
    docker exec -i "$LOCAL_DOCKER_CONTAINER" sh -c \
      "MYSQL_PWD='${LOCAL_DB_PASS}' mysql -u '${LOCAL_DB_USER}' '${LOCAL_DB_NAME}'"
  fi
}

# Build the remote dump command (wrapped to keep password out of process list)
remote_dump_cmd() {
  if [ "${USE_GZIP}" = true ]; then
    # dump -> gzip
    printf "MYSQL_PWD='%s' mysqldump -h '%s' -u '%s' %s '%s' | gzip -c" \
      "${REMOTE_DB_PASS}" "${REMOTE_DB_HOST}" "${REMOTE_DB_USER}" "${DUMP_OPTS}" "${REMOTE_DB_NAME}"
  else
    # plain dump
    printf "MYSQL_PWD='%s' mysqldump -h '%s' -u '%s' %s '%s'" \
      "${REMOTE_DB_PASS}" "${REMOTE_DB_HOST}" "${REMOTE_DB_USER}" "${DUMP_OPTS}" "${REMOTE_DB_NAME}"
  fi
}

main() {
  log "Verifying Docker container '${LOCAL_DOCKER_CONTAINER}' is running..."
  ensure_container_running

  log "Recreating local database '${LOCAL_DB_NAME}' in container '${LOCAL_DOCKER_CONTAINER}'..."
  mysql_exec "CREATE DATABASE \`${LOCAL_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

  log "Starting remote dump from ${SSH_USER}@${SSH_HOST}:${REMOTE_DB_NAME} (SSH port ${SSH_PORT})..."
  # Stream dump over SSH and import into local Docker MySQL
  # shellcheck disable=SC2046
  if [ "${USE_GZIP}" = true ]; then
    # gzip-compressed stream
    ssh -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" "$(remote_dump_cmd)" \
      | mysql_import_stream
  else
    # uncompressed stream
    ssh -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" "$(remote_dump_cmd)" \
      | mysql_import_stream
  fi

  log "✅ Database clone completed successfully into '${LOCAL_DB_NAME}'."
}

main "$@"