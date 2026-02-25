#!/bin/bash

# Exit on error
set -e

echo "Whitelisting all domains in Imunify360..."

if ! command -v imunify360-agent >/dev/null 2>&1; then
    echo "Error: imunify360-agent not found."
    exit 1
fi

imunify360-agent whitelist domain add '*'

echo "Done."