#!/bin/bash

# Appwrite Backup Script - Infomaniak kDrive

set -e

APPWRITE_DIR="/srv/stacks/appwrite"
BACKUP_DIR="/tmp/appwrite-backup"
BACKUP_NAME="appwrite-backup-$(date +%Y-%m-%d_%H-%M)"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Infomaniak kDrive WebDAV
WEBDAV_URL="https://894200.connect.kdrive.infomaniak.com/Backup/Lino-Cloud/Appwrite"
USER="YOUR_EMAIL"
PASS="YOUR_PASSWORD"

echo "==> Starting Appwrite backup: ${BACKUP_NAME}"
mkdir -p "${BACKUP_PATH}"

echo "==> Backing up configuration..."
cp "${APPWRITE_DIR}/docker-compose.yml" "${BACKUP_PATH}/" || { echo "Error: docker-compose.yml not found"; exit 1; }
if [ -f "${APPWRITE_DIR}/.env" ]; then
    cp "${APPWRITE_DIR}/.env" "${BACKUP_PATH}/"
fi

echo "==> Backing up database..."
DB_ROOT_PASS=$(docker exec appwrite-mariadb printenv _APP_DB_ROOT_PASS 2>/dev/null)

if [ -z "$DB_ROOT_PASS" ]; then
    echo "Error: Could not retrieve DB root password"
    exit 1
fi

docker exec appwrite-mariadb mysqldump \
    --user=root \
    --password="${DB_ROOT_PASS}" \
    --all-databases \
    --single-transaction \
    --quick \
    --lock-tables=false \
    > "${BACKUP_PATH}/database.sql" || { echo "Error: Database export failed"; exit 1; }

echo "    Database: $(du -h ${BACKUP_PATH}/database.sql | cut -f1)"

echo "==> Backing up volumes..."
VOLUMES=$(docker volume ls --filter "name=appwrite" --format "{{.Name}}")

for VOLUME in $VOLUMES; do
    VOLUME_NAME=$(basename "$VOLUME")
    echo "    Volume: ${VOLUME_NAME}..."
    
    docker run --rm \
        -v "${VOLUME}:/data:ro" \
        -v "${BACKUP_PATH}:/backup" \
        alpine tar czf "/backup/${VOLUME_NAME}.tar.gz" -C /data . 2>/dev/null || true
    
    if [ -f "${BACKUP_PATH}/${VOLUME_NAME}.tar.gz" ]; then
        echo "      -> $(du -h ${BACKUP_PATH}/${VOLUME_NAME}.tar.gz | cut -f1)"
    fi
done

cat > "${BACKUP_PATH}/backup-info.txt" <<EOF
Appwrite Backup
===============
Date: $(date '+%Y-%m-%d %H:%M:%S')
Server: $(hostname)

Containers:
$(docker ps --filter "name=appwrite" --format "{{.Names}}" | head -5)

Volumes:
$(ls -lh ${BACKUP_PATH}/*.tar.gz 2>/dev/null | wc -l) volumes backed up
EOF

echo "==> Compressing backup..."
cd "${BACKUP_DIR}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}" || { echo "Error: Compression failed"; exit 1; }

BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
echo "    Backup size: ${BACKUP_SIZE}"

echo "==> Uploading to kDrive..."
FULL_FILENAME="${BACKUP_NAME}.tar.gz"

UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$USER:$PASS" \
    -T "$FULL_FILENAME" \
    "$WEBDAV_URL/$FULL_FILENAME" \
    --connect-timeout 30 \
    --max-time 7200)

if [ "$UPLOAD_STATUS" -eq 201 ] || [ "$UPLOAD_STATUS" -eq 204 ] || [ "$UPLOAD_STATUS" -eq 200 ]; then
    echo "    Upload successful (HTTP $UPLOAD_STATUS)"
    
    # Clean up temporary files immediately
    rm -rf "${BACKUP_DIR}"
    
    echo "==> Backup completed: ${FULL_FILENAME} (${BACKUP_SIZE})"
else
    echo "Error: Upload failed (HTTP $UPLOAD_STATUS)"
    # Clean up on error too
    rm -rf "${BACKUP_DIR}"
    exit 1
fi