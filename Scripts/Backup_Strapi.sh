#!/bin/bash

STRAPI_PATH="/var/www/strapi"
BACKUP_NAME="strapi-backup-$(date +%Y-%m-%d_%H-%M)"
WEBDAV_URL="https://894200.connect.kdrive.infomaniak.com/Backup/Lino-Cloud/Strapi"
USER="MAIL"
PASS="PASSWORD"

cd $STRAPI_PATH || { echo "Error: Could not find Strapi directory"; exit 1; }

sudo -u ec2-user npm run strapi export -- --no-encrypt -f "$BACKUP_NAME"

FULL_FILENAME=$(ls ${BACKUP_NAME}* 2>/dev/null)

if [ -f "$FULL_FILENAME" ]; then
    echo "Export successful: $FULL_FILENAME"
    echo "Uploading to kDrive via WebDAV..."
    
    UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$USER:$PASS" -T "$FULL_FILENAME" "$WEBDAV_URL/$FULL_FILENAME")
    
    if [ "$UPLOAD_STATUS" -eq 201 ] || [ "$UPLOAD_STATUS" -eq 204 ] || [ "$UPLOAD_STATUS" -eq 200 ]; then
        echo "Upload successful (HTTP $UPLOAD_STATUS). Cleaning up..."
        rm "$FULL_FILENAME"
    else
        echo "Upload failed with HTTP status: $UPLOAD_STATUS"
        exit 1
    fi
else
    echo "Error: Export file was not created."
    exit 1
fi