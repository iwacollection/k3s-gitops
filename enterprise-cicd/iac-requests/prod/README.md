# PROD Infrastructure Requests

Application teams submit PROD infrastructure requests here using approved catalog schemas.

Flow: request -> schema/policy validation -> Terraform plan -> mandatory review -> merge -> protected PROD environment approval/checks -> exclusive lock -> Apply Identity -> verification.

Do not add `.tf` files here. Do not embed credentials or secrets in requests. Production changes must not bypass the catalog or protected environment checks.
