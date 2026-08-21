#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "backend.tf" ] && [ ! -f "backend.tf.example" ]; then
  echo "terraform backend configuration not found"
  exit 1
fi

echo "backend configuration detected"

echo "run terraform init before production apply"
