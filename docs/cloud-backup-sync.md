# GitHub Actions 云间同步

## 目标

将玩客云已经上传到 OneDrive 的 Vaultwarden 备份，再同步一份到 Google Drive。

推荐采用混合触发：

- `repository_dispatch`：
  玩客云每次成功上传 OneDrive 后，主动通知 GitHub Actions
- `schedule`：
  每天 2 次补偿同步
- `workflow_dispatch`：
  手工兜底

原因：

- GitHub `schedule` 会延迟，极端高负载下甚至可能丢队列
- 公开仓库若 `60` 天没有仓库活动，定时工作流会被自动停用
- 但 GitHub Actions 作为“第三副本同步器”仍然值得做

## 工作流

- [cloud-backup-sync.yml](D:/dev-root3/OneCloud-Armbian/.github/workflows/cloud-backup-sync.yml)

默认同步策略：

- `latest-only`
  - 只复制 OneDrive 中最新的一份备份到 Google Drive
- `full-copy`
  - 将整个备份目录复制到 Google Drive

默认远端：

- Source: `onedrive:OneCloudBackups/Vaultwarden/onecloud`
- Destination: `gdrive:OneCloudBackups/Vaultwarden/onecloud`

## GitHub Secrets / Variables

### Secret

- `RCLONE_SYNC_CONF`

内容是一整份 `rclone.conf`，至少包含两个 remote：

- `[onedrive]`
- `[gdrive]`

GitHub Actions secret 单个大小上限是 `48 KB`，而这一份配置通常远小于这个值，适合直接存进去。

### Variable

- `GDRIVE_KEEP_DAYS`
  - 默认建议 `60`

## 建议的 rclone.conf 结构

```ini
[onedrive]
type = onedrive
token = ...
drive_type = business
drive_id = ...
root_folder_id = ...

[gdrive]
type = drive
token = ...
team_drive =
root_folder_id =
```

## 玩客云侧可选主动触发

如果你想减少 GitHub `schedule` 的不确定性，可以在玩客云上传 OneDrive 成功后，再调用一次 GitHub API：

- [onecloud_github_dispatch.sh](D:/dev-root3/OneCloud-Armbian/scripts/onecloud_github_dispatch.sh)

配合 [backup.env.example](D:/dev-root3/OneCloud-Armbian/scripts/backup.env.example) 中这些项：

- `GITHUB_DISPATCH_ENABLED=1`
- `GITHUB_DISPATCH_REPO=suwei8/OneCloud-Armbian`
- `GITHUB_DISPATCH_TOKEN=...`
- `GITHUB_DISPATCH_EVENT=onecloud-backup-uploaded`

当前脚本已支持：

- 玩客云上传 OneDrive 成功后，尝试触发 `repository_dispatch`
- 如果 dispatch 失败，不影响本地备份和 OneDrive 上传主流程

## 可靠性边界

- GitHub Actions 适合作为第三副本同步器，不建议作为唯一备份链路
- 最可靠的主链路仍然是：
  - 玩客云本地备份
  - Gmail 邮件备份
  - OneDrive 备份
- GitHub Actions 更适合做：
  - OneDrive -> Google Drive
  - 周期补偿同步
  - 手工触发同步
