# DEV Infrastructure Requests

Application teams create or modify only request manifests in this directory for normal DEV infrastructure changes.

Allowed flow: request -> PR validation -> Terraform plan -> review -> merge -> protected DEV apply.

Do not add `.tf` files here. Do not embed credentials or secrets in requests.
