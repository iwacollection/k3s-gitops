FROM python:3.12.13-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /app
COPY dist/*.whl /tmp/platform-smoke-api.whl
RUN pip install --no-cache-dir /tmp/platform-smoke-api.whl && rm -f /tmp/platform-smoke-api.whl
USER 65532:65532
EXPOSE 8080
CMD ["python", "-m", "platform_smoke_api"]
