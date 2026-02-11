# OneCloud Armbian 自定义固件

[![Build OneCloud Armbian](https://github.com/suwei8/OneCloud-Armbian/actions/workflows/build.yml/badge.svg)](https://github.com/suwei8/OneCloud-Armbian/actions/workflows/build.yml)

为 **玩客云 (OneCloud)** 定制的 Armbian 固件，基于官方 [armbian/build](https://github.com/armbian/build) 框架编译，**开箱即用自带 Docker**。

## 设备信息

| 项目 | 详情 |
|------|------|
| SoC | Amlogic S805 (meson8b) |
| CPU | 4x ARMv7 Cortex-A5 @ 1.5GHz |
| RAM | 1GB DDR3 |
| eMMC | 8GB |
| 网络 | 千兆以太网 |

## 固件特性

- ✅ 基于 Armbian 官方源码编译
- ✅ **Docker CE + Docker Compose 预装**
- ✅ 系统优化 (低内存设备调优)
- ✅ 常用工具预装 (htop, tmux, git, iperf3 等)
- ✅ 支持 eMMC 刷机 (burn.img)
- ✅ 支持 SD 卡 / USB 启动

## 下载固件

前往 [Releases](https://github.com/suwei8/OneCloud-Armbian/releases) 页面下载最新固件。

| 文件类型 | 说明 |
|----------|------|
| `*.img.xz` | 标准镜像 (SD 卡 / USB 启动) |
| `*.burn.img` | eMMC 刷机包 (USB Burning Tool) |

## 手动编译

### 通过 GitHub Actions (推荐)

1. Fork 本仓库
2. 进入 **Actions** → **Build OneCloud Armbian**
3. 点击 **Run workflow**，选择参数：
   - **OS Release**: `bookworm` (Debian 12) / `noble` (Ubuntu 24.04) / `trixie` (Debian 13)
   - **Build Type**: `cli` (推荐) / `minimal`
   - **Kernel Branch**: `current` (稳定) / `edge` (最新)
4. 等待编译完成，固件自动发布到 Releases

### 本地编译

```bash
git clone https://github.com/armbian/build
cd build
cp -r /path/to/OneCloud-Armbian/userpatches/* userpatches/
sudo ./compile.sh build \
    BOARD=onecloud \
    BRANCH=current \
    RELEASE=bookworm \
    BUILD_MINIMAL=no \
    BUILD_DESKTOP=no
```

## 刷机指南

### eMMC 刷机 (USB Burning Tool)

1. 下载 `*.burn.img` 文件
2. 打开 [USB Burning Tool](https://androidmtk.com/download-amlogic-usb-burning-tool)
3. 导入 burn.img 文件
4. 短接玩客云主板刷机触点，USB 连接电脑
5. 点击「开始」等待刷机完成

### 首次登录

- **用户名**: `root`
- **密码**: `1234` (首次登录会提示修改)

## 致谢

- [armbian/build](https://github.com/armbian/build) - Armbian 官方构建框架
- [hzyitc/armbian-onecloud](https://github.com/hzyitc/armbian-onecloud) - OneCloud 适配贡献者
- [hzyitc/u-boot-onecloud](https://github.com/hzyitc/u-boot-onecloud) - OneCloud U-Boot

## License

This project follows the [Armbian Build Framework License](https://github.com/armbian/build/blob/main/LICENSE).
