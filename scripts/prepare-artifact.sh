#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARTIFACT_PATH="${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz"

if [ ! -f "${ARTIFACT_PATH}" ]; then
  echo "Missing prebuilt SnowLuma artifact: ${ARTIFACT_PATH}"
  echo "Put SnowLuma.Framework.tar.gz in the Docker framework repository root."
  exit 1
fi

required_entries=(
  "index.mjs"
  "package.json"
  "client/index.html"
  "native/snowluma-linux-x64.node"
  "native/snowluma-linux-x64.so"
  "native/websocket-linux-x64.node"
  "native/snowluma-linux-arm64.node"
  "native/snowluma-linux-arm64.so"
  "native/websocket-linux-arm64.node"
)

archive_entries="$(tar -tzf "${ARTIFACT_PATH}" | sed 's#^\./##')"

for entry in "${required_entries[@]}"; do
  if ! printf '%s\n' "${archive_entries}" | grep -qx "${entry}"; then
    echo "Invalid SnowLuma artifact: missing ${entry}"
    echo "Expected archive layout is the built dist/ contents at archive root."
    exit 1
  fi
done

echo "Using prebuilt artifact from repository root: ${ARTIFACT_PATH}"
