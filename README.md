# XGP V3 Screen

NLnet XiGuaPi V3 TFT 屏幕控制程序，支持 Web 配置界面。

## 项目来源

- **原始项目**: [zzzz0317/xgp-v3-screen](https://github.com/zzzz0317/xgp-v3-screen)
- **原始作者**: zzzz0317
- **许可证**: GPL-3.0

## 改造内容

本项目在原始版本基础上进行了以下改造：

### 1. 集成硬件驱动
- ✅ 使用 OpenWrt master 的 `kmod-drm-panel-mipi-dbi` 通用 DRM 面板驱动
- ✅ 内置 GC9307 MIPI DBI 初始化序列固件包
- ✅ 通过 DRM fbdev emulation 提供标准 Linux framebuffer 接口
- ✅ 支持通过配置指定 framebuffer 设备路径
- ✅ 编译时自动构建初始化固件和应用包

### 2. 新增 LuCI Web 控制界面
- ✅ 集成到 OpenWrt 管理界面（服务 → XGP Screen）
- ✅ 支持配置项：
  - 启用/禁用屏幕（同时控制背光）
  - 切换动画类型（10种动画效果）
  - 默认停留时间
  - 跳过启动/闪屏画面
  - 每个页面独立配置（启用、停留时间、显示顺序）
  - Framebuffer 设备选择
  - 流量监控接口配置和手动清零

### 3. 屏幕切换动画
支持以下动画效果：
| 配置值 | 效果 |
|-------|------|
| `none` | 无动画 |
| `fade` | 淡入淡出 |
| `slide_up` | 向上滑动（默认） |
| `slide_down` | 向下滑动 |
| `slide_left` | 向左滑动 |
| `slide_right` | 向右滑动 |
| `over_up` | 从下往上覆盖 |
| `over_down` | 从上往下覆盖 |
| `over_left` | 从右往左覆盖 |
| `over_right` | 从左往右覆盖 |

### 4. 修复 Modem IP 显示问题
- ✅ 支持 `wwan*` 和 `rmnet_mhi*` 两种接口类型

### 5. 防止控制台日志干扰
- ✅ 启动时自动禁用 framebuffer 控制台输出
- ✅ 降低内核打印级别，防止设备插拔日志显示在屏幕上

### 6. 屏幕管理优化
- ✅ 移除硬编码的屏幕切换逻辑
- ✅ 由配置文件统一管理屏幕切换
- ✅ 关闭屏幕时自动关闭背光并清空显示

### 7. 新增流量监控页面
- ✅ 实时显示WAN接口上传/下载流量统计
- ✅ 支持自定义监控接口列表（eth1, wwan, wan, pppoe等）
- ✅ 支持前缀匹配，灵活配置移动网络接口
- ✅ 自动累加多个WAN接口流量（支持双WAN场景）
- ✅ 数据持久化存储（`/etc/xgp_screen_traffic.dat`）
- ✅ 每日零点自动重置当日统计
- ✅ 手动清零功能（LuCI界面或命令行）
- ✅ 智能单位转换（B/KB/MB/GB自动选择）
- ✅ 每2秒自动刷新数据

## 项目结构

```
xgp-v3-screen/
├── Makefile                    # OpenWrt 包构建文件（初始化固件和应用）
├── mipi-dbi-gc9307/           # GC9307 MIPI DBI 初始化序列和固件转换工具
│   ├── galaxycore,gc9307.txt
│   └── mipi-dbi-cmd
├── files/
│   ├── modem_info.py          # Modem 信息获取脚本
│   ├── xgp_screen.config      # 默认 UCI 配置
│   ├── uci-defaults-xgp-screen # UCI 初始化脚本
│   └── zz_xgp_screen.init     # procd 服务脚本
├── luasrc/                     # LuCI 应用
│   ├── controller/
│   │   └── xgp_screen.lua
│   └── model/cbi/
│       └── xgp_screen.lua
└── src/
    ├── main.c                  # 主程序
    ├── screen_config.c/h       # 配置解析模块
    ├── screen_manager.c/h      # 屏幕管理器
    └── ui/                     # LVGL UI 文件
```

## 编译安装

### 前置条件

此包面向包含 `kmod-drm-panel-mipi-dbi` 的 OpenWrt master。`kmod-drm-panel-mipi-dbi` 是在 OpenWrt 的 `make menuconfig` 中选择的内核模块包；DRM fbdev emulation 则是 Linux 内核配置项，两者不是同一个选项。需要 `/dev/fb*` 时，检查并启用 `CONFIG_DRM_FBDEV_EMULATION`：
```bash
make kernel_menuconfig
# 在内核配置界面按 /，搜索 DRM_FBDEV_EMULATION
# 确认 Enable legacy fbdev support for your modesetting driver 已启用
```
fbdev emulation 只负责在 DRM 设备成功注册后提供兼容的 `/dev/fb*`，不能代替设备树中的面板节点，也不会单独创建 `/dev/dri/card0`。如果 `/sys/class/drm` 中只有 `version` 且没有 `/dev/dri/card0`，应先排查 SPI 面板设备是否出现在设备树中、驱动是否成功 probe，再检查 fbdev 配置。`xgp-v3-screen` 会依赖并自动安装 `kmod-drm-panel-mipi-dbi` 及 GC9307 初始化固件。还需在设备树中将屏幕 SPI 节点配置为 `galaxycore,gc9307`、`panel-mipi-dbi-spi` 兼容设备，并设置实际使用的 SPI 总线、片选、D/C、复位和背光 GPIO。通用驱动通过第一个 compatible 值请求 `/lib/firmware/galaxycore,gc9307.bin`。例如：

```dts
display@0 {
	compatible = "galaxycore,gc9307", "panel-mipi-dbi-spi";
	reg = <0>;
	spi-max-frequency = <24000000>;
	dc-gpios = <&gpio 24 GPIO_ACTIVE_HIGH>;
	reset-gpios = <&gpio 25 GPIO_ACTIVE_HIGH>;
	write-only;
	format = "r5g6b5";
	width-mm = <35>;
	height-mm = <28>;

	panel-timing {
		hactive = <240>;
		vactive = <320>;
		hback-porch = <0>;
		vback-porch = <0>;
		clock-frequency = <0>;
		hfront-porch = <0>;
		hsync-len = <0>;
		vfront-porch = <0>;
		vsync-len = <0>;
	};
};
```
将示例 GPIO、片选、SPI 速率和面板物理尺寸替换为目标板实际值（上面的 `35`、`28` 仅为格式示例）。设备树的 GPIO 定义需包含 `<dt-bindings/gpio/gpio.h>`。

### 1. 放置源码
```bash
# 将项目放入 OpenWrt 的 package 目录
cp -r xgp-v3-screen ~/openwrt/package/
```

### 2. 选择包
```bash
make menuconfig
# 进入 Utilities → xgp-v3-screen
```

### 3. 编译
```bash
make package/xgp-v3-screen/compile -j$(nproc)
```

编译完成后会生成两个包：
- `mipi-dbi-gc9307-*.apk` - GC9307 MIPI DBI 初始化固件
- `xgp-v3-screen-*.apk` - 屏幕控制程序（依赖初始化固件和 DRM 面板驱动）

### 4. 安装
```bash
# APK 包管理器 (ImmortalWrt 25.x)
# 驱动会作为依赖自动安装
apk add --allow-untrusted xgp-v3-screen-*.apk

# OPKG 包管理器 (OpenWrt)
opkg install xgp-v3-screen-*.ipk
```

## 配置文件

配置文件位置: `/etc/config/xgp_screen`

```
config screen 'main'
    option enabled '1'
    option fb_device ''
    option scroll_type 'slide_up'
    option default_delay '5000'
    option skip_boot '0'
    option skip_splash '0'

config traffic 'settings'
    list interfaces 'eth1'
    list interfaces 'wwan0'
    list interfaces 'wwan0_1'
    option reset '0'

config page 'system_info'
    option enabled '1'
    option delay '5000'
    option order '1'

config page 'system_status'
    option enabled '1'
    option delay '5000'
    option order '2'

config page 'traffic'
    option enabled '1'
    option delay '5000'
    option order '6'

# ... 更多页面配置
```

### 流量统计功能

**支持的接口类型：**
- 有线WAN: `eth1`
- 移动网络: `wwan0`, `wwan0_1`, `wwan1` 等
- PPPoE拨号: `pppoe-wan`
- 通用WAN: `wan`, `wan6`

**配置示例：**
```bash
# 添加监控接口
uci add_list xgp_screen.settings.interfaces='eth1'
uci add_list xgp_screen.settings.interfaces='wwan'
uci commit xgp_screen

# 手动清零流量统计
uci set xgp_screen.settings.reset='1'
uci commit xgp_screen
/etc/init.d/zz_xgp_screen restart

# 清零后标志会自动重置为0
```

**数据存储：**
- 位置: `/etc/xgp_screen_traffic.dat`
- 格式: 二进制格式，包含总流量和当日流量
- 更新频率: 每2秒
- 重置时间: 每日00:00自动重置当日统计
```

## 依赖

**编译依赖：**
- OpenWrt 编译环境
- OpenWrt master 中的 `kmod-drm-panel-mipi-dbi`
- 目标内核需启用 DRM fbdev emulation，以提供 `/dev/fb*`

**运行时依赖：**
- `python3` - Modem 信息获取
- `libpthread` - 多线程支持
- `libstdcpp` - C++ 标准库
- `luci-base` - LuCI 基础框架
- `kmod-drm-panel-mipi-dbi` - 通用 MIPI DBI DRM 面板驱动（自动安装）
- `mipi-dbi-gc9307` - GC9307 面板初始化固件（自动安装）

## 服务管理

```bash
# 启动
/etc/init.d/zz_xgp_screen start

# 停止
/etc/init.d/zz_xgp_screen stop

# 重启
/etc/init.d/zz_xgp_screen restart

# 查看状态
ps | grep zz_xgp_screen
```

## 许可证

GPL-3.0-only

## 致谢

- 原始项目作者 [zzzz0317](https://github.com/zzzz0317)
  - [xgp-v3-screen](https://github.com/zzzz0317/xgp-v3-screen) - 屏幕控制程序
- [panel-mipi-dbi](https://github.com/notro/panel-mipi-dbi) - MIPI DBI 面板固件格式工具
- [LVGL](https://lvgl.io/) - 嵌入式图形库
