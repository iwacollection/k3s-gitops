#!/usr/bin/env bash
set -euo pipefail

# Generate Azure resource inventory for Terraform adoption.
# Usage: ./azure-resource-inventory.sh [output-file]

OUTPUT=${1:-azure-resource-inventory.json}

command -v az >/dev/null || { echo "Azure CLI is required"; exit 1; }

az resource list --output json > "${OUTPUT}"

echo "Inventory written to ${OUTPUT}"
