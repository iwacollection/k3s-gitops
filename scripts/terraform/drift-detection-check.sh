#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE="${1:-drift-plan.json}"

if [ ! -f "$PLAN_FILE" ]; then
  echo "missing terraform plan json: $PLAN_FILE"
  exit 1
fi

CHANGES=$(jq '[.resource_changes[]? | select(.change.actions != ["no-op"])] | length' "$PLAN_FILE")

if [ "$CHANGES" -gt 0 ]; then
  echo "Terraform drift detected: $CHANGES resource changes"
  jq '.resource_changes[]? | select(.change.actions != ["no-op"]) | {address, actions:.change.actions}' "$PLAN_FILE"
  exit 2
fi

echo "No Terraform drift detected"
