#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"

BASE_PATH="/home/master/applications/${APP_NAME}"
WEBROOT="${BASE_PATH}/public_html"
PRIVATE_HTML="${BASE_PATH}/private_html"
BACKUP_FILE="${WEBROOT}/${APP_NAME}.zip"
SQL_FILE="${WEBROOT}/${APP_NAME}.sql"

usage() {
    echo "Usage: backup.sh <app_name>"
    exit 1
}

error_exit() {
    echo "ERROR: $1"
    exit 1
}

echo "Initializing backup script..."

# 1. Validate argument
[[ -z "$APP_NAME" ]] && usage

# 2. Validate Linux user exists
if ! id "$APP_NAME" &>/dev/null; then
    error_exit "Application user '$APP_NAME' does not exist on this server."
fi

# 3. Validate application directories
[[ ! -d "$BASE_PATH" ]] && error_exit "Application path not found: $BASE_PATH"
[[ ! -d "$WEBROOT" ]] && error_exit "Webroot not found: $WEBROOT"

echo "Application validated: $APP_NAME"
echo "Webroot: $WEBROOT"

cd "$WEBROOT"

# 4. Export database
if [[ -f "wp-config.php" ]]; then
    echo "WordPress detected. Exporting database using wp-cli."
    wp db export "$SQL_FILE" --allow-root
else
    echo "Non-WordPress application. Exporting database using mysqldump."
    mysqldump "$APP_NAME" > "$SQL_FILE"
fi

# 5. Create zip archive
echo "Creating backup archive..."
find . -type f -print | zip "$BACKUP_FILE" -@

# 6. Include private_html if exists
if [[ -d "$PRIVATE_HTML" ]]; then
    echo "Including private_html directory."
    find "$PRIVATE_HTML" -type f -print | zip "$BACKUP_FILE" -@
fi

# 7. Cleanup SQL file
rm -f "$SQL_FILE"

# 8. Set ownership
chown "${APP_NAME}:${APP_NAME}" "$BACKUP_FILE"

echo "Backup completed successfully."
echo "Backup location: $BACKUP_FILE"
