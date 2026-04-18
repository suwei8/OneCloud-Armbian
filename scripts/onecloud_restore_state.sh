#!/bin/bash
set -euo pipefail

restore_root="${1:-/root/onecloud_restore}"
restore_stage="${restore_root}/extracted"
archive_override="${2:-}"

require_root() {
    if [ "${EUID}" -ne 0 ]; then
        echo "Please run as root." >&2
        exit 1
    fi
}

install_packages() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y \
        ca-certificates \
        cron \
        curl \
        docker.io \
        docker-compose-plugin \
        nginx \
        sqlite3 \
        network-manager
}

extract_backup() {
    mkdir -p "${restore_stage}"
    if [ -n "${archive_override}" ]; then
        tar -C "${restore_stage}" -xzf "${archive_override}"
        return
    fi

    local archive
    archive="$(find "${restore_root}" -maxdepth 2 -type f -name 'onecloud_state_*.tar.gz' | sort | tail -n 1)"
    if [ -z "${archive}" ]; then
        echo "Backup archive not found under ${restore_root}" >&2
        exit 1
    fi
    tar -C "${restore_stage}" -xzf "${archive}"
}

restore_tree() {
    local src_rel="$1"
    local dst="$2"
    if [ -e "${restore_stage}/${src_rel}" ]; then
        mkdir -p "$(dirname "${dst}")"
        if [ -d "${restore_stage}/${src_rel}" ]; then
            mkdir -p "${dst}"
            cp -a "${restore_stage}/${src_rel}/." "${dst}/"
        else
            cp -a "${restore_stage}/${src_rel}" "${dst}"
        fi
    fi
}

restore_network() {
    if compgen -G "${restore_stage}/etc/NetworkManager/system-connections/*" > /dev/null; then
        mkdir -p /etc/NetworkManager/system-connections
        cp -a "${restore_stage}/etc/NetworkManager/system-connections/." /etc/NetworkManager/system-connections/
        chmod 600 /etc/NetworkManager/system-connections/* || true
        systemctl restart NetworkManager
    fi
}

restore_vaultwarden() {
    if [ -e "${restore_stage}/vaultwarden" ]; then
        mkdir -p /root/Vaultwarden
        cp -a "${restore_stage}/vaultwarden/." /root/Vaultwarden/
        mkdir -p /root/Vaultwarden/data
        if [ -f /root/Vaultwarden/data/db.sqlite3.backup ] && [ ! -f /root/Vaultwarden/data/db.sqlite3 ]; then
            cp -a /root/Vaultwarden/data/db.sqlite3.backup /root/Vaultwarden/data/db.sqlite3
        fi
        if [ -f /root/Vaultwarden/docker-compose.yml ]; then
            docker compose -f /root/Vaultwarden/docker-compose.yml pull || true
            docker compose -f /root/Vaultwarden/docker-compose.yml up -d
        fi
    fi
}

require_root
install_packages
extract_backup

restore_tree root/Aliyun-DDNS-update-linux.sh /root/Aliyun-DDNS-update-linux.sh
restore_tree root/Cloudflare-DDNS-update-linux.sh /root/Cloudflare-DDNS-update-linux.sh
chmod 700 /root/Aliyun-DDNS-update-linux.sh /root/Cloudflare-DDNS-update-linux.sh 2>/dev/null || true

restore_tree etc/cron.d/onecloud-ddns /etc/cron.d/onecloud-ddns
restore_tree etc/nginx/conf.d/b.13982.com.conf /etc/nginx/conf.d/b.13982.com.conf
restore_tree etc/letsencrypt /etc/letsencrypt
restore_tree etc/systemd/system/cloudflared.service /etc/systemd/system/cloudflared.service
restore_tree etc/systemd/system/cloudflared-update.service /etc/systemd/system/cloudflared-update.service
restore_tree etc/systemd/system/cloudflared-update.timer /etc/systemd/system/cloudflared-update.timer
restore_tree etc/default/cloudflared /etc/default/cloudflared
restore_tree etc/cloudflared /etc/cloudflared
restore_tree usr/local/sbin/onecloud-leds-off.sh /usr/local/sbin/onecloud-leds-off.sh
restore_tree etc/systemd/system/onecloud-leds-off.service /etc/systemd/system/onecloud-leds-off.service
restore_tree etc/hostname /etc/hostname
restore_tree etc/hosts /etc/hosts

chmod 755 /usr/local/sbin/onecloud-leds-off.sh 2>/dev/null || true

restore_vaultwarden
restore_network

systemctl daemon-reload
systemctl enable cron nginx docker onecloud-leds-off.service
systemctl restart cron
nginx -t
systemctl restart nginx
systemctl restart onecloud-leds-off.service

if systemctl list-unit-files | grep -q '^cloudflared.service'; then
    systemctl enable cloudflared.service || true
    systemctl restart cloudflared.service || true
fi

echo "Restore complete."
echo "Verify:"
echo "  systemctl status nginx docker cloudflared onecloud-leds-off --no-pager"
echo "  docker ps"
echo "  curl -I https://b.13982.com"
