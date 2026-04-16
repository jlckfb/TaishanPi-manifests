# TaishanPi Manifests

TaishanPi 系列开发板的 `repo` manifest 统一管理仓库。

## 一键安装

```bash
# Android14 - TaishanPi-3
curl -fsSL https://raw.githubusercontent.com/jlckfb/manifests/main/install.sh | bash -s -- -b android14/tspi-3-260416

# Linux - TaishanPi-3
curl -fsSL https://raw.githubusercontent.com/jlckfb/manifests/main/install.sh | bash -s -- -b linux/tspi-3-260402
```

脚本会自动根据分支名识别 SDK 类型（Android/Linux），安装对应的编译依赖、下载 SDK 源码、拉取 LFS 大文件。

## 手动下载

```bash
# Android14
repo init -u https://github.com/jlckfb/manifests.git -b android14/tspi-3-260416 --depth=1
repo sync -c -j$(nproc)

# Linux
repo init -u https://github.com/jlckfb/manifests.git -b linux/tspi-3-260402 --depth=1
repo sync -c --no-clone-bundle -j$(nproc)
```

## 可用版本

| 系统 | 开发板 | 分支 | 代码托管 |
|------|--------|------|----------|
| Android14 | TaishanPi-3 (RK3576) | `android14/tspi-3-260416` | [cnb.cool](https://cnb.cool/TaishanPi-Rockchip-Android) |

## 分支命名规则

```
{os}{version}/{board}-{date}
```

示例：`android14/tspi-3-260416`、`linux/tspi-3-260402`
