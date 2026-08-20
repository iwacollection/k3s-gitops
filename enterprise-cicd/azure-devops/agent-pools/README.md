# Agent Pools

Enterprise execution-plane boundary for Azure Pipelines.

Target strategy:
- prefer ephemeral/managed agents
- isolate infra jobs from application builds
- version build environments instead of mutating long-lived hosts
- separate privileged deployment pools from untrusted PR workloads
