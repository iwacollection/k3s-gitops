#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-azure_enterprise_cicd_preflight.log}"

{
  echo "========================================="
  echo "AZURE ENTERPRISE CICD - PHASE 1 PREFLIGHT"
  echo "========================================="
  echo

  echo "[1] Azure CLI"
  command -v az || true
  az version --output json 2>/dev/null || true
  echo

  echo "[2] Current Azure Account"
  az account show \
    --query '{subscriptionId:id,subscriptionName:name,tenantId:tenantId,user:user.name,state:state}' \
    --output json 2>/dev/null || true
  echo

  echo "[3] Available Subscriptions"
  az account list \
    --query '[].{subscriptionId:id,subscriptionName:name,tenantId:tenantId,state:state,isDefault:isDefault}' \
    --output table 2>/dev/null || true
  echo

  echo "[4] Terraform"
  command -v terraform || true
  terraform version 2>/dev/null || true
  echo

  echo "[5] Helm"
  command -v helm || true
  helm version --short 2>/dev/null || true
  echo

  echo "[6] kubectl"
  command -v kubectl || true
  kubectl version --client=true 2>/dev/null || true
  echo

  echo "[7] Git"
  git --version 2>/dev/null || true
  echo

  echo "========================================="
  echo "PREFLIGHT FINISHED"
  echo "========================================="
} >"$OUT" 2>&1

echo "Preflight complete: $OUT"
