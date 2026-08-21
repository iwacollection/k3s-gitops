#!/usr/bin/env python3
"""Validate Azure existing resource adoption plan safety."""

import json
import sys


def main():
    if len(sys.argv) < 2:
        print("usage: adoption-validator.py <plan.json>")
        return 2

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        plan = json.load(f)

    risky = []
    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        if "delete" in actions or actions == ["delete", "create"]:
            risky.append(change.get("address", "unknown"))

    if risky:
        print("ADOPTION BLOCKED")
        for item in risky:
            print(item)
        return 1

    print("ADOPTION VALIDATION PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
