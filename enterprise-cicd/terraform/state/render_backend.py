#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONTRACTS = HERE.parent.parent / "contracts"


def load_json(name: str):
    with (CONTRACTS / name).open("r", encoding="utf-8") as fh:
        return json.load(fh)


def quote(value: str) -> str:
    return json.dumps(value)


def valid_name(value: str) -> bool:
    return bool(re.fullmatch(r"[a-z0-9][a-z0-9-]{1,62}", value))


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a safe azurerm backend.hcl from enterprise state contracts")
    parser.add_argument("--scope", choices=["platform", "workload", "catalog"], required=True)
    parser.add_argument("--stack", help="Platform stack name, e.g. identity/aks/connectivity/observability")
    parser.add_argument("--environment", choices=["dev", "test", "prod"])
    parser.add_argument("--workload", help="Workload name for workload state")
    parser.add_argument("--service", help="Catalog service name, e.g. acr/redis/database")
    parser.add_argument("--request", help="Catalog request name")
    parser.add_argument("--auth", choices=["oidc", "cli"], default="oidc")
    parser.add_argument("--output", default="backend.hcl")
    args = parser.parse_args()

    state = load_json("state-contract.json")
    env_contract = load_json("environment-contract.json")

    storage_account = os.getenv("TFSTATE_STORAGE_ACCOUNT", "").strip()
    if not storage_account:
        print("TFSTATE_STORAGE_ACCOUNT is required", file=sys.stderr)
        return 2

    container = state["backend"]["container_name"]
    resource_group = os.getenv(
        "TFSTATE_RESOURCE_GROUP",
        state.get("lab_mapping", {}).get("backend_resource_group", "rg-platform-cicd"),
    )

    if args.scope == "platform":
        if not args.stack:
            print("--stack is required for platform scope", file=sys.stderr)
            return 2
        environment_scoped = set(state.get("environment_scoped_platform_stacks", []))
        if args.stack in environment_scoped:
            if not args.environment:
                print(f"--environment is required for environment-scoped platform stack {args.stack}", file=sys.stderr)
                return 2
            if args.environment not in env_contract.get("environments", {}):
                print(f"unknown environment: {args.environment}", file=sys.stderr)
                return 2
            key = state["platform_environment_key_pattern"].format(
                environment=args.environment,
                stack=args.stack,
            )
        else:
            platform_keys = state.get("platform_keys", {})
            if args.stack not in platform_keys:
                allowed = sorted(set(platform_keys) | environment_scoped)
                print(f"unknown platform stack: {args.stack}; allowed={','.join(allowed)}", file=sys.stderr)
                return 2
            if args.environment:
                print(f"--environment is not accepted for global platform stack {args.stack}", file=sys.stderr)
                return 2
            key = platform_keys[args.stack]

    elif args.scope == "workload":
        if not args.environment or not args.workload:
            print("--environment and --workload are required for workload scope", file=sys.stderr)
            return 2
        if args.environment not in env_contract.get("environments", {}):
            print(f"unknown environment: {args.environment}", file=sys.stderr)
            return 2
        if not valid_name(args.workload):
            print("workload must match [a-z0-9][a-z0-9-]{1,62}", file=sys.stderr)
            return 2
        key = state["workload_key_pattern"].format(environment=args.environment, workload=args.workload)

    else:
        if not args.environment or not args.service or not args.request:
            print("--environment, --service and --request are required for catalog scope", file=sys.stderr)
            return 2
        if args.environment not in env_contract.get("environments", {}):
            print(f"unknown environment: {args.environment}", file=sys.stderr)
            return 2
        if not valid_name(args.service):
            print("service must match [a-z0-9][a-z0-9-]{1,62}", file=sys.stderr)
            return 2
        if not valid_name(args.request):
            print("request must match [a-z0-9][a-z0-9-]{1,62}", file=sys.stderr)
            return 2
        key = state["catalog_key_pattern"].format(
            environment=args.environment,
            service=args.service,
            request=args.request,
        )

    lines = [
        f"resource_group_name  = {quote(resource_group)}",
        f"storage_account_name = {quote(storage_account)}",
        f"container_name       = {quote(container)}",
        f"key                  = {quote(key)}",
        "use_azuread_auth     = true",
    ]
    lines.append("use_oidc             = true" if args.auth == "oidc" else "use_cli              = true")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("BACKEND CONFIG RENDERED")
    print(f"scope={args.scope}")
    if args.environment:
        print(f"environment={args.environment}")
    print(f"key={key}")
    print(f"auth={args.auth}")
    print(f"output={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
