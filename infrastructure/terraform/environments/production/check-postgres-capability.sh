#!/usr/bin/env bash
set -euo pipefail

DECLARED_REGION="eastus"
DECLARED_VERSION="16"
DECLARED_SKU="GP_Standard_D2s_v3"
DECLARED_SKU_TOKEN="standard_d2s_v3"
CANDIDATE_REGIONS=(eastus eastus2 centralus westus3)

printf 'PostgreSQL Flexible Server capability preflight\n'
printf 'Declared region=%s version=%s sku=%s\n' "$DECLARED_REGION" "$DECLARED_VERSION" "$DECLARED_SKU"

DECLARED_VALID=0
BEST_CANDIDATE_REGION=""
BEST_CANDIDATE_SKU=""

for region in "${CANDIDATE_REGIONS[@]}"; do
  echo "=== region: ${region} ==="
  stderr_file="$(mktemp)"

  if ! capabilities="$(az postgres flexible-server list-skus --location "$region" --output json 2>"$stderr_file")"; then
    echo "CLI_ERROR=$(cat "$stderr_file")"
    rm -f "$stderr_file"
    continue
  fi

  cli_stderr="$(cat "$stderr_file")"
  rm -f "$stderr_file"
  if [[ -n "$cli_stderr" ]]; then
    printf 'cli_note=%s\n' "$cli_stderr"
  fi

  if ! jq -e . >/dev/null 2>&1 <<<"$capabilities"; then
    echo "INVALID_JSON_OUTPUT"
    printf '%s\n' "$capabilities" | head -n 20
    continue
  fi

  reason="$(jq -r '[.[].reason // empty] | first // ""' <<<"$capabilities")"
  versions="$(jq -r '
    [
      .. | objects | .supportedServerVersions? | select(. != null)
      | if type == "array" then .[] else . end
      | if type == "object" then (.name // .version // empty) else . end
      | tostring
    ] | unique | join(",")
  ' <<<"$capabilities")"
  skus="$(jq -r '
    [
      .. | objects | to_entries[]
      | select((.key | ascii_downcase) | contains("sku"))
      | .value
      | if type == "array" then .[] else . end
      | if type == "object" then (.name // .skuName // .supportedSku // empty) else . end
      | select(type == "string")
      | ascii_downcase
    ] | unique | join(",")
  ' <<<"$capabilities")"

  printf 'reason=%s\n' "${reason:-<none>}"
  printf 'versions=%s\n' "${versions:-<none>}"
  printf 'skus=%s\n' "${skus:-<none>}"

  version_ok=0
  sku_ok=0
  [[ ",${versions}," == *",${DECLARED_VERSION},"* ]] && version_ok=1
  [[ ",${skus}," == *",${DECLARED_SKU_TOKEN},"* ]] && sku_ok=1

  if [[ "$region" == "$DECLARED_REGION" ]] && [[ -z "$reason" ]] && [[ "$version_ok" == "1" ]] && [[ "$sku_ok" == "1" ]]; then
    DECLARED_VALID=1
  fi

  if [[ -z "$BEST_CANDIDATE_REGION" ]] && [[ -z "$reason" ]] && [[ "$version_ok" == "1" ]]; then
    BEST_CANDIDATE_REGION="$region"
    if [[ "$sku_ok" == "1" ]]; then
      BEST_CANDIDATE_SKU="$DECLARED_SKU"
    else
      first_gp_sku="$(tr ',' '\n' <<<"$skus" | grep -E '^standard_(d|e)[0-9]' | head -n 1 || true)"
      BEST_CANDIDATE_SKU="${first_gp_sku:-<review-required>}"
    fi
  fi
done

if [[ "$DECLARED_VALID" != "1" ]]; then
  printf 'recommended_region=%s\n' "${BEST_CANDIDATE_REGION:-<none>}"
  printf 'recommended_sku=%s\n' "${BEST_CANDIDATE_SKU:-<none>}"
  echo "::error::Declared PostgreSQL region/SKU/version is not currently provisionable for this subscription. Review the capability summary and recommended candidate above before apply."
  exit 1
fi

echo "PostgreSQL capability preflight passed."
