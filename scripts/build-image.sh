#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="${IMAGE:-snowluma-docker-framework:latest}"
PUSH="${PUSH:-0}"

if [ "${PUSH}" = "1" ] || [ "${PUSH}" = "true" ]; then
  PLATFORM="${PLATFORM:-linux/amd64,linux/arm64}"
  OUTPUT="${OUTPUT:---push}"
else
  PLATFORM="${PLATFORM:-linux/amd64}"
  OUTPUT="${OUTPUT:---load}"
fi

"${SCRIPT_DIR}/prepare-artifact.sh"

docker buildx build \
  --platform "${PLATFORM}" \
  --tag "${IMAGE}" \
  --file "${FRAMEWORK_DIR}/Dockerfile" \
  ${OUTPUT} \
  "${FRAMEWORK_DIR}"

echo "Built ${IMAGE} for ${PLATFORM}"
