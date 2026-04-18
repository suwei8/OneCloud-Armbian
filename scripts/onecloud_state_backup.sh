#!/bin/bash
set -euo pipefail

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${1:-/root/onecloud_state_backups/onecloud_state_${timestamp}}"
stage_dir="${backup_root}/staging"
archive_path="${backup_root}/onecloud_state_${timestamp}.tar.gz"
summary_path="${backup_root}/SUMMARY.txt"

mkdir -p "${stage_dir}"

copy_path() {
    local src="$1"
    local dst_rel="$2"

    if [ -e "${src}" ]; then
        mkdir -p "${stage_dir}/$(dirname "${dst_rel}")"
        cp -a "${src}" "${stage_dir}/${dst_rel}"
    fi
}

copy_glob() {
    local pattern="$1"
    local dst_rel="$2"
    shopt -s nullglob
    local matches=( ${pattern} )
    shopt -u nullglob
    if [ "${#matches[@]}" -gt 0 ]; then
        mkdir -p "${stage_dir}/${dst_rel}"
        cp -a "${matches[@]}" "${stage_dir}/${dst_rel}/"
    fi
}

mkdir -p "${backup_root}"

# Vaultwarden
if [ -f /root/Vaultwarden/data/db.sqlite3 ]; then
    mkdir -p "${stage_dir}/vaultwarden"
    sqlite3 /root/Vaultwarden/data/db.sqlite3 ".backup '${stage_dir}/vaultwarden/db.sqlite3.backup'"
fi
copy_path /root/Vaultwarden/docker-compose.yml vaultwarden/docker-compose.yml
copy_path /root/Vaultwarden/.env vaultwarden/.env
copy_path /root/Vaultwarden/data vaultwarden/data

# DDNS
copy_path /root/Aliyun-DDNS-update-linux.sh root/Aliyun-DDNS-update-linux.sh
copy_path /root/Cloudflare-DDNS-update-linux.sh root/Cloudflare-DDNS-update-linux.sh
copy_path /etc/cron.d/onecloud-ddns etc/cron.d/onecloud-ddns

# HTTPS / nginx / certbot
copy_path /etc/nginx/conf.d/b.13982.com.conf etc/nginx/conf.d/b.13982.com.conf
copy_path /etc/letsencrypt etc/letsencrypt

# Cloudflare tunnel
copy_path /etc/systemd/system/cloudflared.service etc/systemd/system/cloudflared.service
copy_path /etc/systemd/system/cloudflared-update.service etc/systemd/system/cloudflared-update.service
copy_path /etc/systemd/system/cloudflared-update.timer etc/systemd/system/cloudflared-update.timer
copy_path /etc/default/cloudflared etc/default/cloudflared
copy_path /etc/cloudflared etc/cloudflared

# Network / host identity / LED configuration
copy_glob "/etc/NetworkManager/system-connections/*" etc/NetworkManager/system-connections
copy_path /etc/hostname etc/hostname
copy_path /etc/hosts etc/hosts
copy_path /usr/local/sbin/onecloud-leds-off.sh usr/local/sbin/onecloud-leds-off.sh
copy_path /etc/systemd/system/onecloud-leds-off.service etc/systemd/system/onecloud-leds-off.service

# State manifests
mkdir -p "${stage_dir}/manifests"
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > "${stage_dir}/manifests/packages.tsv"
systemctl list-unit-files --type=service --no-pager > "${stage_dir}/manifests/systemd-unit-files.txt"
systemctl list-units --type=service --state=running --no-pager > "${stage_dir}/manifests/running-services.txt"
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' > "${stage_dir}/manifests/docker-ps.tsv" || true
docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' > "${stage_dir}/manifests/docker-images.tsv" || true
ip -brief addr > "${stage_dir}/manifests/ip-brief-addr.txt"
df -h > "${stage_dir}/manifests/df-h.txt"
nmcli -t -f NAME,UUID,DEVICE,TYPE connection show > "${stage_dir}/manifests/nmcli-connections.txt" || true

tar -C "${stage_dir}" -czf "${archive_path}" .

cat > "${summary_path}" <<EOF
Created: $(date --iso-8601=seconds)
Archive: ${archive_path}
Included:
- Vaultwarden full data directory and sqlite backup
- Vaultwarden docker-compose and env
- DDNS scripts and cron
- nginx config and /etc/letsencrypt
- cloudflared service/unit files and config if present
- NetworkManager connection profiles
- LED-off persistent service
- Package, service, docker and network manifests
EOF

echo "Backup created:"
echo "${archive_path}"
echo "${summary_path}"
