#!/bin/bash
# ============================================
# RSYNC REMOTE TO LOCAL CLONE SCRIPT
# ============================================
# Description:
#   This script clones a remote directory to a local folder using rsync over SSH.
#   It preserves file permissions, ownerships, and timestamps.
# ============================================

# ---------- CONFIGURATION ----------
REMOTE_USER="root"
REMOTE_HOST="cliquo.cz"
REMOTE_PORT=20008
REMOTE_DIR="/var/www/licard"
LOCAL_DIR="/root/docker/licard"

# ---------- EXECUTION ----------
echo "Starting rsync clone from ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR} to ${LOCAL_DIR}"
echo "Using SSH port ${REMOTE_PORT}..."

# Perform the rsync operation
rsync -az -e "ssh -p ${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" "${LOCAL_DIR}/"

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Rsync completed successfully."
else
    echo "❌ Rsync encountered an error."
    exit 1
fi