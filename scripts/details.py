#!/usr/bin/env python3
import requests
import csv

# -------------------
# Variables
# -------------------
email = ""
api_key = ""
output_file = "cloudways_servers.csv"  # CSV output

# -------------------
# Step 1: Get access token
# -------------------
token_url = "https://api.cloudways.com/api/v1/oauth/access_token"
payload = {'email': email, 'api_key': api_key}

response = requests.post(token_url, data=payload)
response.raise_for_status()
token_data = response.json()
access_token = token_data.get('access_token')

if not access_token:
    print("Failed to get access token")
    exit(1)

# -------------------
# Step 2: Get server list
# -------------------
servers_url = "https://api.cloudways.com/api/v1/server"
headers = {"Accept": "application/json", "Authorization": f"Bearer {access_token}"}

response = requests.get(servers_url, headers=headers)
response.raise_for_status()
servers_data = response.json()

# -------------------
# Step 3: Prepare CSV
# -------------------
with open(output_file, mode='w', newline='') as csv_file:
    writer = csv.writer(csv_file)
    writer.writerow(["Label", "Public IP", "PHP Version", "MySQL/MariaDB Version"])

    # -------------------
    # Step 4: Loop servers
    # -------------------
    if servers_data.get("status") and "servers" in servers_data:
        for server in servers_data["servers"]:
            label = server.get("label")
            public_ip = server.get("public_ip")
            server_id = server.get("id")

            try:
                settings_url = f"https://api.cloudways.com/api/v1/server/manage/settings?server_id={server_id}"
                response = requests.get(settings_url, headers=headers)
                response.raise_for_status()
                settings_data = response.json()

                package_versions = settings_data.get("settings", {}).get("package_versions", {})
                php_version = package_versions.get("php", "Unknown")
                mysql_version = package_versions.get("mariadb", "Unknown")

                writer.writerow([label, public_ip, php_version, mysql_version])
                print(f"Saved: {label} - {public_ip} - PHP {php_version} - MySQL/MariaDB {mysql_version}")

            except Exception as e:
                print(f"Failed to fetch settings for {label} ({public_ip}): {e}")
    else:
        print("No servers found or error in response")

print(f"\nCSV file generated: {output_file}")

