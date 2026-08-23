# Helm Production Deployment Standards

## Enterprise CMDB Deployment Model

Recommended production flow:

```
Git Commit
    |
Docker Build
    |
ACR Push (immutable tag)
    |
Helm values update
    |
AKS Rollout
```

## Required values

```yaml
image:
  repository: <acr>.azurecr.io/enterprise-cmdb
  tag: <git-sha>

service:
  type: ClusterIP

resources:
  requests:
    cpu: 250m
    memory: 512Mi

probes:
  readiness:
    enabled: true
  liveness:
    enabled: true
```

## Production Requirements

- Never use `latest` image tag
- Enable readiness/liveness probes
- Configure resource requests and limits
- Use rolling update strategy
- Keep secrets outside values files
- Validate manifests before deployment
