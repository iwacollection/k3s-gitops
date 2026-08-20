#!/usr/bin/env bash
set -euo pipefail

ROOT=${1:-infrastructure/terraform}

missing=0

while IFS= read -r file; do
  if grep -q 'resource "azurerm_' "$file"; then
    if ! grep -q 'prevent_destroy' "$file"; then
      echo "WARNING: missing prevent_destroy: $file"
      missing=$((missing+1))
    fi
  fi
done < <(find "$ROOT" -name '*.tf' -type f)

if [ "$missing" -gt 0 ]; then
  echo "Critical Terraform resources require lifecycle protection review"
  exit 1
fi

echo "Lifecycle protection check passed"
