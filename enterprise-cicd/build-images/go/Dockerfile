FROM golang:1.26.5-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git jq \
    && rm -rf /var/lib/apt/lists/*

ENV GOMODCACHE=/platform-cache/go/mod \
    GOCACHE=/platform-cache/go/build \
    GOPATH=/platform-cache/go/path

WORKDIR /workspace

RUN go version
