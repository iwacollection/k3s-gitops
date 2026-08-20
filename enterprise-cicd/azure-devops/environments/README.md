# Protected Environments

Logical environments: dev, test, prod.

Target controls:
- DEV: automated after merge where safe
- TEST: branch/check gates
- PROD: explicit approval, branch control, required template, exclusive lock

Environment checks are managed outside application YAML wherever possible.
