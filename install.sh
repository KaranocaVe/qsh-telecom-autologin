#!/bin/bash

set -e

# 配置参数
ROUTER_IP="192.168.1.1"
ROUTER_USER="root"
PHONE="你的手机号"
PASSWORD="你的密码"
REMOTE_DIR="/data"
LOCAL_BIN="./login-linux-armv7"

echo "电信自动登录安装脚本"
echo ""

# 检查本地二进制文件
if [ ! -f "$LOCAL_BIN" ]; then
    echo "错误: 找不到 $LOCAL_BIN"
    exit 1
fi

echo "连接到路由器 $ROUTER_IP (需要输入密码)"
echo ""

# SSH/SCP 命令
SSH_CMD="ssh -oHostKeyAlgorithms=+ssh-rsa $ROUTER_USER@$ROUTER_IP"
SCP_CMD="scp -O -oHostKeyAlgorithms=+ssh-rsa"

# 创建检查脚本
cat > /tmp/check_network.sh << EOF
#!/bin/sh
LOG_FILE="/tmp/telecom_login.log"
LOGIN_BIN="/data/login"
PHONE="$PHONE"
PASSWORD="$PASSWORD"

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" > "\$LOG_FILE"
}

ping -c 2 -W 4 8.8.8.8 > /dev/null 2>&1
if [ \$? -eq 0 ]; then
    log "网络正常"
    exit 0
else
    log "网络不通，尝试登录"
    if \$LOGIN_BIN -name \$PHONE -passwd \$PASSWORD > /dev/null 2>&1; then
        log "登录成功"
    else
        log "登录失败"
    fi
fi
EOF

# 创建刷新租期脚本
cat > /tmp/refresh_lease.sh << EOF
#!/bin/sh
LOG_FILE="/tmp/telecom_login.log"
LOGIN_BIN="/data/login"
CACHE_FILE="/data/login_cache.json"
PHONE="$PHONE"
PASSWORD="$PASSWORD"

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" > "\$LOG_FILE"
}

log "开始刷新租期"

if [ -f "\$CACHE_FILE" ]; then
    \$LOGIN_BIN -cache "\$CACHE_FILE" -logout > /dev/null 2>&1
    sleep 2
fi

if \$LOGIN_BIN -name \$PHONE -passwd \$PASSWORD -cache "\$CACHE_FILE" > /dev/null 2>&1; then
    log "刷新成功"
else
    log "刷新失败"
fi
EOF

echo "清理旧安装..."
$SSH_CMD << 'CLEANUP'
# 删除旧文件
rm -f /data/login /data/check_network.sh /data/refresh_lease.sh /data/login_cache.json

# 清理 crontab
crontab -l 2>/dev/null | grep -v "check_network.sh" | grep -v "refresh_lease.sh" | crontab - || true

# 清理旧的 init.d 服务
if [ -f /etc/init.d/telecom_login ]; then
    /etc/init.d/telecom_login disable 2>/dev/null || true
    rm -f /etc/init.d/telecom_login
fi

echo "清理完成"
CLEANUP

echo "上传文件..."
$SCP_CMD "$LOCAL_BIN" "$ROUTER_USER@$ROUTER_IP:$REMOTE_DIR/login"
$SCP_CMD /tmp/check_network.sh "$ROUTER_USER@$ROUTER_IP:$REMOTE_DIR/"
$SCP_CMD /tmp/refresh_lease.sh "$ROUTER_USER@$ROUTER_IP:$REMOTE_DIR/"

echo "配置路由器..."

$SSH_CMD << 'REMOTE'
set -e

chmod +x /data/login /data/check_network.sh /data/refresh_lease.sh

# 配置 crontab
crontab -l 2>/dev/null > /tmp/crontab.new || touch /tmp/crontab.new
cat >> /tmp/crontab.new << 'CRON'
0 * * * * /data/check_network.sh
0 5 * * * /data/refresh_lease.sh
CRON
crontab /tmp/crontab.new

# 配置开机自启 - 使用 OpenWRT init.d 方式
cat > /etc/init.d/telecom_login << 'INITD'
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    # 等待网络稳定
    (sleep 30 && /data/check_network.sh) &
}

stop() {
    return 0
}

restart() {
    stop
    start
}
INITD

chmod +x /etc/init.d/telecom_login
/etc/init.d/telecom_login enable

echo "已配置开机自启动 (init.d)"

echo "配置完成"
REMOTE

echo "运行网络检查..."
$SSH_CMD "/data/check_network.sh" || true

echo ""
echo "安装完成"
echo ""
echo "配置信息:"
echo "  登录程序: /data/login"
echo "  日志文件: /tmp/telecom_login.log"
echo ""
echo "定时任务:"
echo "  每小时检查网络"
echo "  每天 05:00 刷新租期"
echo "  开机 60 秒后自动登录"
echo ""
echo "查看日志: ssh -oHostKeyAlgorithms=+ssh-rsa root@$ROUTER_IP 'tail -f /tmp/telecom_login.log'"

rm -f /tmp/check_network.sh /tmp/refresh_lease.sh