#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
ENV_DIR="$ROOT_DIR/infrastructure/terraform/environments/production"

if [ ! -d "$ENV_DIR" ]; then
  echo "production terraform environment missing"
  exit 1
fi

if [ ! -f "$ENV_DIR/backend.tf" ]; then
  echo "backend.tf missing"
  exit 1
fi

cd "$ENV_DIR"
terraform init -backend=false

echo "terraform backend validation passed"
