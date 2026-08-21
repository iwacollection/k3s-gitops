#!/usr/bin/env bash
set -euo pipefail

PLAN_JSON=${1:-terraform-plan.json}

if [[ ! -f "$PLAN_JSON" ]]; then
  echo "missing terraform plan json: $PLAN_JSON"
  exit 1
fi

if grep -Eq '"delete"|"replace"' "$PLAN_JSON"; then
  echo "ERROR: import validation detected delete or replace action"
  exit 1
fi

echo "Import validation passed"
