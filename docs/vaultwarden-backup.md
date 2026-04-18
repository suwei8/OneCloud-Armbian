# Vaultwarden 邮件 + OneDrive 备份

## 目标

每 3 小时对当前玩客云上的 Vaultwarden 做一次关键数据备份，并执行两条异地链路：

- 微软邮箱发信到 Gmail
- `rclone copy` 上传到 OneDrive

当前设计只备份关键恢复资产，不包含 `attachments/`：

- `db.sqlite3` 的一致性备份
- `config.json`
- `rsa_key.pem`
- `rsa_key.pub.pem`
- `docker-compose.yml`

## 脚本

- [vaultwarden_backup.sh](D:/dev-root3/OneCloud-Armbian/scripts/vaultwarden_backup.sh)
- [vaultwarden_backup_runner.sh](D:/dev-root3/OneCloud-Armbian/scripts/vaultwarden_backup_runner.sh)
- [send_backup_email.py](D:/dev-root3/OneCloud-Armbian/scripts/send_backup_email.py)
- [backup.env.example](D:/dev-root3/OneCloud-Armbian/scripts/backup.env.example)

## OneCloud 部署路径

- `/usr/local/sbin/vaultwarden_backup.sh`
- `/usr/local/sbin/vaultwarden_backup_runner.sh`
- `/usr/local/sbin/send_backup_email.py`
- `/root/.config/onecloud-backup/backup.env`
- `/etc/cron.d/vaultwarden-backup`

## 运行逻辑

1. 用 `sqlite3 .backup` 生成一致性数据库备份
2. 复制恢复所需密钥和配置
3. 生成 `tar.gz`
4. 发邮件
5. 上传 OneDrive
6. 清理超过保留天数的本地备份
7. 备份失败时，发一封纯文本告警邮件

邮件链路支持可选 IMAP 清理发件箱，适合像 126 邮箱这种长期定时发送的场景。

## 为什么不直接挂载网盘

- `rclone mount` 更脆弱，启动顺序和网络抖动都会影响稳定性
- Vaultwarden 是关键数据，主链路应为“本地生成备份包，再上传”
- `rclone copy` 更适合无人值守

## 尚需补齐的信息

在真正启用前，需要填写：

- 发信邮箱 SMTP 账号
- 发信邮箱 SMTP 密码或授权码
- Gmail 收件地址
- `rclone` 的 OneDrive 授权

## 建议 cron

```cron
5 */3 * * * root /usr/local/sbin/vaultwarden_backup_runner.sh
```
