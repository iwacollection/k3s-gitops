from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINDINGS = ROOT / "contracts" / "environment-bindings.json"
POLICY = ROOT / "iac-catalog" / "services" / "postgresql-flexible" / "v1" / "policy.json"
UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare a governed PR change that activates PostgreSQL PROD after the real platform DBA Entra group is known.")
    parser.add_argument("--object-id", required=True)
    parser.add_argument("--principal-name", required=True)
    args = parser.parse_args()

    if not UUID_RE.fullmatch(args.object_id):
        raise SystemExit("--object-id must be a valid Entra object UUID")
    principal_name = args.principal_name.strip()
    if not principal_name or len(principal_name) > 256:
        raise SystemExit("--principal-name must be a non-empty Entra group display name")

    bindings = load(BINDINGS)
    prod = bindings["environments"]["prod"]
    prod.setdefault("identities", {})["postgresqlDba"] = {
        "objectId": args.object_id.lower(),
        "principalName": principal_name,
        "principalType": "Group",
    }

    policy = load(POLICY)
    prod_policy = policy["prod"]
    if prod_policy.get("enabled") is True:
        raise SystemExit("PostgreSQL PROD catalog is already enabled")
    activation_policy = prod_policy.get("activationPolicy")
    if not isinstance(activation_policy, dict) or not activation_policy:
        raise SystemExit("PostgreSQL PROD activationPolicy is missing; platform owners must define policy before activation")

    policy["prod"] = {"enabled": True, **activation_policy}

    write(BINDINGS, bindings)
    write(POLICY, policy)
    print(json.dumps({
        "postgresqlProdActivationPrepared": True,
        "objectId": args.object_id.lower(),
        "principalName": principal_name,
        "policyEnabled": True,
    }, indent=2))


if __name__ == "__main__":
    main()
