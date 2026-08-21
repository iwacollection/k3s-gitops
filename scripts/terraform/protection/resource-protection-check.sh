#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-infrastructure/terraform}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "terraform directory not found: $TARGET_DIR"
  exit 1
fi

missing=0

while IFS= read -r file; do
  if ! grep -q "prevent_destroy" "$file"; then
    echo "WARNING: no prevent_destroy found in $file"
    missing=$((missing+1))
  fi
done < <(find "$TARGET_DIR" -name '*.tf' -type f)

if [ "$missing" -gt 0 ]; then
  echo "resource protection review required: $missing files"
else
  echo "resource protection baseline passed"
fi
