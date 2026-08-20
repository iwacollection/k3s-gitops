#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Existing Azure resource adoption workflow

1. Inventory existing Azure resources
2. Map Azure resource id -> Terraform resource address
3. terraform import
4. terraform plan
5. Verify:
   - no unexpected destroy
   - no replacement
   - state matches reality

Never run terraform apply before import validation for existing production resources.
EOF
