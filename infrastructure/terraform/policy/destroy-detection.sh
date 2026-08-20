#!/usr/bin/env bash
set -euo pipefail

PLAN_JSON=${1:-tfplan.json}

if [ ! -f "$PLAN_JSON" ]; then
  echo "missing terraform plan json: $PLAN_JSON"
  exit 1
fi

DELETE_COUNT=$(jq '[.resource_changes[]? | select(.change.actions | index("delete"))] | length' "$PLAN_JSON")
REPLACE_COUNT=$(jq '[.resource_changes[]? | select((.change.actions | index("delete")) and (.change.actions | index("create")))] | length' "$PLAN_JSON")

echo "delete_count=$DELETE_COUNT"
echo "replace_count=$REPLACE_COUNT"

if [ "$DELETE_COUNT" -gt 0 ] || [ "$REPLACE_COUNT" -gt 0 ]; then
  echo "Terraform plan contains destructive changes. Manual approval required."
  exit 1
fi

echo "Terraform plan safety check passed."
