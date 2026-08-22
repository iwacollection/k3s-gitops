# Production TLS flow

Azure Key Vault Certificate

-> Secrets Store CSI Driver

-> Kubernetes TLS Secret

-> Application Gateway / AGIC Ingress listener

Production validation:

- certificate rotation works
- secret sync succeeds
- HTTPS listener returns valid certificate
