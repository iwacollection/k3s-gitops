# Build Image Platform

Versioned, reproducible build environments for all CI systems.

Rules:
- never depend on mutable long-lived build hosts
- pin toolchains and package-manager versions
- publish images to ACR
- separate language build images from infra/deploy images
- promote image changes through validation before becoming default
