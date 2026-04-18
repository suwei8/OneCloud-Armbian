#!/bin/bash
set -euo pipefail

CONFIG_FILE="${ONECLOUD_BACKUP_ENV:-/root/.config/onecloud-backup/backup.env}"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Missing config file: ${CONFIG_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

VAULTWARDEN_DIR="${VAULTWARDEN_DIR:-/root/Vaultwarden}"
DATA_DIR="${DATA_DIR:-${VAULTWARDEN_DIR}/data}"
BACKUP_ROOT="${BACKUP_ROOT:-/root/backups/vaultwarden}"
KEEP_LOCAL_DAYS="${KEEP_LOCAL_DAYS:-14}"
ENABLE_MAIL="${ENABLE_MAIL:-0}"
ENABLE_ONEDRIVE="${ENABLE_ONEDRIVE:-0}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
RCLONE_DEST_PATH="${RCLONE_DEST_PATH:-vaultwarden-db-backups}"
MAILER_SCRIPT="${MAILER_SCRIPT:-/usr/local/sbin/send_backup_email.py}"
HOST_TAG="${HOST_TAG:-$(hostname)}"
MAIL_MAX_BYTES="${MAIL_MAX_BYTES:-20971520}"
REMOTE_KEEP_DAYS="${REMOTE_KEEP_DAYS:-30}"
GITHUB_DISPATCH_SCRIPT="${GITHUB_DISPATCH_SCRIPT:-/usr/local/sbin/onecloud_github_dispatch.sh}"

timestamp="$(date +%Y%m%d-%H%M%S)"
work_dir="$(mktemp -d /tmp/vaultwarden-backup.XXXXXX)"
stage_dir="${work_dir}/bundle"
archive_name="vaultwarden-db-${HOST_TAG}-${timestamp}.tar.gz"
archive_path="${BACKUP_ROOT}/${archive_name}"

cleanup() {
    rm -rf "${work_dir}"
}
trap cleanup EXIT

mkdir -p "${stage_dir}" "${BACKUP_ROOT}"

if [ ! -f "${DATA_DIR}/db.sqlite3" ]; then
    echo "Vaultwarden DB not found: ${DATA_DIR}/db.sqlite3" >&2
    exit 1
fi

sqlite3 "${DATA_DIR}/db.sqlite3" ".backup '${stage_dir}/db.sqlite3'"

for rel_path in \
    "config.json" \
    "rsa_key.pem" \
    "rsa_key.pub.pem" \
    "docker-compose.yml"
do
    src_path="${DATA_DIR}/${rel_path}"
    if [ "${rel_path}" = "docker-compose.yml" ]; then
        src_path="${VAULTWARDEN_DIR}/docker-compose.yml"
    fi
    if [ -f "${src_path}" ]; then
        cp -a "${src_path}" "${stage_dir}/$(basename "${rel_path}")"
    fi
done

cat > "${stage_dir}/BACKUP_INFO.txt" <<EOF
created_at=$(date --iso-8601=seconds)
hostname=${HOST_TAG}
vaultwarden_dir=${VAULTWARDEN_DIR}
data_dir=${DATA_DIR}
backup_type=critical-db
EOF

(
    cd "${stage_dir}"
    sha256sum * > SHA256SUMS
)

tar -C "${stage_dir}" -czf "${archive_path}" .

archive_size="$(stat -c '%s' "${archive_path}")"
echo "Created backup: ${archive_path}"
echo "Archive size: ${archive_size} bytes"

if [ "${ENABLE_MAIL}" = "1" ]; then
    if [ ! -x "${MAILER_SCRIPT}" ]; then
        echo "Mailer script missing or not executable: ${MAILER_SCRIPT}" >&2
        exit 1
    fi
    if [ "${archive_size}" -gt "${MAIL_MAX_BYTES}" ]; then
        echo "Skip mail: archive exceeds MAIL_MAX_BYTES (${MAIL_MAX_BYTES})"
    else
        python3 "${MAILER_SCRIPT}" --config "${CONFIG_FILE}" --attachment "${archive_path}"
    fi
fi

if [ "${ENABLE_ONEDRIVE}" = "1" ]; then
    if ! command -v rclone >/dev/null 2>&1; then
        echo "rclone is not installed" >&2
        exit 1
    fi
    if [ -z "${RCLONE_REMOTE}" ]; then
        echo "RCLONE_REMOTE is empty" >&2
        exit 1
    fi
    remote_target="${RCLONE_REMOTE%/}/${RCLONE_DEST_PATH%/}/${HOST_TAG}/${archive_name}"
    rclone copyto "${archive_path}" "${remote_target}" --transfers 1 --checkers 2 --retries 3 --low-level-retries 10
    echo "Uploaded to remote: ${remote_target}"
    if [ -x "${GITHUB_DISPATCH_SCRIPT}" ]; then
        "${GITHUB_DISPATCH_SCRIPT}" "${archive_name}" || true
    fi
    if [ "${REMOTE_KEEP_DAYS}" -gt 0 ] 2>/dev/null; then
        remote_dir="${RCLONE_REMOTE%/}/${RCLONE_DEST_PATH%/}/${HOST_TAG}"
        rclone delete "${remote_dir}" --min-age "${REMOTE_KEEP_DAYS}d" --rmdirs >/dev/null 2>&1 || true
        echo "Applied remote retention: ${REMOTE_KEEP_DAYS} days"
    fi
fi

find "${BACKUP_ROOT}" -maxdepth 1 -type f -name 'vaultwarden-db-*.tar.gz' -mtime +"${KEEP_LOCAL_DAYS}" -delete

echo "Backup job finished."
