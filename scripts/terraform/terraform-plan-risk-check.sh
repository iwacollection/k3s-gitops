#!/usr/bin/env bash
set -euo pipefail

PLAN_JSON=${1:-tfplan.json}

if [ ! -f "$PLAN_JSON" ]; then
  echo "missing terraform plan json: $PLAN_JSON"
  exit 1
fi

python3 - "$PLAN_JSON" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

changes = data.get("resource_changes", [])
create = []
delete = []
replace = []

for item in changes:
    actions = item.get("change", {}).get("actions", [])
    addr = item.get("address", "unknown")
    if "create" in actions:
        create.append(addr)
    if "delete" in actions:
        delete.append(addr)
    if "replace" in actions or ("create" in actions and "delete" in actions):
        replace.append(addr)

print("Terraform Risk Summary")
print(f"create={len(create)}")
print(f"delete={len(delete)}")
print(f"replace={len(replace)}")

if delete:
    print("\nDELETE DETECTED")
    for x in delete:
        print(x)

if replace:
    print("\nREPLACE DETECTED")
    for x in replace:
        print(x)

# Production default safety policy
if delete or replace:
    print("\nBLOCK: destructive terraform change requires review")
    sys.exit(1)

print("PASS: no destructive terraform change detected")
PY
