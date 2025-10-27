# 电子科技大学清水河校区电信自动登录

适用于电子科技大学清水河校区本科宿舍电信网络的自动登录工具，专为路由器等嵌入式设备设计。

## 特性

- 纯 Go 语言编写，无需运行时依赖
- 静态编译，单个可执行文件
- 支持 19+ 平台架构
- 密码 RSA 加密存储
- 自动网络检测
- 定时刷新租期
- 内存占用极低

## 快速开始

### 方式一：自动安装（推荐，适用于 OpenWRT 路由器）

1. 下载对应平台的编译文件到本地
2. 修改 `install.sh` 中的账号密码
3. 运行安装脚本：

```bash
./install.sh
```

安装脚本会自动：

- 清理旧安装
- 上传登录程序到路由器
- 配置定时任务（每小时检查网络）
- 配置自动刷新（每天凌晨 5 点）
- 配置开机自启动

### 方式二：手动使用

下载对应平台的可执行文件，运行：

```bash
# 登录
./login -name 手机号 -passwd 密码

# 使用缓存（密码加密存储）
./login -name 手机号 -passwd 密码 -cache ./cache.json

# 下次使用缓存登录
./login -cache ./cache.json

# 登出
./login -cache ./cache.json -logout
```

## 支持平台

GitHub Actions 自动构建以下平台，每个平台提供原始版本和 UPX 压缩版本：

### Linux

- `linux-amd64` - x86_64 服务器/PC
- `linux-386` - 32 位 x86
- `linux-arm64` - ARM64 (树莓派 4 等)
- `linux-armv7` - ARMv7 (小米路由器、树莓派 2/3)
- `linux-armv6` - ARMv6 (树莓派 1)
- `linux-armv5` - ARMv5 (老旧 ARM 设备)
- `linux-mips` / `linux-mipsle` - MIPS 路由器
- `linux-mips64` / `linux-mips64le` - 64 位 MIPS
- `linux-ppc64le` - IBM POWER
- `linux-riscv64` - RISC-V

### macOS

- `darwin-amd64` - Intel Mac
- `darwin-arm64` - Apple Silicon (M1/M2/M3)

### Windows

- `windows-amd64` - 64 位 Windows
- `windows-386` - 32 位 Windows
- `windows-arm64` - ARM64 Windows

### FreeBSD

- `freebsd-amd64` / `freebsd-arm64` - pfSense/OPNsense 等

## 命令行参数

```
-name string
    账号名，通常是手机号

-passwd string
    账号密码

-host string
    登录服务器地址 (默认: 172.25.249.64)

-cache string
    缓存文件路径，用于加密存储密码和会话信息

-localip string
    绑定的本地 IP 地址

-logout
    登出当前会话

-index string
    用户索引（仅登出时需要，或从缓存读取）
```

## 安装脚本配置

编辑 `install.sh` 顶部配置：

```bash
ROUTER_IP="192.168.1.1"    # 路由器 IP
ROUTER_USER="root"          # SSH 用户名
PHONE="手机号"              # 电信账号
PASSWORD="密码"             # 电信密码
```

### 功能说明

安装后自动配置：

1. **开机启动** - 启动 60 秒后自动检查并登录
2. **定时检查** - 每小时检查网络连通性（ping 8.8.8.8）
3. **定时刷新** - 每天凌晨 5 点登出再登录，刷新租期
4. **日志记录** - 保存最后一次运行状态到 `/tmp/telecom_login.log`

### 查看运行状态

```bash
# 查看日志
ssh root@192.168.1.1 'cat /tmp/telecom_login.log'

# 手动运行检查
ssh root@192.168.1.1 '/data/check_network.sh'

# 查看定时任务
ssh root@192.168.1.1 'crontab -l'
```

## 注意事项

1. **网络检查间隔** - 掉线后需等到 DHCP 租期过期才能重新登录
2. **密码安全** - 缓存文件包含加密后的密码，注意保护
3. **路由器兼容性** - 主要针对 OpenWRT 测试，其他系统可能需要调整
4. **登录地址** - 默认 `172.25.249.64`，如变更请使用 `-host` 参数

## 常见问题

### Q: 如何确定我的路由器架构？

```bash
uname -m
```

- `armv7l` → linux-armv7
- `mips` → linux-mips 或 linux-mipsle
- `aarch64` → linux-arm64
- `x86_64` → linux-amd64

### Q: 程序运行失败怎么办？

1. 检查网络连接
2. 确认登录地址是否正确
3. 查看日志：`cat /tmp/telecom_login.log`
4. 手动运行测试：`/data/login -name 账号 -passwd 密码`

### Q: 如何卸载？

```bash
ssh root@路由器IP
rm -f /data/login /data/check_network.sh /data/refresh_lease.sh /data/login_cache.json
crontab -l | grep -v "check_network\|refresh_lease" | crontab -
sed -i '/check_network.sh/d' /etc/rc.local
```
