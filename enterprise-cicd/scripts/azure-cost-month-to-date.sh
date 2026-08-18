#!/usr/bin/env bash

# Read-only Azure Cost Management inventory.
# No resource create/update/delete operations are performed.

set -u

LOG="${1:-azure_cost_month_to_date.log}"
SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
AKS_RG="${AKS_RG:-group-test}"
AKS_NODE_RG="${AKS_NODE_RG:-MC_group-test_k8s-test-cicd_eastus}"
API_VERSION="2025-03-01"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

print_query() {
  local scope="$1"
  local title="$2"
  local outfile="$3"

  echo
  echo "========================================="
  echo " $title"
  echo "========================================="

  local body
  body='{
    "type": "Usage",
    "timeframe": "MonthToDate",
    "dataset": {
      "granularity": "None",
      "aggregation": {
        "totalCost": {
          "name": "PreTaxCost",
          "function": "Sum"
        }
      },
      "grouping": [
        {
          "type": "Dimension",
          "name": "ResourceId"
        }
      ]
    }
  }'

  if ! az rest \
      --method post \
      --url "https://management.azure.com${scope}/providers/Microsoft.CostManagement/query?api-version=${API_VERSION}" \
      --headers Content-Type=application/json \
      --body "$body" \
      -o json > "$outfile" 2>"${outfile}.err"; then
    echo "Cost query failed for scope: $scope"
    cat "${outfile}.err" || true
    echo "This is commonly caused by Cost Management data not being available yet or the signed-in identity lacking cost-read permission."
    return 0
  fi

  python3 - "$outfile" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

props = data.get("properties", {})
columns = props.get("columns", [])
rows = props.get("rows", [])

names = [c.get("name", "") for c in columns]
print("Columns:", " | ".join(names) if names else "<none>")

if not rows:
    print("No cost rows returned yet.")
    sys.exit(0)

indexes = {name: i for i, name in enumerate(names)}

def value(row, name, default=""):
    i = indexes.get(name)
    return row[i] if i is not None and i < len(row) else default

normalized = []
for row in rows:
    cost = value(row, "PreTaxCost", value(row, "Cost", 0))
    resource = value(row, "ResourceId", "")
    currency = value(row, "Currency", value(row, "CurrencyCode", ""))
    try:
        ncost = float(cost or 0)
    except (TypeError, ValueError):
        ncost = 0.0
    normalized.append((ncost, currency, resource))

normalized.sort(key=lambda x: x[0], reverse=True)

total = sum(x[0] for x in normalized)
print(f"Total returned cost: {total:.6f}")
print()
print("Cost | Currency | ResourceId")
print("-----|----------|-----------")
for cost, currency, resource in normalized:
    print(f"{cost:.6f} | {currency} | {resource}")
PY
}

{
  echo "========================================="
  echo " AZURE COST INVENTORY - READ ONLY"
  echo "========================================="
  echo "Subscription: ${SUBSCRIPTION_ID:-UNKNOWN}"
  echo "AKS Resource Group: $AKS_RG"
  echo "AKS Node Resource Group: $AKS_NODE_RG"
  echo "Timeframe: MonthToDate"
  echo
  echo "NOTE: Azure Cost Management data can lag behind recent resource creation/usage."

  if [ -z "$SUBSCRIPTION_ID" ]; then
    echo "ERROR: No active Azure subscription found. Run az login first."
  else
    print_query "/subscriptions/$SUBSCRIPTION_ID" \
      "[1] SUBSCRIPTION MONTH-TO-DATE COST BY RESOURCE" \
      "$TMP_DIR/subscription.json"

    print_query "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AKS_RG" \
      "[2] AKS RESOURCE GROUP MONTH-TO-DATE COST" \
      "$TMP_DIR/aks-rg.json"

    print_query "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AKS_NODE_RG" \
      "[3] AKS NODE RESOURCE GROUP MONTH-TO-DATE COST" \
      "$TMP_DIR/aks-node-rg.json"
  fi

  echo
  echo "========================================="
  echo " COST INVENTORY FINISHED"
  echo "========================================="
} 2>&1 | tee "$LOG"
