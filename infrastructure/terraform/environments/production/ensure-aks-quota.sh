#!/usr/bin/env bash
set -euo pipefail

REGION="${AKS_REGION:-eastus}"
VM_SIZE="${AKS_VM_SIZE:-Standard_D2s_v7}"
# Production convergence can temporarily run the old system pool, a full
# replacement `systemtmp` pool and the new workload pool at the same time.
# Eight vCPUs was enough for steady state but not for the HA/AZ rotation peak.
# Keep a 16-vCPU buffer so both regional and VM-family quotas cover the
# transition without weakening the requested HA topology.
HEADROOM_VCPUS="${AKS_QUOTA_HEADROOM_VCPUS:-16}"
RBAC_RETRY_ATTEMPTS="${AKS_QUOTA_RBAC_RETRY_ATTEMPTS:-12}"
EFFECTIVE_RETRY_ATTEMPTS="${AKS_QUOTA_EFFECTIVE_RETRY_ATTEMPTS:-30}"
SUBSCRIPTION_ID="$(printf '%s' "${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID is required}" | tr -d '\r\n')"
SCOPE="/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/${REGION}"

usage_json() {
  az vm list-usage --location "$REGION" --output json
}

usage_value() {
  local json="$1"
  local resource_name="$2"
  local field="$3"
  jq -r --arg resource "$resource_name" --arg field "$field" '
    .[] | select((.name.value // "") == $resource) | .[$field]
  ' <<<"$json" | head -n1
}

ensure_quota_provider() {
  local state
  state="$(az provider show --namespace Microsoft.Quota --query registrationState --output tsv 2>/dev/null || true)"

  if [[ "$state" == "Registered" ]]; then
    echo "Microsoft.Quota provider is already registered."
    return 0
  fi

  for attempt in $(seq 1 "$RBAC_RETRY_ATTEMPTS"); do
    echo "Registering Microsoft.Quota provider (attempt ${attempt}/${RBAC_RETRY_ATTEMPTS})."

    if az provider register --namespace Microsoft.Quota --wait --only-show-errors >/dev/null 2>&1; then
      state="$(az provider show --namespace Microsoft.Quota --query registrationState --output tsv 2>/dev/null || true)"
      if [[ "$state" == "Registered" ]]; then
        echo "Microsoft.Quota provider registration completed."
        return 0
      fi
    fi

    sleep 15
  done

  echo "::error::Microsoft.Quota provider registration is still unauthorized or incomplete after RBAC propagation retries."
  return 1
}

request_quota() {
  local resource_name="$1"
  local localized_name="$2"
  local current="$3"
  local limit="$4"
  local target=$((current + HEADROOM_VCPUS))

  echo "quota=${localized_name} resource=${resource_name} current=${current} limit=${limit} target=${target}"

  if (( limit >= target )); then
    echo "${localized_name}: sufficient quota."
    return 0
  fi

  echo "${localized_name}: requesting quota increase to ${target}."

  az extension add --name quota --upgrade --only-show-errors >/dev/null
  ensure_quota_provider

  local update_ok=0
  for attempt in $(seq 1 "$RBAC_RETRY_ATTEMPTS"); do
    if az quota update \
      --resource-name "$resource_name" \
      --scope "$SCOPE" \
      --limit-object "value=${target}" \
      --resource-type dedicated \
      --only-show-errors \
      --output none; then
      update_ok=1
      break
    fi

    echo "${localized_name}: quota write not ready (attempt ${attempt}/${RBAC_RETRY_ATTEMPTS}); waiting for RBAC/API propagation."
    sleep 15
  done

  if (( update_ok == 0 )); then
    echo "::error::Unable to request ${localized_name} quota after retries. Verify the Terraform-managed Quota Request Operator assignment and subscription quota policy."
    return 1
  fi

  for attempt in $(seq 1 "$EFFECTIVE_RETRY_ATTEMPTS"); do
    effective_limit="$(az quota show \
      --resource-name "$resource_name" \
      --scope "$SCOPE" \
      --query properties.limit.value \
      --output tsv 2>/dev/null || true)"

    if [[ "$effective_limit" =~ ^[0-9]+$ ]] && (( effective_limit >= target )); then
      echo "${localized_name}: quota increase effective at ${effective_limit}."
      return 0
    fi

    echo "${localized_name}: quota request pending (attempt ${attempt}/${EFFECTIVE_RETRY_ATTEMPTS}, effective=${effective_limit:-unknown})."
    sleep 60
  done

  echo "::error::${localized_name} quota request was submitted but did not become effective within the workflow wait window. Requested=${target}."
  return 1
}

USAGE_JSON="$(usage_json)"
REGIONAL_RESOURCE="cores"
REGIONAL_NAME="Total Regional vCPUs"
REGIONAL_CURRENT="$(usage_value "$USAGE_JSON" "$REGIONAL_RESOURCE" currentValue)"
REGIONAL_LIMIT="$(usage_value "$USAGE_JSON" "$REGIONAL_RESOURCE" limit)"

if [[ ! "$REGIONAL_CURRENT" =~ ^[0-9]+$ || ! "$REGIONAL_LIMIT" =~ ^[0-9]+$ ]]; then
  echo "::error::Unable to resolve ${REGIONAL_NAME} usage for ${REGION}."
  exit 1
fi

FAMILY_RESOURCE="$(az vm list-skus \
  --location "$REGION" \
  --size "$VM_SIZE" \
  --resource-type virtualMachines \
  --query '[0].family' \
  --output tsv)"

if [[ -z "$FAMILY_RESOURCE" ]]; then
  echo "::error::Unable to resolve VM quota family for ${VM_SIZE} in ${REGION}."
  exit 1
fi

FAMILY_CURRENT="$(usage_value "$USAGE_JSON" "$FAMILY_RESOURCE" currentValue)"
FAMILY_LIMIT="$(usage_value "$USAGE_JSON" "$FAMILY_RESOURCE" limit)"

if [[ ! "$FAMILY_CURRENT" =~ ^[0-9]+$ || ! "$FAMILY_LIMIT" =~ ^[0-9]+$ ]]; then
  echo "::error::Unable to resolve ${FAMILY_RESOURCE} usage for ${REGION}."
  exit 1
fi

echo "AKS quota preflight: region=${REGION} vm_size=${VM_SIZE} headroom=${HEADROOM_VCPUS}"
request_quota "$REGIONAL_RESOURCE" "$REGIONAL_NAME" "$REGIONAL_CURRENT" "$REGIONAL_LIMIT"
request_quota "$FAMILY_RESOURCE" "${VM_SIZE} family vCPUs" "$FAMILY_CURRENT" "$FAMILY_LIMIT"

FINAL_USAGE="$(usage_json)"
FINAL_REGIONAL_CURRENT="$(usage_value "$FINAL_USAGE" "$REGIONAL_RESOURCE" currentValue)"
FINAL_REGIONAL_LIMIT="$(usage_value "$FINAL_USAGE" "$REGIONAL_RESOURCE" limit)"
FINAL_FAMILY_CURRENT="$(usage_value "$FINAL_USAGE" "$FAMILY_RESOURCE" currentValue)"
FINAL_FAMILY_LIMIT="$(usage_value "$FINAL_USAGE" "$FAMILY_RESOURCE" limit)"

echo "AKS quota ready:"
echo "  regional: ${FINAL_REGIONAL_CURRENT}/${FINAL_REGIONAL_LIMIT}"
echo "  family(${FAMILY_RESOURCE}): ${FINAL_FAMILY_CURRENT}/${FINAL_FAMILY_LIMIT}"
