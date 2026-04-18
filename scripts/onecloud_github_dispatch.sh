#!/bin/bash
set -euo pipefail

CONFIG_FILE="${ONECLOUD_BACKUP_ENV:-/root/.config/onecloud-backup/backup.env}"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Missing config file: ${CONFIG_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

GITHUB_DISPATCH_ENABLED="${GITHUB_DISPATCH_ENABLED:-0}"
GITHUB_DISPATCH_REPO="${GITHUB_DISPATCH_REPO:-}"
GITHUB_DISPATCH_TOKEN="${GITHUB_DISPATCH_TOKEN:-}"
GITHUB_DISPATCH_EVENT="${GITHUB_DISPATCH_EVENT:-onecloud-backup-uploaded}"
GITHUB_API_BASE="${GITHUB_API_BASE:-https://api.github.com}"
HOST_TAG="${HOST_TAG:-$(hostname)}"

backup_file="${1:-}"
if [ -z "${backup_file}" ]; then
    echo "Usage: $0 <backup-file-name>" >&2
    exit 1
fi

if [ "${GITHUB_DISPATCH_ENABLED}" != "1" ]; then
    echo "GitHub dispatch disabled"
    exit 0
fi

if [ -z "${GITHUB_DISPATCH_REPO}" ] || [ -z "${GITHUB_DISPATCH_TOKEN}" ]; then
    echo "GitHub dispatch config incomplete" >&2
    exit 1
fi

payload="$(cat <<EOF
{
  "event_type": "${GITHUB_DISPATCH_EVENT}",
  "client_payload": {
    "host": "${HOST_TAG}",
    "file": "${backup_file}"
  }
}
EOF
)"

curl -fsSL \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_DISPATCH_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${GITHUB_API_BASE}/repos/${GITHUB_DISPATCH_REPO}/dispatches" \
  -d "${payload}" >/dev/null

echo "Dispatched ${backup_file} to ${GITHUB_DISPATCH_REPO}"
