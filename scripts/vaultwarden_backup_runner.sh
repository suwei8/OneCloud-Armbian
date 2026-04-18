#!/bin/bash
set -euo pipefail

CONFIG_FILE="${ONECLOUD_BACKUP_ENV:-/root/.config/onecloud-backup/backup.env}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-/usr/local/sbin/vaultwarden_backup.sh}"
MAILER_SCRIPT="${MAILER_SCRIPT:-/usr/local/sbin/send_backup_email.py}"
LOG_FILE="${LOG_FILE:-/var/log/vaultwarden-backup.log}"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Missing config file: ${CONFIG_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

ENABLE_ALERT_ON_FAILURE="${ENABLE_ALERT_ON_FAILURE:-1}"
HOST_TAG="${HOST_TAG:-$(hostname)}"

if "${BACKUP_SCRIPT}" >> "${LOG_FILE}" 2>&1; then
    exit 0
fi

status=$?

if [ "${ENABLE_ALERT_ON_FAILURE}" = "1" ] && [ -x "${MAILER_SCRIPT}" ]; then
    body=$(
        cat <<EOF
Vaultwarden backup failed.

Host: ${HOST_TAG}
Time: $(date --iso-8601=seconds)
Log file: ${LOG_FILE}
Exit code: ${status}

Last 40 log lines:
$(tail -n 40 "${LOG_FILE}" 2>/dev/null || true)
EOF
    )
    python3 "${MAILER_SCRIPT}" \
        --config "${CONFIG_FILE}" \
        --subject "[OneCloud] Vaultwarden backup FAILED ${HOST_TAG}" \
        --body "${body}" >> "${LOG_FILE}" 2>&1 || true
fi

exit "${status}"
