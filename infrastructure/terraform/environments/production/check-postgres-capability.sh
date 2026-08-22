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
  versions="$(jq -r '[.. | objects | .supportedServerVersions? | select(. != null) | if type == "array" then .[] else . end | tostring] | unique | join(",")' <<<"$capabilities")"
  skus="$(jq -r '[.. | objects | .supportedSku? | select(. != null) | tostring | ascii_downcase] | unique | join(",")' <<<"$capabilities")"

  printf 'reason=%s\n' "${reason:-<none>}"
  printf 'versions=%s\n' "${versions:-<none>}"
  printf 'skus=%s\n' "${skus:-<none>}"

  if [[ "$region" == "$DECLARED_REGION" ]]; then
    if [[ -z "$reason" ]] && [[ ",${versions}," == *",${DECLARED_VERSION},"* ]] && [[ ",${skus}," == *",${DECLARED_SKU_TOKEN},"* ]]; then
      DECLARED_VALID=1
    fi
  fi
done

if [[ "$DECLARED_VALID" != "1" ]]; then
  echo "::error::Declared PostgreSQL region/SKU/version is not currently provisionable for this subscription. Review the capability summary above and update the Terraform database location/SKU before apply."
  exit 1
fi

echo "PostgreSQL capability preflight passed."
