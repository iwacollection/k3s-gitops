# GitOps Control Plane

Target AKS CD model: CI publishes immutable artifacts; GitOps repository records desired state; Flux reconciles AKS.

CI does not become an unrestricted production kubectl control plane.
