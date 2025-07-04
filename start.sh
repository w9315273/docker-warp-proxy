#!/bin/bash
set -e

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

log "===== Docker WARP PROXY VERSION: $(cat /VERSION 2>/dev/null || echo unknown) ====="

WARP_SOCKS_PORT=10101
WARP_PROXY_PORT=${WARP_PROXY_PORT:-1080}
WARP_LICENSE_KEY=${WARP_LICENSE_KEY:-}

warp-svc > /dev/null 2>&1 &
sleep 2

WARP_STATUS=$(warp-cli --accept-tos registration show 2>&1 || true)

if echo "$WARP_STATUS" | grep -q "Account type:"; then
    log "检测到已有 WARP 账号, 无需注册"
    if [ -n "$WARP_LICENSE_KEY" ]; then
        CUR_LICENSE=$(echo "$WARP_STATUS" | awk -F ': ' '/License:/ {print $2}' | xargs)
        if [ "$CUR_LICENSE" != "$WARP_LICENSE_KEY" ]; then
            log "检测到 License 与 WARP_LICENSE_KEY 不一致, 重新绑定 License"
            warp-cli --accept-tos registration license "$WARP_LICENSE_KEY" 1>/dev/null
        else
            log "License 已正确绑定, 跳过补绑"
        fi
    fi
else
    log "未检测到注册信息, 自动初始化..."
    if ! warp-cli --accept-tos registration new 1>/dev/null; then
        log "注册失败, 存在老注册, 尝试自动删除后重试..."
        warp-cli --accept-tos registration delete 1>/dev/null || true
        warp-cli --accept-tos registration new 1>/dev/null
    fi

    for i in {1..30}; do
        WARP_STATUS_READY=$(warp-cli --accept-tos registration show 2>&1 || true)
        if echo "$WARP_STATUS_READY" | grep -q "Account type:"; then
            log "注册信息生效"
            break
        fi
        log "等待 warp 注册信息生效: $i 秒"
        sleep 1
    done

    if ! echo "$WARP_STATUS_READY" | grep -q "Account type:"; then
        log "warp 注册信息一直未生效, 启动失败"
        pkill -f warp-svc
        exit 4
    fi

    if [ -n "$WARP_LICENSE_KEY" ]; then
        warp-cli --accept-tos registration license "$WARP_LICENSE_KEY" 1>/dev/null
    else
        log "WARP_LICENSE_KEY 未设置, 将使用免费账户"
    fi
fi

log "设置 WARP 为代理模式..."
warp-cli --accept-tos mode proxy 1>/dev/null

warp-cli --accept-tos proxy port $WARP_SOCKS_PORT 1>/dev/null

log "连接 WARP 服务..."
warp-cli --accept-tos connect 1>/dev/null

for i in {1..30}; do
    if nc -z 127.0.0.1 $WARP_SOCKS_PORT 2>/dev/null; then
        log "服务已启动"
        break
    fi
    log "等待服务启动: $i 秒"
    sleep 1
done

if ! nc -z 127.0.0.1 $WARP_SOCKS_PORT 2>/dev/null; then
    log "服务启动失败"
    exit 3
fi

log "SOCKS5 代理准备完成, 监听端口 $WARP_PROXY_PORT"

exec socat TCP-LISTEN:$WARP_PROXY_PORT,bind=0.0.0.0,fork TCP:127.0.0.1:$WARP_SOCKS_PORT