#!/usr/bin/env bash
set -euo pipefail

RESOURCE_ID=${1:-}
RESOURCE_ADDRESS=${2:-}

if [[ -z "$RESOURCE_ID" || -z "$RESOURCE_ADDRESS" ]]; then
  echo "usage: $0 <azure_resource_id> <terraform_resource_address>"
  exit 1
fi

echo "terraform import $RESOURCE_ADDRESS $RESOURCE_ID"
