# Terraform Module Production Standard

Every module should contain:

```text
module/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── README.md
└── examples/
```

Requirements:

- Explicit inputs
- Stable outputs
- Version constraints
- Documentation
- No hidden resource replacement
- Safe lifecycle handling

Before production usage:

```bash
terraform fmt
terraform validate
terraform plan
```
