#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${ROOT_DIR}/web_deploy"
BACKUP_DIR="${ROOT_DIR}/.release/web_deploy.rollback"
HEALTH_URL="${HEALTH_URL:-http://154.12.117.175:3002/api/health}"

restore_previous_release() {
  if [[ ! -f "${BACKUP_DIR}/main.dart.js" ]]; then
    echo "rollback_unavailable: ${BACKUP_DIR}" >&2
    return 1
  fi
  rsync -a --delete "${BACKUP_DIR}/" "${DEPLOY_DIR}/"
  curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 "${HEALTH_URL}" >/dev/null
  echo "rollback=ok"
}

if [[ "${1:-}" == "--rollback" ]]; then
  restore_previous_release
  exit 0
fi

cd "${ROOT_DIR}"
flutter build web --release --no-wasm-dry-run

mkdir -p "${BACKUP_DIR}"
rsync -a --delete "${DEPLOY_DIR}/" "${BACKUP_DIR}/"
rsync -a --delete "${ROOT_DIR}/build/web/" "${DEPLOY_DIR}/"

if ! curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 "${HEALTH_URL}" >/dev/null; then
  echo "release_health_check_failed: restoring previous release" >&2
  restore_previous_release
  exit 1
fi

BUILD_HASH="$(sha256sum "${ROOT_DIR}/build/web/main.dart.js" | awk '{print $1}')"
DEPLOY_HASH="$(sha256sum "${DEPLOY_DIR}/main.dart.js" | awk '{print $1}')"
if [[ "${BUILD_HASH}" != "${DEPLOY_HASH}" ]]; then
  echo "release_checksum_mismatch: restoring previous release" >&2
  restore_previous_release
  exit 1
fi

echo "release=ok hash=${DEPLOY_HASH} health=${HEALTH_URL}"