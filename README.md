# TaishanPi-3 Android14 SDK

基于 Rockchip RK3576 的 TaishanPi-3 开发板 Android14 SDK，通过 `repo` 工具管理多仓库代码。

- SoC: Rockchip RK3576
- Android 版本: 14
- 代码托管: [cnb.cool/TaishanPi-Rockchip-Android](https://cnb.cool/TaishanPi-Rockchip-Android)

## 快速开始

### 系统要求

- Ubuntu 20.04 / 22.04 LTS (x86_64)
- 磁盘空间 >= 500GB
- 内存 >= 32GB

### 下载源码

```bash
# 安装 repo (如已安装可跳过)
mkdir -p ~/.bin
curl -L https://storage.googleapis.com/git-repo-downloads/repo -o ~/.bin/repo
chmod a+rx ~/.bin/repo
export PATH="$HOME/.bin:$PATH"

# 初始化并同步
mkdir -p ~/TaishanPi-3-Android14 && cd ~/TaishanPi-3-Android14
repo init -u https://github.com/jlckfb/manifests.git -b android14/tspi-3-260416 --depth=1
repo sync -c -j$(nproc)
```

### 编译

```bash
cd ~/TaishanPi-3-Android14
source build/envsetup.sh
lunch rk3576-userdebug
make -j$(nproc)
```

## Manifest 信息

- Manifest 分支: `android14/tspi-3-260416`
- 代码 Remote: `cnb` -> `https://cnb.cool/TaishanPi-Rockchip-Android`
- 代码 Revision: `tspi-3-Android14-260415`
