#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
shift || true  # Shift to process flags

INCLUDE_PRIVATE=false

# Parse flags
while getopts ":p" opt; do
  case "$opt" in
    p) INCLUDE_PRIVATE=true ;;
    *)
      echo "Usage: backup.sh <app_name> [-p]"
      exit 1
      ;;
  esac
done

BASE_PATH="/home/master/applications/${APP_NAME}"
WEBROOT="${BASE_PATH}/public_html"
PRIVATE_HTML="${BASE_PATH}/private_html"
BACKUP_FILE="${WEBROOT}/${APP_NAME}.zip"
SQL_FILE="${WEBROOT}/${APP_NAME}.sql"

usage() {
    echo "Usage: backup.sh <app_name> [-p]"
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

# 3. Validate webroot
[[ ! -d "$WEBROOT" ]] && error_exit "Webroot not found: $WEBROOT"

echo "Application validated: $APP_NAME"
echo "Webroot: $WEBROOT"

cd "$WEBROOT"

# 4. Export database inside public_html
if [[ -f "wp-config.php" ]]; then
    echo "WordPress detected. Exporting database using wp-cli."
    wp db export "$SQL_FILE" --allow-root
else
    echo "Non-WordPress application. Exporting database using mysqldump."
    mysqldump "$APP_NAME" > "$SQL_FILE"
fi

# 5. Create zip archive including hidden files
echo "Creating backup archive (optimized with hidden files)..."

# Include all files in current directory including hidden ones
find . -mindepth 1 -print | zip -q "$BACKUP_FILE" -@

# Optionally include private_html
if $INCLUDE_PRIVATE; then
    if [[ -d "../private_html" ]]; then
        echo "Including private_html directory..."
        find ../private_html -type f -print | zip -q "$BACKUP_FILE" -@
    else
        echo "Warning: private_html directory not found — skipping."
    fi
else
    echo "Skipping private_html as requested."
fi

# 6. Cleanup SQL file
rm -f "$SQL_FILE"

# 7. Set ownership
chown "${APP_NAME}:" "$BACKUP_FILE"

echo "Backup completed successfully."
echo "Backup location: $BACKUP_FILE"
