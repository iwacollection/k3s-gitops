#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION=${1:-}

if [ -z "$SUBSCRIPTION" ]; then
  echo "usage: $0 <subscription-id>"
  exit 1
fi

az account set --subscription "$SUBSCRIPTION"
az resource list --output json
