#!/bin/bash

set -e

# Configuration
N8N_DIR="/srv/stacks/n8n"
BACKUP_DIR="/tmp/n8n-backup"
BACKUP_NAME="n8n-backup-$(date +%Y-%m-%d_%H-%M)"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Infomaniak kDrive WebDAV
WEBDAV_URL="https://894200.connect.kdrive.infomaniak.com/Backup/Lino-Cloud/n8n"
USER="YOUR_EMAIL"
PASS="YOUR_PASSWORD"

echo "==> Starting n8n backup: ${BACKUP_NAME}"
mkdir -p "${BACKUP_PATH}"

echo "==> Backing up configuration..."
cp "${N8N_DIR}/docker-compose.yml" "${BACKUP_PATH}/"
[ -f "${N8N_DIR}/.env" ] && cp "${N8N_DIR}/.env" "${BACKUP_PATH}/"

echo "==> Stopping n8n (integrity check)..."
docker compose -f "${N8N_DIR}/docker-compose.yml" stop

echo "==> Backing up volume: n8n_n8n_data..."
docker run --rm \
    -v "n8n_n8n_data:/data:ro" \
    -v "${BACKUP_PATH}:/backup" \
    alpine tar czf "/backup/n8n_n8n_data.tar.gz" -C /data .

echo "==> Starting n8n..."
docker compose -f "${N8N_DIR}/docker-compose.yml" up -d

echo "==> Compressing archive..."
cd "${BACKUP_DIR}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

echo "==> Uploading to kDrive (${BACKUP_SIZE})..."
UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$USER:$PASS" \
    -T "${BACKUP_NAME}.tar.gz" \
    "$WEBDAV_URL/${BACKUP_NAME}.tar.gz")

if [ "$UPLOAD_STATUS" -eq 201 ] || [ "$UPLOAD_STATUS" -eq 204 ] || [ "$UPLOAD_STATUS" -eq 200 ]; then
    echo "==> Upload successful"
    rm -rf "${BACKUP_DIR}"
    echo "==> Backup finished: ${BACKUP_NAME}.tar.gz"
else
    echo "==> Upload failed (HTTP $UPLOAD_STATUS)"
    exit 1
fi