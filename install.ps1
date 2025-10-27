# 电信自动登录安装脚本 (Windows PowerShell)
# 适用于小米路由器 OpenWRT 系统

# 配置参数
$ROUTER_IP = "192.168.1.1"
$ROUTER_USER = "root"
$PHONE = "你的手机号"
$PASSWORD = "你的密码"
$REMOTE_DIR = "/data"
$LOCAL_BIN = ".\login-arm-cortex-a7"

Write-Host "电信自动登录安装脚本 (Windows)" -ForegroundColor Cyan
Write-Host ""

# 检查本地二进制文件
if (-not (Test-Path $LOCAL_BIN)) {
    Write-Host "错误: 找不到 $LOCAL_BIN" -ForegroundColor Red
    exit 1
}

Write-Host "连接到路由器 $ROUTER_IP (需要输入密码)"
Write-Host ""

# SSH/SCP 基础配置
$SSH_HOST = "${ROUTER_USER}@${ROUTER_IP}"

# 创建临时目录
$TempDir = "$env:TEMP\telecom_login"
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# 创建检查脚本
$CheckScript = @"
#!/bin/sh
LOG_FILE="/tmp/telecom_login.log"
LOGIN_BIN="/data/login"
PHONE="$PHONE"
PASSWORD="$PASSWORD"

log() {
    echo "[\`$(date '+%Y-%m-%d %H:%M:%S')] \`$1" > "\`$LOG_FILE"
}

ping -c 2 -W 4 8.8.8.8 > /dev/null 2>&1
if [ \`$? -eq 0 ]; then
    log "网络正常"
    exit 0
else
    log "网络不通，尝试登录" 
    if \`$LOGIN_BIN -name \`$PHONE -passwd \`$PASSWORD > /dev/null 2>&1; then
        log "登录成功"
    else
        log "登录失败"
    fi
fi
"@

Set-Content -Path "$TempDir\check_network.sh" -Value $CheckScript -NoNewline

# 创建刷新租期脚本
$RefreshScript = @"
#!/bin/sh
LOG_FILE="/tmp/telecom_login.log"
LOGIN_BIN="/data/login"
CACHE_FILE="/data/login_cache.json"
PHONE="$PHONE"
PASSWORD="$PASSWORD"

log() {
    echo "[\`$(date '+%Y-%m-%d %H:%M:%S')] \`$1" > "\`$LOG_FILE"
}

log "开始刷新租期"

if [ -f "\`$CACHE_FILE" ]; then
    \`$LOGIN_BIN -cache "\`$CACHE_FILE" -logout > /dev/null 2>&1
    sleep 2
fi

if \`$LOGIN_BIN -name \`$PHONE -passwd \`$PASSWORD -cache "\`$CACHE_FILE" > /dev/null 2>&1; then
    log "刷新成功"
else
    log "刷新失败"
fi
"@

Set-Content -Path "$TempDir\refresh_lease.sh" -Value $RefreshScript -NoNewline

Write-Host "清理旧安装..."

# 清理旧安装
$CleanupCommands = @"
rm -f /data/login /data/check_network.sh /data/refresh_lease.sh /data/login_cache.json
crontab -l 2>/dev/null | grep -v "check_network.sh" | grep -v "refresh_lease.sh" | crontab - || true
if [ -f /etc/rc.local ]; then
    sed -i '/check_network.sh/d' /etc/rc.local
fi
echo "清理完成"
"@

$CleanupCommands | ssh -oHostKeyAlgorithms=+ssh-rsa $SSH_HOST "sh -s"

Write-Host "上传文件..."

# 上传文件
scp -O -oHostKeyAlgorithms=+ssh-rsa $LOCAL_BIN ${SSH_HOST}:${REMOTE_DIR}/login
scp -O -oHostKeyAlgorithms=+ssh-rsa "$TempDir\check_network.sh" ${SSH_HOST}:${REMOTE_DIR}/
scp -O -oHostKeyAlgorithms=+ssh-rsa "$TempDir\refresh_lease.sh" ${SSH_HOST}:${REMOTE_DIR}/

Write-Host "配置路由器..."

# 配置路由器
$ConfigCommands = @"
set -e

chmod +x /data/login /data/check_network.sh /data/refresh_lease.sh

# 配置 crontab
crontab -l 2>/dev/null > /tmp/crontab.new || touch /tmp/crontab.new
cat >> /tmp/crontab.new << 'CRON'
0 * * * * /data/check_network.sh
0 5 * * * /data/refresh_lease.sh
CRON
crontab /tmp/crontab.new

# 配置开机自启
if ! grep -q "check_network.sh" /etc/rc.local 2>/dev/null; then
    if [ ! -f /etc/rc.local ]; then
        cat > /etc/rc.local << 'RCLOCAL'
#!/bin/sh
sleep 60
/data/check_network.sh &
exit 0
RCLOCAL
        chmod +x /etc/rc.local
    else
        sed -i '/^exit 0/i sleep 60' /etc/rc.local
        sed -i '/^exit 0/i /data/check_network.sh &' /etc/rc.local
    fi
fi

echo "配置完成"
"@

$ConfigCommands | ssh -oHostKeyAlgorithms=+ssh-rsa $SSH_HOST "sh -s"

Write-Host "运行网络检查..."
ssh -oHostKeyAlgorithms=+ssh-rsa $SSH_HOST "/data/check_network.sh" 2>$null

Write-Host ""
Write-Host "安装完成" -ForegroundColor Green
Write-Host ""
Write-Host "配置信息:"
Write-Host "  登录程序: /data/login"
Write-Host "  日志文件: /tmp/telecom_login.log"
Write-Host ""
Write-Host "定时任务:"
Write-Host "  每小时检查网络"
Write-Host "  每天 05:00 刷新租期"
Write-Host "  开机 60 秒后自动登录"
Write-Host ""
Write-Host "查看日志: ssh -oHostKeyAlgorithms=+ssh-rsa $SSH_HOST 'cat /tmp/telecom_login.log'"

# 清理临时文件
Remove-Item -Path $TempDir -Recurse -Force

