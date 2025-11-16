#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

log "构建版本: $(cat /VERSION 2>/dev/null || echo unknown)"
WARP_VER="$(dpkg-query -W -f='${Version}\n' cloudflare-warp 2>/dev/null | sed 's/-.*$//' || true)"
[ -z "$WARP_VER" ] && WARP_VER="unknown"
log "WARP 版本: ${WARP_VER}"

log "启动 warp-svc 守护进程..."
warp-svc >> /tmp/warp-svc.log 2>&1 &
WARP_SVC_PID=$!
sleep 2

if ! kill -0 "$WARP_SVC_PID" 2>/dev/null; then
    log "warp-svc 进程启动失败或已退出"
    if [ -f /tmp/warp-svc.log ]; then
        log "warp-svc 日志最后 50 行："
        tail -n 50 /tmp/warp-svc.log || true
    else
        log "未找到 /tmp/warp-svc.log"
    fi
    exit 3
fi

log "warp-svc 进程 PID: ${WARP_SVC_PID}"

WARP_STATUS=$(warp-cli --accept-tos registration show 2>&1 || true)
log "当前 registration 状态输出："
printf '%s\n' "$WARP_STATUS"

ACCOUNT_TYPE=$(echo "$WARP_STATUS" | awk -F ': ' '/Account type:/ {print $2}' | xargs)
if [ -n "$ACCOUNT_TYPE" ]; then
    log "$ACCOUNT_TYPE 已登陆"
    if [ -n "$WARP_LICENSE_KEY" ] && [ "$ACCOUNT_TYPE" != "Team" ]; then
        CUR_LICENSE=$(echo "$WARP_STATUS" | awk -F ': ' '/License:/ {print $2}' | xargs)
        if [ "$CUR_LICENSE" != "$WARP_LICENSE_KEY" ]; then
            log "正在绑定新 License"
            warp-cli --accept-tos registration license "$WARP_LICENSE_KEY" 1>/dev/null
        else
            log "License 已绑定"
        fi
    fi
else
    log "未注册, 开始自动注册..."

    if [ -n "$WARP_TOKEN_URL" ]; then
        log "使用 Team Token 进行注册"
        warp-cli --accept-tos registration token "$WARP_TOKEN_URL" 1>/dev/null
    elif [ -n "$WARP_LICENSE_KEY" ]; then
        log "使用 License 注册"
        if ! warp-cli --accept-tos registration new 1>/dev/null; then
            log "注册失败, 存在旧注册信息, 尝试删除重试..."
            warp-cli --accept-tos registration delete 1>/dev/null || true
            warp-cli --accept-tos registration new 1>/dev/null
        fi
        warp-cli --accept-tos registration license "$WARP_LICENSE_KEY" 1>/dev/null
    else
        log "使用免费账户注册"
        if ! warp-cli --accept-tos registration new 1>/dev/null; then
            log "注册失败, 存在旧注册信息, 尝试删除重试..."
            warp-cli --accept-tos registration delete 1>/dev/null || true
            warp-cli --accept-tos registration new 1>/dev/null
        fi
        log "WARP_LICENSE_KEY 未设置, 使用免费账户"
    fi

    for i in {1..30}; do
        WARP_STATUS_READY=$(warp-cli --accept-tos registration show 2>&1 || true)
        ACCOUNT_TYPE_READY=$(echo "$WARP_STATUS_READY" | awk -F ': ' '/Account type:/ {print $2}' | xargs)
        if [ -n "$ACCOUNT_TYPE_READY" ]; then
            log "注册信息 ${ACCOUNT_TYPE_READY}"
            ACCOUNT_TYPE="$ACCOUNT_TYPE_READY"
            break
        fi
        sleep 1
    done
    if [ -z "$ACCOUNT_TYPE" ]; then
        log "WARP 注册信息未生效, 启动失败"
        if [ -f /tmp/warp-svc.log ]; then
            log "warp-svc 日志最后 50 行："
            tail -n 50 /tmp/warp-svc.log || true
        fi
        pkill -f warp-svc || true
        exit 4
    fi
fi

log "WARP 等待连接建立..."
warp-cli --accept-tos connect 1>/dev/null || log "warp-cli connect 调用返回非零, 继续检查状态"

for i in {1..15}; do
    STATUS_OUT="$(LC_ALL=C warp-cli --accept-tos status 2>&1 || true)"
    echo "$STATUS_OUT" | grep -q "Status update: Connected" && break
    log "当前状态轮询第 ${i} 次："
    printf '%s\n' "$STATUS_OUT"
    sleep 1
    if [ "$i" -eq 15 ]; then
        log "WARP 连接超时, 启动失败"
        if [ -f /tmp/warp-svc.log ]; then
            log "warp-svc 日志最后 50 行："
            tail -n 50 /tmp/warp-svc.log || true
        fi
        pkill -f warp-svc || true
        exit 5
    fi
done
log "WARP 连接成功"

log "SOCKS5 代理服务启动, 监听端口: ${SOCKS5_PROXY_PORT}"
cat >/tmp/danted.conf <<EOF
logoutput: /dev/null
internal: 0.0.0.0 port = ${SOCKS5_PROXY_PORT}
external: CloudflareWARP

user.privileged: root
user.unprivileged: nobody

socksmethod: none

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF
/usr/sbin/danted -f /tmp/danted.conf >/dev/null 2>&1 &

log "HTTP 代理服务启动, 监听端口: ${HTTP_PROXY_PORT}"
cat >/tmp/privoxy.conf <<EOF
listen-address 0.0.0.0:${HTTP_PROXY_PORT}
EOF
/usr/sbin/privoxy --no-daemon /tmp/privoxy.conf >/dev/null 2>&1 &

log "进入守护状态, 等待容器生命周期结束"
tail -f /dev/null