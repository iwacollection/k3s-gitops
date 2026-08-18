# Dependency Proxy Platform

Central package ingress/caching boundary for internet and internal dependencies.

Goals:
- reduce external dependency availability risk
- provide immutable/approved package sources
- isolate per-job writable caches from shared repository caches
- support Maven, PyPI, Go Proxy and Conan/vcpkg ecosystems
