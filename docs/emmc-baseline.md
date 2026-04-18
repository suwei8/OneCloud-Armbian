# OneCloud eMMC 基线镜像

## 目标

生成一份可以在大故障后“尽量完整回到当前状态”的 eMMC 整盘基线镜像。

这不是应用级备份，而是整盘位级镜像。

## 关键原则

不要在当前从 eMMC 运行的系统上直接对 eMMC 根盘做整盘基线。

更稳的方式：

1. 用 SD 卡或维护系统启动
2. 确保 eMMC 不是当前根分区
3. 再对 `/dev/mmcblk1` 做整盘导出

## 脚本

- [onecloud_emmc_baseline_backup.sh](D:/dev-root3/OneCloud-Armbian/scripts/onecloud_emmc_baseline_backup.sh)

用途：

- 从维护系统对 `eMMC` 做整盘镜像
- 自动压缩
- 自动生成 `sha256`
- 自动写一份恢复说明

## 推荐执行方式

假设：

- 维护系统已经从 SD 卡启动
- eMMC 是 `/dev/mmcblk1`
- 备份输出目录已挂到 `/mnt/backup`

执行：

```bash
chmod +x /usr/local/sbin/onecloud_emmc_baseline_backup.sh
/usr/local/sbin/onecloud_emmc_baseline_backup.sh /mnt/backup /dev/mmcblk1
```

产物：

- `onecloud-emmc-baseline-<host>-<timestamp>.img.gz`
- `onecloud-emmc-baseline-<host>-<timestamp>.img.gz.sha256`
- `README-<timestamp>.txt`

## 恢复示例

从维护系统恢复：

```bash
gunzip -c onecloud-emmc-baseline-<host>-<timestamp>.img.gz | dd of=/dev/mmcblk1 bs=4M status=progress conv=fsync
```

## 建议策略

- 日常：继续使用应用级恢复包 + Vaultwarden 异地备份
- 重大稳定版本确认后：再做一次 eMMC 基线
- 基线镜像不要高频做，但一定要在“系统稳定、服务都恢复好”的节点做
