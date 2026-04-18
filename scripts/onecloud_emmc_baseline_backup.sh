#!/bin/bash
set -euo pipefail

OUTPUT_DIR="${1:-/mnt/backup}"
DEVICE="${2:-/dev/mmcblk1}"
STAMP="$(date +%Y%m%d-%H%M%S)"
HOST_TAG="${HOST_TAG:-$(hostname)}"
RAW_IMG="${OUTPUT_DIR}/onecloud-emmc-baseline-${HOST_TAG}-${STAMP}.img"
COMPRESSED_IMG="${RAW_IMG}.gz"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root." >&2
    exit 1
fi

if findmnt -rn -S "${DEVICE}" >/dev/null 2>&1; then
    echo "${DEVICE} appears mounted. Boot from SD/maintenance system first." >&2
    findmnt -rn -S "${DEVICE}" >&2 || true
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "Creating raw image from ${DEVICE} ..."
dd if="${DEVICE}" of="${RAW_IMG}" bs=4M iflag=fullblock status=progress conv=fsync

echo "Compressing image ..."
gzip -1 "${RAW_IMG}"

echo "Hashing image ..."
sha256sum "${COMPRESSED_IMG}" | tee "${COMPRESSED_IMG}.sha256"

cat > "${OUTPUT_DIR}/README-${STAMP}.txt" <<EOF
Created: $(date --iso-8601=seconds)
Host: ${HOST_TAG}
Source device: ${DEVICE}
Image: ${COMPRESSED_IMG}
SHA256 file: ${COMPRESSED_IMG}.sha256

Restore example from maintenance system:
  gunzip -c ${COMPRESSED_IMG} | dd of=${DEVICE} bs=4M status=progress conv=fsync
EOF

echo "Baseline image complete:"
echo "${COMPRESSED_IMG}"
echo "${COMPRESSED_IMG}.sha256"
