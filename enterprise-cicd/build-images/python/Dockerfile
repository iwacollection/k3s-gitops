FROM python:3.12.13-slim-trixie

COPY --from=ghcr.io/astral-sh/uv:0.12.0 /uv /uvx /usr/local/bin/

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates curl git jq \
    && rm -rf /var/lib/apt/lists/*

ENV UV_CACHE_DIR=/platform-cache/uv \
    UV_LINK_MODE=copy \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

RUN python --version && uv --version
