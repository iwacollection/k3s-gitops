#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
STACKS = REPO / "enterprise-cicd" / "terraform" / "stacks"
EXPECTED_AZURERM = "~> 4.81.0"

EXPECTED_VERSION_FILES = {
    "platform/identity/versions.tf",
    "platform/acr/versions.tf",
    "platform/connectivity/versions.tf",
    "platform/aks/versions.tf",
    "platform/observability/versions.tf",
    "platform/aks-observability/versions.tf",
    "workloads/storage/versions.tf",
    "workloads/key-vault/versions.tf",
    "workloads/managed-identity/versions.tf",
    "workloads/service-bus/versions.tf",
    "workloads/managed-redis/versions.tf",
    "workloads/postgresql-flexible/versions.tf",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    actual = {
        path.relative_to(STACKS).as_posix()
        for path in STACKS.rglob("versions.tf")
    }

    missing = EXPECTED_VERSION_FILES - actual
    unexpected = actual - EXPECTED_VERSION_FILES
    if missing or unexpected:
        fail(
            "IaC root-stack inventory changed without provider-pin contract update: "
            f"missing={sorted(missing)} unexpected={sorted(unexpected)}"
        )

    for relative in sorted(EXPECTED_VERSION_FILES):
        path = STACKS / relative
        text = path.read_text(encoding="utf-8")

        if 'source  = "hashicorp/azurerm"' not in text:
            fail(f"{relative}: AzureRM provider source is missing or changed")

        expected = f'version = "{EXPECTED_AZURERM}"'
        provider_version_lines = [
            line.strip()
            for line in text.splitlines()
            if line.strip().startswith('version =')
        ]
        if provider_version_lines != [expected]:
            fail(
                f"{relative}: AzureRM provider version must be exactly "
                f"{EXPECTED_AZURERM!r}; found={provider_version_lines}"
            )

    print(
        f"IaC provider pin contract valid: {len(EXPECTED_VERSION_FILES)} root stacks, "
        f"AzureRM {EXPECTED_AZURERM}."
    )


if __name__ == "__main__":
    main()
