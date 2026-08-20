FROM ubuntu:24.04

ARG CONAN_VERSION=2.24.0

ENV DEBIAN_FRONTEND=noninteractive \
    CONAN_HOME=/platform-cache/conan \
    CCACHE_DIR=/platform-cache/ccache \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential ca-certificates ccache cmake curl git jq ninja-build pipx pkg-config python3 python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && pipx install "conan==${CONAN_VERSION}"

WORKDIR /workspace

RUN gcc --version | head -n 1 \
    && g++ --version | head -n 1 \
    && cmake --version | head -n 1 \
    && ninja --version \
    && conan --version
