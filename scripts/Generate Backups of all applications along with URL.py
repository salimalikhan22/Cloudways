#!/usr/bin/env python3

import requests
import subprocess
import re
import sys
import os
import shutil

# =====================================================
# CONFIGURATION
# =====================================================
email = "rahul@propbuying.com"
api_key = "fwbp9yjxi6IqdZhYn3kD5dUhGms7kl"
server_fqdn_input = "1436916.cloudwaysapps.com"  # <-- PASS SERVER FQDN HERE

# =====================================================

# -----------------------------
# STEP 1: Get Access Token
# -----------------------------
token_url = "https://api.cloudways.com/api/v1/oauth/access_token"
payload = {'email': email, 'api_key': api_key}

response = requests.post(token_url, data=payload)
response.raise_for_status()

access_token = response.json().get("access_token")
if not access_token:
    print("Access token not received.")
    sys.exit(1)

headers = {
    "Accept": "application/json",
    "Authorization": f"Bearer {access_token}"
}

# -----------------------------
# STEP 2: Fetch Servers
# -----------------------------
servers_url = "https://api.cloudways.com/api/v1/server"
response = requests.get(servers_url, headers=headers)
response.raise_for_status()
servers_data = response.json()

target_server = None
for server in servers_data.get("servers", []):
    if server.get("server_fqdn") == server_fqdn_input:
        target_server = server
        break

if not target_server:
    print("Server not found.")
    sys.exit(1)

apps = target_server.get("apps", [])
if not apps:
    print("No applications found.")
    sys.exit(0)

print("\nStarting backups...\n")

results = []

# -----------------------------
# Download backup script once
# -----------------------------
subprocess.run(
    "curl -s -o /tmp/backup.sh https://raw.githubusercontent.com/salimalikhan22/Cloudways/refs/heads/master/scripts/backup.sh",
    shell=True,
    check=True
)

# -----------------------------
# Symlink-aware applications base
# -----------------------------
applications_base = os.path.realpath("/home/master/applications")

# -----------------------------
# PROCESS EACH APPLICATION
# -----------------------------
for app in apps:
    app_label = app.get("label")
    mysql_db_name = app.get("mysql_db_name")

    if not mysql_db_name:
        continue

    print(f"Processing: {app_label} ({mysql_db_name})")

    # -----------------------------
    # Run backup script and capture output
    # -----------------------------
    try:
        proc = subprocess.run(
            ["bash", "/tmp/backup.sh", mysql_db_name],
            capture_output=True,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Backup failed for {mysql_db_name}: {e}")
        continue

    output = proc.stdout + proc.stderr

    # -----------------------------
    # Extract exact backup zip location
    # -----------------------------
    match = re.search(r'Backup location:\s*(\S+\.zip)', output)
    if not match:
        print(f"Could not detect backup zip for {mysql_db_name}")
        continue

    source_zip = match.group(1)
    if not os.path.exists(source_zip):
        print(f"Backup zip does not exist: {source_zip}")
        continue

    # -----------------------------
    # Detect webroot from nginx config
    # -----------------------------
    nginx_config_file = f"/etc/nginx/sites-available/{mysql_db_name}"
    webroot_path = None

    try:
        with open(nginx_config_file, "r") as f:
            content = f.read()
        match_root = re.search(r'root\s+([^;]+);', content)
        if match_root:
            webroot_path = match_root.group(1).strip()
    except Exception as e:
        print(f"Could not read nginx config for {mysql_db_name}: {e}")
        continue

    if not webroot_path or not os.path.isdir(webroot_path):
        print(f"Invalid or missing webroot for {mysql_db_name}")
        # If no valid webroot, leave ZIP in original location
        destination_zip = source_zip
    else:
        # Move ZIP only if webroot is NOT default public_html
        if not webroot_path.endswith("public_html"):
            destination_zip = os.path.join(webroot_path, f"{mysql_db_name}.zip")
            if os.path.exists(destination_zip):
                os.remove(destination_zip)
            shutil.move(source_zip, destination_zip)
        else:
            # Keep ZIP in original location
            destination_zip = source_zip

    # -----------------------------
    # Extract site URL from server.nginx
    # -----------------------------
    nginx_file = os.path.join(applications_base, mysql_db_name, "conf/server.nginx")
    site_url = "Unknown"

    try:
        with open(nginx_file, "r") as f:
            content = f.read()
        match_server = re.search(r"server_name\s+([^;]+);", content)
        if match_server:
            site_url = match_server.group(1).split()[0].strip()
    except Exception:
        pass

    final_url = f"https://{site_url}/{mysql_db_name}.zip"

    results.append({
        "label": app_label,
        "db": mysql_db_name,
        "url": final_url,
        "location": destination_zip
    })


# -----------------------------
# FINAL SUMMARY
# -----------------------------
print("\n======================================")
print("FINAL BACKUP SUMMARY")
print("======================================\n")

for r in results:
    print(f"{r['label']} - {r['db']} - {r['url']} - {r['location']}")

print("\nAll backups completed successfully.\n")
