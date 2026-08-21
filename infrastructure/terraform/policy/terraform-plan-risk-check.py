#!/usr/bin/env python3
"""Fail Terraform promotion when plan contains destructive changes."""

import json
import sys


def main():
    if len(sys.argv) != 2:
        print("usage: terraform-plan-risk-check.py plan.json")
        return 2

    with open(sys.argv[1], encoding="utf-8") as f:
        plan = json.load(f)

    blocked = []
    for item in plan.get("resource_changes", []):
        actions = item.get("change", {}).get("actions", [])
        if actions == ["delete"] or actions == ["delete", "create"]:
            blocked.append(
                {
                    "address": item.get("address"),
                    "actions": actions,
                }
            )

    if blocked:
        print("BLOCKED: destructive terraform changes detected")
        for item in blocked:
            print(item)
        return 1

    print("PASS: no destructive terraform changes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
