#!/usr/bin/env python3
"""
Validate Terraform adoption after importing existing resources.

Production goal:
- detect destroy
- detect replace
- allow safe adoption workflow
"""

import json
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: import-diff-check.py plan.json")
        return 2

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        plan = json.load(f)

    dangerous = []
    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        if "delete" in actions or actions == ["delete", "create"]:
            dangerous.append({
                "address": change.get("address"),
                "actions": actions,
            })

    if dangerous:
        print(json.dumps({"status": "BLOCK", "changes": dangerous}, indent=2))
        return 1

    print(json.dumps({"status": "PASS"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
