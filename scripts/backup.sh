#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"

BASE_PATH="/home/master/applications/${APP_NAME}"
WEBROOT="${BASE_PATH}/public_html"
PRIVATE_HTML="${BASE_PATH}/private_html"
BACKUP_FILE="${BASE_PATH}/${APP_NAME}.zip"
SQL_FILE="${WEBROOT}/${APP_NAME}.sql"

usage() {
    echo "Usage: backup.sh <app_name>"
    exit 1
}

# Validate input
[[ -z "$APP_NAME" ]] && usage
[[ ! -d "$WEBROOT" ]] && { echo "Error: Webroot not found at $WEBROOT"; exit 1; }

echo "Starting backup for application: $APP_NAME"

cd "$WEBROOT"

# Export database
if [[ -f "wp-config.php" ]]; then
    echo "WordPress detected. Exporting DB using wp-cli."
    wp db export "$SQL_FILE"
else
    echo "Non-WordPress app. Exporting DB using mysqldump."
    mysqldump "$APP_NAME" > "$SQL_FILE"
fi

# Create zip archive
echo "Creating zip archive..."
find . -type f -print | zip "$BACKUP_FILE" -@

# Include private_html if exists
if [[ -d "$PRIVATE_HTML" ]]; then
    echo "Including private_html in backup."
    find "$PRIVATE_HTML" -type f -print | zip "$BACKUP_FILE" -@
fi

# Cleanup SQL dump
rm -f "$SQL_FILE"

# Set ownership
chown "${APP_NAME}:${APP_NAME}" "$BACKUP_FILE"

echo "Backup completed successfully:"
echo " → $BACKUP_FILE"
