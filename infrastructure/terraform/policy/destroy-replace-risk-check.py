#!/usr/bin/env python3
"""
Terraform plan JSON risk analyzer.
Blocks destructive production changes:
- delete actions
- replace actions (delete/create)
"""
import json
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: destroy-replace-risk-check.py plan.json")
        return 2

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        plan = json.load(f)

    risks = []
    for item in plan.get("resource_changes", []):
        actions = item.get("change", {}).get("actions", [])
        address = item.get("address", "unknown")
        if actions == ["delete"]:
            risks.append(f"DELETE: {address}")
        elif "delete" in actions and "create" in actions:
            risks.append(f"REPLACE: {address}")

    if risks:
        print("Production Terraform risk detected:")
        for r in risks:
            print(r)
        return 1

    print("No destructive Terraform changes detected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
