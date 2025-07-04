# Docker Warp Proxy

#### Cloudflare WARP + Socat 一键容器代理  
#### 配置自动注册、支持Warp+授权码/免费账号

### docker cli

```bash
docker run -d \
  --name warp-proxy \
  --restart always \
  -p 1080:1080 \
  -e TZ=Asia/Seoul \
  -e WARP_PROXY_PORT=1080 \
  -e WARP_LICENSE_KEY= #你的WARP+key,可留空 \
  -v ./warp-data:/var/lib/cloudflare-warp \
  ghcr.io/w9315273/docker-warp-proxy:latest
```

### docker compose
```yaml
services:
  Proxy:
    image: ghcr.io/w9315273/docker-warp-proxy:latest
    container_name: Proxy
    network_mode: bridge
    ports:
      - "1080:1080"
    environment:
      TZ: 'Asia/Seoul'
      WARP_PROXY_PORT: '1080'
      WARP_LICENSE_KEY: '' #你的WARP+key,可留空
    volumes:
      - ./warp-data:/var/lib/cloudflare-warp
    restart: always
```

### 测试
```bash
curl --socks5-hostname 127.0.0.1:1080 https://www.cloudflare.com/cdn-cgi/trace/
```
返回字段中 `warp=on` 或 `warp=plus` 表示成功