# DEV IaC bootstrap UAMI REST field correction

During the real DEV IaC control-plane activation on 2026-08-19, Azure successfully created the state resource group, storage account/container, and the two dedicated user-assigned managed identities, but the bootstrap stopped at UAMI ID resolution.

Root cause: the Managed Identity ARM REST response exposes `clientId` and `principalId` under `properties`. The bootstrap helper currently queries the top-level fields.

Required correction in `bootstrap-dev-iac-control-plane.sh`:

```bash
# incorrect
--query "$field" -o tsv

# correct
--query "properties.${field}" -o tsv
```

The bootstrap is designed to be idempotent, so after applying this correction it is safe to rerun with `--apply`; already-created control-plane resources are normalized and activation continues with FIC, custom-role, RBAC, and evidence creation.

This note records the real activation defect so it is not lost while the source fix is applied.
