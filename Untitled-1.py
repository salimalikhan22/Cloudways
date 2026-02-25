#!/usr/bin/env python3

import requests
import subprocess
import re
import sys

# -------------------
# CONFIGURATION
# -------------------
email = "salim.@.com"
api_key = ""
server_fqdn_input = "..com"  # <-- PASS SERVER FQDN HERE

# -------------------
# Step 1: Get access token
# -------------------
token_url = "https://api.cloudways.com/api/v1/oauth/access_token"
payload = {'email': email, 'api_key': api_key}

response = requests.post(token_url, data=payload)
response.raise_for_status()
access_token = response.json().get("access_token")

if not access_token:
    print("Failed to get access token")
    sys.exit(1)

headers = {
    "Accept": "application/json",
    "Authorization": f"Bearer {access_token}"
}

# -------------------
# Step 2: Fetch Servers
# -------------------
servers_url = "https://api.cloudways.com/api/v1/server"
response = requests.get(servers_url, headers=headers)
response.raise_for_status()
servers_data = response.json()

if not servers_data.get("status"):
    print("Failed to fetch servers")
    sys.exit(1)

target_server = None

for server in servers_data.get("servers", []):
    if server.get("server_fqdn") == server_fqdn_input:
        target_server = server
        break

if not target_server:
    print("Server FQDN not found")
    sys.exit(1)

apps = target_server.get("apps", [])

if not apps:
    print("No applications found on this server")
    sys.exit(0)

print("\nProcessing applications...\n")

# -------------------
# Step 3: Process Each Application
# -------------------
for app in apps:
    app_label = app.get("label")
    mysql_db_name = app.get("mysql_db_name")

    if not mysql_db_name:
        continue

    print(f"Running backup for: {app_label} ({mysql_db_name})")

    # -------------------
    # Step 4: Run backup_zip
    # -------------------
    try:
        subprocess.run(
            f'bash -c "backup_zip {mysql_db_name}"',
            shell=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Backup failed for {mysql_db_name}: {e}")
        continue

    # -------------------
    # Step 5: Read URL from nginx config
    # -------------------
    nginx_file = f"/home/master/applications/{mysql_db_name}/conf/server.nginx"
    site_url = "Unknown"

    try:
        with open(nginx_file, "r") as f:
            content = f.read()

            match = re.search(r"server_name\s+([^;]+);", content)
            if match:
                site_url = match.group(1).strip()
    except Exception as e:
        print(f"Could not read nginx config for {mysql_db_name}: {e}")

    # -------------------
    # Step 6: Final Output Format
    # -------------------
    zip_url = f"{site_url}/{mysql_db_name}.zip"

    print(f"{app_label} - {mysql_db_name} - {zip_url}")

print("\nAll applications processed.\n")
