#!/usr/bin/env bash

# Safe kubelogin installer for the temporary CentOS 7 bootstrap host.
# This host is not intended to become the long-lived enterprise CI runner image.

(
  LOG="${1:-kubelogin_install.log}"
  VERSION="v0.2.19"
  ZIP="kubelogin-linux-amd64.zip"
  URL="https://github.com/Azure/kubelogin/releases/download/${VERSION}/${ZIP}"
  SHA256="ebaeff02aa899c5cae6a2b954b64fc02738185319df2570f7dc053451efa4b2f"
  TMPDIR="$(mktemp -d)"

  cleanup() {
    rm -rf "$TMPDIR"
  }
  trap cleanup EXIT

  {
    set -euo pipefail

    echo "========================================="
    echo " KUBELOGIN INSTALL - CENTOS 7"
    echo "========================================="

    echo
    echo "[1] Existing kubelogin"
    if command -v kubelogin >/dev/null 2>&1; then
      command -v kubelogin
      kubelogin --version || true
      echo "kubelogin already installed"
      exit 0
    fi

    echo
    echo "[2] Prerequisites"
    sudo yum install -y curl unzip

    echo
    echo "[3] Download ${VERSION}"
    cd "$TMPDIR"
    curl -fL --retry 3 --retry-delay 2 -o "$ZIP" "$URL"

    echo
    echo "[4] Verify SHA256"
    echo "${SHA256}  ${ZIP}" | sha256sum -c -

    echo
    echo "[5] Extract"
    unzip -q "$ZIP"

    echo
    echo "[6] Install"
    sudo install -m 0755 bin/linux_amd64/kubelogin /usr/local/bin/kubelogin

    echo
    echo "[7] Verify"
    command -v kubelogin
    kubelogin --version

    echo
    echo "========================================="
    echo " INSTALL SUCCESS"
    echo "========================================="
  } 2>&1 | tee "$LOG"
) || {
  STATUS=$?
  echo
  echo "========================================="
  echo " INSTALL FAILED"
  echo "========================================="
  echo "exit_code=$STATUS"
  echo "log=${1:-kubelogin_install.log}"
  true
}
