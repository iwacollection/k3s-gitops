#!/usr/bin/env bash
set -euo pipefail

PLAN_JSON=${1:-tfplan.json}

if [[ ! -f "$PLAN_JSON" ]]; then
  echo "missing terraform plan json: $PLAN_JSON"
  exit 1
fi

python3 - "$PLAN_JSON" <<'PY'
import json
import sys

path=sys.argv[1]
data=json.load(open(path))
changes=data.get("resource_changes", [])

bad=[]
for item in changes:
    actions=item.get("change",{}).get("actions",[])
    if "delete" in actions or ("create" in actions and "delete" in actions):
        bad.append({
            "address": item.get("address"),
            "actions": actions
        })

if bad:
    print("Unsafe resource adoption detected")
    for x in bad:
        print(x)
    sys.exit(1)

print("Import validation passed: no delete/replace detected")
PY
