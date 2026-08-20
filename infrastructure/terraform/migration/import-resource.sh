#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <terraform_address> <azure_resource_id>"
  exit 1
fi

ADDRESS=$1
RESOURCE_ID=$2

echo "Importing existing resource into Terraform state"
echo "address=$ADDRESS"
echo "id=$RESOURCE_ID"

terraform import "$ADDRESS" "$RESOURCE_ID"
terraform plan
