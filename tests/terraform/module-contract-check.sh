#!/usr/bin/env bash
set -euo pipefail

ROOT="infrastructure/terraform"

if [ ! -d "$ROOT" ]; then
  echo "terraform root missing: $ROOT"
  exit 1
fi

for module in "$ROOT"/modules/*; do
  [ -d "$module" ] || continue

  if [ ! -f "$module/main.tf" ]; then
    echo "module missing main.tf: $module"
    exit 1
  fi

done

echo "Terraform module contract check passed"
