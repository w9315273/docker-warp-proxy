#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
log "构建版本: $(cat /VERSION 2>/dev/null || echo unknown)"
WARP_VER="$(dpkg-query -W -f='${Version}\n' cloudflare-warp 2>/dev/null | sed 's/-.*$//' || true)"
[ -z "$WARP_VER" ] && WARP_VER="unknown"
log "WARP 版本: ${WARP_VER}"

WARP_PROXY_PORT="${WARP_PROXY_PORT:-1080}"
WARP_LICENSE_KEY="${WARP_LICENSE_KEY:-}"
WARP_TOKEN_URL="${WARP_TOKEN_URL:-}"

warp-svc > /dev/null 2>&1 &
sleep 2

WARP_STATUS=$(warp-cli --accept-tos registration show 2>&1 || true)
ACCOUNT_TYPE=$(echo "$WARP_STATUS" | awk -F ': ' '/Account type:/ {print $2}' | xargs)
if [ -n "$ACCOUNT_TYPE" ]; then
    log "已登陆 $ACCOUNT_TYPE"
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
        log "Team 注册"
        warp-cli --accept-tos registration token "$WARP_TOKEN_URL" 1>/dev/null
    elif [ -n "$WARP_LICENSE_KEY" ]; then
        log "License 注册"
        if ! warp-cli --accept-tos registration new 1>/dev/null; then
            log "注册失败, 存在旧注册信息, 尝试删除重试..."
            warp-cli --accept-tos registration delete 1>/dev/null || true
            warp-cli --accept-tos registration new 1>/dev/null
        fi
        warp-cli --accept-tos registration license "$WARP_LICENSE_KEY" 1>/dev/null
    else
        log "免费注册流程"
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
            log "注册信息 $ACCOUNT_TYPE_READY"
            ACCOUNT_TYPE="$ACCOUNT_TYPE_READY"
            break
        fi
        sleep 1
    done
    if [ -z "$ACCOUNT_TYPE" ]; then
        log "warp 注册信息未生效, 启动失败"
        pkill -f warp-svc
        exit 4
    fi
fi

log "等待 WARP 连接建立..."
warp-cli --accept-tos connect 1>/dev/null
for i in {1..15}; do
    if LC_ALL=C warp-cli --accept-tos status | grep -q "Status update: Connected"; then
        break
    fi
    sleep 1
    if [ "$i" -eq 15 ]; then
        log "WARP 连接超时, 启动失败"
        pkill -f warp-svc
        exit 5
    fi
done
log "WARP 连接成功"

log "启动 SOCKS5 代理服务, 监听端口: ${WARP_PROXY_PORT}"
sed -i "s/{{WARP_PROXY_PORT}}/${WARP_PROXY_PORT}/g" /etc/danted.conf
/usr/sbin/danted -f /etc/danted.conf >/dev/null
