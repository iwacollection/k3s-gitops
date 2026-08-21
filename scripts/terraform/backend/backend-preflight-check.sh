#!/usr/bin/env bash
set -euo pipefail

check(){
  command -v "$1" >/dev/null 2>&1 || { echo "missing: $1"; exit 1; }
}

check terraform
check az

echo "terraform: $(terraform version | head -n1)"
echo "azure-cli: $(az version --query '"azure-cli"' -o tsv)"

echo "Backend preflight passed"
