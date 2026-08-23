# Enterprise CMDB Ingress

## Flow

Internet
 -> Azure Application Gateway
 -> Application Gateway Ingress Controller (AGIC)
 -> ClusterIP Service
 -> enterprise-cmdb Pod

## Production requirements

- Configure Azure Application Gateway backend pool
- Configure DNS record for CMDB domain
- Attach TLS certificate
- Enable WAF policy
- Replace example host with production domain

The Kubernetes Service remains ClusterIP by design.
