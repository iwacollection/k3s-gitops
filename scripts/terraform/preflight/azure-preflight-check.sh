#!/usr/bin/env bash
set -euo pipefail

fail(){
  echo "FAILED: $1"
  exit 1
}

command -v terraform >/dev/null || fail "terraform not installed"
command -v az >/dev/null || fail "azure cli not installed"

terraform version
az account show >/dev/null || fail "azure authentication missing"

SUB=$(az account show --query id -o tsv)
echo "Azure subscription: ${SUB}"

echo "Preflight completed"
