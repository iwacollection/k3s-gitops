# Terraform Module Regression Test Baseline

Future automation should verify:

- terraform fmt
- terraform validate
- module contract
- import compatibility
- destroy safety
- plan regression

Production IaC changes should fail before reaching Azure when they introduce unexpected destructive changes.
