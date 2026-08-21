#!/usr/bin/env python3
"""Analyze terraform plan json for production safety risks."""

import json
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: plan-risk-analyzer.py <plan.json>")
        return 2

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        plan = json.load(f)

    risks = []
    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        address = change.get("address", "unknown")
        if "delete" in actions:
            risks.append(f"DELETE: {address}")
        if "replace" in actions or ("delete" in actions and "create" in actions):
            risks.append(f"REPLACE: {address}")

    print("Terraform Production Risk Report")
    print(f"risk_count={len(risks)}")
    for item in risks:
        print(item)

    return 1 if risks else 0


if __name__ == "__main__":
    raise SystemExit(main())
