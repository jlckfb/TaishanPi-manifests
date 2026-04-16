# TaishanPi Manifests

[English](README.md) | 中文

TaishanPi 系列开发板的 `repo` manifest 统一管理仓库。每个 SDK 版本对应一个独立分支，包含 `default.xml` 和专属安装脚本。

## 一键安装

通过统一入口脚本，指定 `-b` 分支即可自动下载对应版本的安装脚本并执行：

```bash
# Android14 - TaishanPi-3
curl -fsSL https://raw.githubusercontent.com/jlckfb/manifests/main/install.sh | bash -s -- -b android14/tspi-3-260416

# Linux - TaishanPi-3
curl -fsSL https://raw.githubusercontent.com/jlckfb/manifests/main/install.sh | bash -s -- -b linux/tspi-3-260402
```

## 手动下载

如果只需要拉取源码（不安装编译依赖），可直接使用 `repo`：

```bash
# 安装 repo
mkdir -p ~/.bin
curl -fsSL https://cnb.cool/jlckfb/git-repo/-/git/raw/main/repo -o ~/.bin/repo
chmod a+rx ~/.bin/repo
export PATH="$HOME/.bin:$PATH"
export REPO_URL="https://cnb.cool/jlckfb/git-repo"
export REPO_REV="main"

# Android14
mkdir -p ~/TaishanPi-3-Android14 && cd ~/TaishanPi-3-Android14
repo init -u https://github.com/jlckfb/manifests.git -b android14/tspi-3-260416 --depth=1
repo sync -c -j$(nproc)

# Linux
mkdir -p ~/TaishanPi-3-Linux && cd ~/TaishanPi-3-Linux
repo init -u https://github.com/jlckfb/manifests.git -b linux/tspi-3-260402 --depth=1 --no-clone-bundle
repo sync -c --no-clone-bundle -j$(nproc)
```

## 可用版本

| 系统 | 开发板 | 分支 | 代码托管 |
|------|--------|------|----------|
| Android14 | TaishanPi-3 (RK3576) | `android14/tspi-3-260416` | [cnb.cool](https://cnb.cool/TaishanPi-Rockchip-Android) |
| Linux | TaishanPi-3 (RK3576) | `linux/tspi-3-260402` | [gitcode.com](https://gitcode.com/TaishanPi-Rockchip) |

## 仓库结构

```
main                        ← 入口脚本 install.sh + README 索引
android14/tspi-3-260416     ← default.xml + setup.sh (Android14 专用)
linux/tspi-3-260402         ← default.xml (占位，待迁移)
```

## 分支命名规则

```
{os}{version}/{board}-{date}
```

示例：`android14/tspi-3-260416`、`android15/tspi-3-xxxxxx`、`linux/tspi-3-260402`
