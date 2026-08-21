#!/usr/bin/env bash
set -euo pipefail

check() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1"; exit 1; }
}

check terraform
check az

echo "[terraform]"
terraform version

echo "[azure account]"
az account show >/dev/null || { echo "azure login required"; exit 1; }
az account show --query '{subscription:id,name:name,tenant:tenantId}' -o json

echo "preflight passed"
