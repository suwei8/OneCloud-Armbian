# OneCloud 备份与快速恢复

当前这台玩客云建议保留两层备份，它们解决的是两类不同问题。

## 1. 现状精确恢复

适用场景：
- 想在重刷 Armbian 后快速恢复到现在的业务状态
- 保留 Vaultwarden、DDNS、证书、静态 IP、LED 配置、cloudflared 这类关键配置

执行备份：

```bash
chmod +x /usr/local/sbin/onecloud_state_backup.sh
/usr/local/sbin/onecloud_state_backup.sh
```

备份内容：
- `/root/Vaultwarden/data` 全量
- Vaultwarden `docker-compose.yml` 和 `.env`
- `Aliyun-DDNS-update-linux.sh`
- `Cloudflare-DDNS-update-linux.sh`
- `/etc/cron.d/onecloud-ddns`
- `/etc/nginx/conf.d/b.13982.com.conf`
- `/etc/letsencrypt`
- cloudflared 的 systemd 单元和配置
- `NetworkManager` 连接配置
- LED 持久化关闭脚本和 systemd 服务
- 已安装包、运行中服务、Docker 镜像/容器、IP/磁盘等清单

执行恢复：

```bash
chmod +x /root/onecloud_restore/onecloud_restore_state.sh
/root/onecloud_restore/onecloud_restore_state.sh /root/onecloud_restore
```

说明：
- 这是“应用状态恢复”，不是整盘位级回滚。
- 适合在新刷好的 Armbian 上快速恢复服务。
- 如果 DHCP 环境已变化，恢复静态 IP 前先确认网络不会把自己锁死。
- `cloudflared` 本地可恢复的是服务单元和 token；如果 Tunnel 的 hostname / ingress 规则是在 Cloudflare 账号侧远程管理，仍要以 Cloudflare 控制台上的配置为准。

## 2. 完全回滚到当前系统

适用场景：
- 希望将来线刷后恢复到“和现在一模一样”的系统状态
- 包括系统包版本、容器层、日志、所有配置和文件布局

做法：
- 对当前 eMMC 做整盘镜像备份
- 保存镜像文件到电脑或大容量存储

示例：

```bash
dd if=/dev/mmcblk1 of=/root/onecloud-emmc-baseline.img bs=4M status=progress
gzip -1 /root/onecloud-emmc-baseline.img
```

说明：
- 这是唯一能做到“刷回去就是现在这个样子”的方案。
- 缺点是镜像更大、制作和恢复都更慢。
- 适合作为最终兜底基线，不建议高频执行。

## 建议的实际策略

- 日常：定期执行状态备份，成本低，恢复快
- 重大变更后：做一次新的 eMMC 基线镜像
- 真出故障时：
  - 配置损坏或重刷后恢复服务：用状态备份
  - 想百分百回到今天这台机器：用 eMMC 基线镜像
