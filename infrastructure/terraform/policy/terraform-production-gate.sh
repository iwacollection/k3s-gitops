#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE=${1:-tfplan}

if [ ! -f "$PLAN_FILE" ]; then
  echo "plan file not found: $PLAN_FILE"
  exit 1
fi

terraform show -json "$PLAN_FILE" > terraform-plan.json

python3 - <<'PY'
import json
with open('terraform-plan.json') as f:
    data=json.load(f)

blocked=[]
for item in data.get('resource_changes', []):
    actions=item.get('change',{}).get('actions',[])
    if 'delete' in actions:
        blocked.append({
            'address': item.get('address'),
            'actions': actions
        })

if blocked:
    print('Terraform destructive change detected:')
    for x in blocked:
        print(x)
    raise SystemExit(1)

print('Terraform production gate passed: no destructive changes detected')
PY
