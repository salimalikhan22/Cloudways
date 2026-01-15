#!/bin/bash

# Change to the home directory
cd ~ || { echo "Failed to change to home directory."; exit 1; }

# Download the script
wget https://github.com/salimalikhan22/Cloudways/raw/refs/heads/master/scripts/apm.sh -O apm.sh
if [[ $? -ne 0 ]]; then
    echo "Failed to download the script."
    exit 1
fi

# Execute the downloaded script
bash apm.sh
if [[ $? -ne 0 ]]; then
    echo "The script encountered an error during execution."
    exit 1
fi

# Remove the script
rm -f apm.sh

echo "Script executed and removed successfully."
