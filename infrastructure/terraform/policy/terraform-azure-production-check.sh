#!/usr/bin/env bash
set -euo pipefail

PLAN_JSON=${1:-tfplan.json}

if [ ! -f "$PLAN_JSON" ]; then
  echo "missing terraform plan json: $PLAN_JSON"
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  changes=$(jq '[.resource_changes[]? | select(.change.actions | index("delete"))] | length' "$PLAN_JSON")

  if [ "$changes" -gt 0 ]; then
    echo "ERROR: destructive Terraform changes detected"
    jq '.resource_changes[] | select(.change.actions | index("delete")) | {address,actions:.change.actions}' "$PLAN_JSON"
    exit 1
  fi
fi

echo "Terraform production validation passed"
