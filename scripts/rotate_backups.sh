#!/bin/bash
source ./env/backup.env
find "$BACKUP_FOLDER" -name "*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
echo "Rotated old backups."