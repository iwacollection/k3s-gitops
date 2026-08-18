# Flux / GitOps skeleton

This directory contains a minimal skeleton for Flux v2 Kustomizations that point to this repository.

Note: If you already have an existing GitOps repository controlling your cluster, DO NOT bootstrap Flux against the same cluster with these manifests without reviewing — you may get resource conflicts.

Example structure:

clusters/gitops/
  - kustomization.yaml
  - apps/
      - example-service.yaml

Bootstrap command (example):
  flux bootstrap github --owner=<org> --repository=<repo> --branch=<branch> --path=./clusters/gitops --personal

Adjust the bootstrap command to use Azure and AKS if you prefer: see Flux docs.
