#!/usr/bin/env python3
"""
Generate Terraform import commands from a resource mapping file.

Input format (json):
[
  {
    "resource_id": "/subscriptions/...",
    "terraform_address": "module.network.azurerm_virtual_network.main"
  }
]

The generated commands are intentionally reviewed before execution.
"""

import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print("usage: generate-import-map.py <mapping.json>")
        sys.exit(1)

    data = json.loads(Path(sys.argv[1]).read_text())

    for item in data:
        resource_id = item["resource_id"]
        address = item["terraform_address"]
        print(f"terraform import '{address}' '{resource_id}'")


if __name__ == "__main__":
    main()
