#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DECOM_DIR = REPO / "enterprise-cicd" / "iac-decommission" / "dev"
VALIDATOR = REPO / "enterprise-cicd" / "iac-decommission" / "validate_decommission.py"
TOMBSTONE = DECOM_DIR / "synthetic-managed-identity.json"
DUPLICATE = DECOM_DIR / "synthetic-managed-identity-duplicate.json"


def run_validator(expect_success: bool) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["python", str(VALIDATOR), "--tombstone", str(TOMBSTONE)],
        cwd=REPO,
        text=True,
        capture_output=True,
    )
    if expect_success and result.returncode != 0:
        raise SystemExit(f"valid tombstone rejected:\nstdout={result.stdout}\nstderr={result.stderr}")
    if not expect_success and result.returncode == 0:
        raise SystemExit("invalid tombstone unexpectedly accepted")
    return result


def main() -> None:
    DECOM_DIR.mkdir(parents=True, exist_ok=True)
    valid = {
        "apiVersion": "platform.iac/v1",
        "kind": "DecommissionRequest",
        "metadata": {
            "name": "synthetic-managed-identity-retirement",
            "owner": "platform-sre",
            "changeTicket": "CHG-CI-0001",
            "reason": "Synthetic CI contract validation only"
        },
        "spec": {
            "environment": "dev",
            "requestPath": "enterprise-cicd/iac-requests/dev/platform-free-managed-identity.json",
            "requestName": "platform-free-managed-identity",
            "service": "managed-identity",
            "confirmation": "DESTROY platform-free-managed-identity"
        }
    }

    try:
        TOMBSTONE.write_text(json.dumps(valid, indent=2) + "\n", encoding="utf-8")
        result = run_validator(expect_success=True)
        resolved = json.loads(result.stdout)
        assert resolved["requestName"] == "platform-free-managed-identity"
        assert resolved["service"] == "managed-identity"
        assert resolved["retired"] is True

        invalid_confirmation = json.loads(json.dumps(valid))
        invalid_confirmation["spec"]["confirmation"] = "DESTROY something-else"
        TOMBSTONE.write_text(json.dumps(invalid_confirmation, indent=2) + "\n", encoding="utf-8")
        run_validator(expect_success=False)

        TOMBSTONE.write_text(json.dumps(valid, indent=2) + "\n", encoding="utf-8")
        DUPLICATE.write_text(json.dumps(valid, indent=2) + "\n", encoding="utf-8")
        duplicate = run_validator(expect_success=False)
        combined = duplicate.stdout + duplicate.stderr
        assert "exactly one immutable tombstone" in combined

        print("IaC decommission validator synthetic contract tests passed.")
    finally:
        for path in (TOMBSTONE, DUPLICATE):
            path.unlink(missing_ok=True)
        try:
            DECOM_DIR.rmdir()
        except OSError:
            pass


if __name__ == "__main__":
    main()
