#!/usr/bin/env python3
"""Block terraform replace (-/+) actions in production plans."""
import json
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: replace-guard.py <terraform-plan-json>")
        return 2
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        plan = json.load(f)
    bad = []
    for item in plan.get("resource_changes", []):
        actions = item.get("change", {}).get("actions", [])
        if "delete" in actions and "create" in actions:
            bad.append(item.get("address", "unknown"))
    if bad:
        print("BLOCK: terraform replace detected")
        for r in bad:
            print(r)
        return 1
    print("PASS: no replace detected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
