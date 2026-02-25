#!/usr/bin/env python3

import requests
import sys
import os
import paramiko
import csv
from typing import List, Dict

# -------------------
# CONFIGURATION
# -------------------
EMAIL = "@.ae"
API_KEY = ""

BASE_V1 = "https://api.cloudways.com/api/v1"
TIMEOUT = 15

CSV_FILE = "server_disk_report.csv"


# -------------------
# GET ACCESS TOKEN
# -------------------
def get_access_token(email: str, api_key: str) -> str:
    url = f"{BASE_V1}/oauth/access_token"
    payload = {"email": email, "api_key": api_key}

    response = requests.post(url, data=payload, timeout=TIMEOUT)
    response.raise_for_status()

    token = response.json().get("access_token")
    if not token:
        raise Exception("Failed to retrieve access token")

    return token


# -------------------
# FETCH SERVERS
# -------------------
def fetch_servers(headers: Dict) -> List[Dict]:
    url = f"{BASE_V1}/server"
    response = requests.get(url, headers=headers, timeout=TIMEOUT)
    response.raise_for_status()

    data = response.json()
    if not data.get("status"):
        raise Exception("Failed to fetch servers")

    servers = []

    for server in data.get("servers", []):
        servers.append({
            "label": server.get("label"),
            "public_ip": server.get("public_ip"),
            "status": server.get("status"),
            "instance_type": server.get("instance_type"),
            "local_backups": server.get("local_backups"),
            "apps_count": len(server.get("apps", [])),
            "master_user": server.get("master_user"),
            "master_password": server.get("master_password"),
        })

    return servers


# -------------------
# SSH DISK USAGE
# -------------------
def get_disk_usage_via_ssh(ip: str, username: str, password: str) -> Dict:
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        ssh.connect(
            hostname=ip,
            username=username,
            password=password,
            timeout=10
        )

        stdin, stdout, stderr = ssh.exec_command("df -h / | tail -1")
        output = stdout.read().decode().strip()
        ssh.close()

        parts = output.split()

        return {
            "total": parts[1],
            "used": parts[2],
            "available": parts[3],
            "percent": parts[4]
        }

    except Exception:
        return {
            "total": "N/A",
            "used": "N/A",
            "available": "N/A",
            "percent": "N/A"
        }


# -------------------
# MAIN
# -------------------
def main():
    if not EMAIL or not API_KEY:
        print("Please set CW_EMAIL and CW_API_KEY environment variables.")
        sys.exit(1)

    print("Generating CSV report...\n")

    token = get_access_token(EMAIL, API_KEY)

    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {token}"
    }

    servers = fetch_servers(headers)

    if not servers:
        print("No servers found.")
        return

    rows = []

    for server in servers:
        disk = get_disk_usage_via_ssh(
            server["public_ip"],
            server["master_user"],
            server["master_password"]
        )

        rows.append([
            server["label"],
            server["public_ip"],
            server["status"],
            server["instance_type"],
            server["local_backups"],
            server["apps_count"],
            disk["total"],
            disk["used"],
            disk["available"],
            disk["percent"]
        ])

        print(f"Processed: {server['label']}")

    # Write CSV
    with open(CSV_FILE, mode="w", newline="") as file:
        writer = csv.writer(file)

        writer.writerow([
            "Label",
            "IP Address",
            "Status",
            "Instance Type",
            "Local Backups",
            "Number of Apps",
            "Disk Total",
            "Disk Used",
            "Disk Available",
            "Disk Usage %"
        ])

        writer.writerows(rows)

    print(f"\nCSV report generated: {CSV_FILE}\n")


if __name__ == "__main__":
    main()
