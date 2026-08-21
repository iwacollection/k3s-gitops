#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE=${1:-tfplan.json}

if [[ ! -f "${PLAN_FILE}" ]]; then
  echo "missing terraform plan json: ${PLAN_FILE}"
  exit 1
fi

CREATE=$(jq '[.resource_changes[] | select(.change.actions | index("create"))] | length' "${PLAN_FILE}")
DESTROY=$(jq '[.resource_changes[] | select(.change.actions | index("delete"))] | length' "${PLAN_FILE}")
REPLACE=$(jq '[.resource_changes[] | select((.change.actions | index("delete")) and (.change.actions | index("create")))] | length' "${PLAN_FILE}")

echo "create=${CREATE}"
echo "destroy=${DESTROY}"
echo "replace=${REPLACE}"

if [[ "${DESTROY}" != "0" || "${REPLACE}" != "0" ]]; then
  echo "unsafe terraform change detected"
  exit 1
fi

echo "terraform adoption safety check passed"
