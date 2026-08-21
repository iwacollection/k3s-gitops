#!/usr/bin/env python3
"""
Validate resource adoption mappings before terraform import.

This prevents blindly importing wrong Azure resources into Terraform state.
"""

import json
import sys
from pathlib import Path

REQUIRED = {"resource_id", "terraform_address"}


def main():
    if len(sys.argv) < 2:
        print("usage: resource-match-check.py <mapping.json>")
        sys.exit(1)

    items = json.loads(Path(sys.argv[1]).read_text())
    failed = False

    for index, item in enumerate(items):
        missing = REQUIRED - set(item)
        if missing:
            print(f"invalid item {index}: missing {sorted(missing)}")
            failed = True
        else:
            print(f"ok: {item['terraform_address']}")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
