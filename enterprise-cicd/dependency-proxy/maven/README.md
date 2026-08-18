# Maven Proxy

Internal Maven proxy/feed boundary for Java builds. Shared repository cache is read-through; job-local writable Maven caches remain isolated and keyed by JDK/toolchain/lock inputs.
