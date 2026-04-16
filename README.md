# TaishanPi Manifests

TaishanPi 系列开发板的 `repo` manifest 统一管理仓库。

## 可用版本

| 系统 | 开发板 | 分支 | 代码托管 | 使用命令 |
|------|--------|------|----------|----------|
| Android14 | TaishanPi-3 (RK3576) | `android14/tspi-3-260416` | [cnb.cool](https://cnb.cool/TaishanPi-Rockchip-Android) | 见下方 |

## 使用方法

### Android14 - TaishanPi-3

```bash
repo init -u https://github.com/jlckfb/manifests.git -b android14/tspi-3-260416 --depth=1
repo sync -c -j$(nproc)
```

## 分支命名规则

```
{os}{version}/{board}-{date}
```

示例：`android14/tspi-3-260416`、`android15/tspi-3-xxxxxx`、`linux/tspi-3-260402`
