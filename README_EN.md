# TaishanPi Manifests

[中文](README.md) | English

Unified `repo` manifest repository for TaishanPi series development boards. Each SDK version lives on its own branch with a `default.xml` and a dedicated setup script.

## One-Click Install

Use the bootstrap script with `-b` to specify the branch:

```bash
# Android14 - TaishanPi-3
curl -fsSL https://raw.githubusercontent.com/jlckfb/manifests/main/install.sh | bash -s -- -b android14/tspi-3-260416

# Linux - TaishanPi-3
curl -fsSL https://raw.githubusercontent.com/jlckfb/manifests/main/install.sh | bash -s -- -b linux/tspi-3-260402
```

## Manual Download

To fetch source code only (without installing build dependencies), use `repo` directly:

```bash
# Install repo
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

## Available Versions

| OS | Board | Branch | Code Hosting |
|----|-------|--------|--------------|
| Android14 | TaishanPi-3 (RK3576) | `android14/tspi-3-260416` | [cnb.cool](https://cnb.cool/TaishanPi-Rockchip-Android) |
| Linux | TaishanPi-3 (RK3576) | `linux/tspi-3-260402` | [gitcode.com](https://gitcode.com/TaishanPi-Rockchip) |

## Repository Structure

```
main                        ← Bootstrap install.sh + README
android14/tspi-3-260416     ← default.xml + setup.sh (Android14)
linux/tspi-3-260402         ← default.xml (placeholder, pending migration)
```

## Branch Naming Convention

```
{os}{version}/{board}-{date}
```

Examples: `android14/tspi-3-260416`, `android15/tspi-3-xxxxxx`, `linux/tspi-3-260402`
