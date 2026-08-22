# AGIC deployment

This chart configuration enables Azure Application Gateway Ingress Controller integration.

Flow:

Internet -> Application Gateway WAF -> AGIC -> Kubernetes Ingress -> Service

Production deployment must provide:

- Application Gateway resource id
- Managed Identity client id
- Federated workload identity binding
- Key Vault TLS certificate integration
