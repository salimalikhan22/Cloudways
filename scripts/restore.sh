#!/bin/bash
# Improved Simple Duplicity Restore Script
# Author: ChatGPT
# Last Edited: 2026-01-15

set -e

echo "===== Simple Duplicity Restore ====="

# Ask for application name
read -rp "Enter application name: " APP_NAME
if [ -z "$APP_NAME" ]; then
    echo "Application name is required!"
    exit 1
fi

# Ask restore type
echo "Restore type options:"
echo "1) Full Backup"
echo "2) Webfiles Only"
echo "3) Database Only"
echo "4) Specific Folder"
echo "5) Specific File"

read -rp "Enter choice (1-5): " TYPE_CHOICE

case $TYPE_CHOICE in
    1)
        RESTORE_TYPE="-r"
        ;;
    2)
        RESTORE_TYPE="-w"
        ;;
    3)
        RESTORE_TYPE="-d"
        ;;
    4)
        read -rp "Enter folder path relative to public_html (e.g., wp-includes): " SPECIFIC_FOLDER
        ;;
    5)
        read -rp "Enter file path relative to public_html (e.g., license.txt): " SPECIFIC_FILE
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Ask restore date/time (flexible formats)
read -rp "Enter restore date/time (e.g., 2026-01-02 or 2 Jan 2026 01:40:08): " INPUT_DATE
if [ -z "$INPUT_DATE" ]; then
    echo "Restore date/time is required!"
    exit 1
fi

# Convert date to duplicity format
# If time is provided, output YYYY-MM-DDTHH:MM:SS, otherwise YYYY-MM-DD
if date -d "$INPUT_DATE" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then
    FORMATTED_DATE=$(date -d "$INPUT_DATE" "+%Y-%m-%dT%H:%M:%S")
else
    echo "Invalid date format!"
    exit 1
fi

# Ask destination path (default tmp)
read -rp "Enter destination path (default: /home/master/applications/$APP_NAME/tmp): " DST_PATH
DST_PATH=${DST_PATH:-/home/master/applications/$APP_NAME/tmp}

echo
echo "Backup fetching started for '$APP_NAME'..."
echo "Restore type: $TYPE_CHOICE"
echo "Restore date/time: $FORMATTED_DATE"
echo "Destination path: $DST_PATH"
echo

# Run duplicity restore command
case $TYPE_CHOICE in
    1|2|3) # Full, webfiles, database
        /var/cw/scripts/bash/duplicity_restore.sh --src "$APP_NAME" $RESTORE_TYPE --dst "$DST_PATH" --time "$FORMATTED_DATE"
        ;;
    4) # Specific folder
        source /root/.duplicity && duplicity restore --no-encryption --no-print-statistics --s3-use-new-style -v 4 \
        -t "$FORMATTED_DATE" --file-to-restore "public_html/$SPECIFIC_FOLDER" \
        $(awk -F'[="]' '/S3_url/ {print $3}' /root/.duplicity)/apps/"$APP_NAME" "$DST_PATH/$SPECIFIC_FOLDER"
        ;;
    5) # Specific file
        source /root/.duplicity && duplicity restore --no-encryption --no-print-statistics --s3-use-new-style -v 4 \
        -t "$FORMATTED_DATE" --file-to-restore "public_html/$SPECIFIC_FILE" \
        $(awk -F'[="]' '/S3_url/ {print $3}' /root/.duplicity)/apps/"$APP_NAME" "$DST_PATH/$SPECIFIC_FILE"
        ;;
esac

echo
echo "Restore completed successfully!"