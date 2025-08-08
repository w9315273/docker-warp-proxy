# Docker WARP Proxy

### Cloudflare WARP + Socks5 一键容器代理 支持UDP
### 配置自动注册, 免费账号/LICENSE/ZeroTrust 3种模式
<br><br>

## ZeroTrust `TOKEN_URL` 获取方法
首先需要有 ZeroTrust 账号, 自行免费开通.<br>
浏览器最好使用无痕窗口转到以下地址, 进行账号登陆.
```
https://<你的ZeroTrust组织名>.cloudflareaccess.com/warp
```
登陆完成后, 有个 `Open Cloudflare WARP` 的蓝色按钮, 右键检查元素.<br>
把两个单引号‘ ’之间的
```
com.cloudflare.warp://超级长的一串字符复制下来
```
这就是 `TOKEN_URL`<br>
⚠️ `TOKEN_URL` 有时限, 尽快运行容器完成绑定. ⚠️
<br><br>

## docker cli

```bash
docker run -d \
  --name WARP \
  --restart always \
  -p 1080:1080/tcp \
  -p 1080:1080/udp \
  -v ./warp-data:/var/lib/cloudflare-warp \
  -e TZ=Asia/Seoul \
  -e WARP_PROXY_PORT=1080 \
  -e WARP_LICENSE_KEY= "" \    # 可选, 你的LICENSE_KEY \
  -e WARP_TOKEN_URL= "" \       # 可选, 获取到的TOKEN_URL \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  --sysctl net.ipv4.ip_forward=1 \
  ghcr.io/w9315273/docker-warp-proxy:latest
```

## docker compose
```yaml
services:
  WARP:
    image: ghcr.io/w9315273/docker-warp-proxy:latest
    container_name: WARP
    network_mode: bridge
    ports:
      - "1080:1080/tcp"
      - "1080:1080/udp"
    environment:
      TZ: "Asia/Seoul"
      WARP_PROXY_PORT: "1080"
      WARP_LICENSE_KEY: ""    # 可选, 你的LICENSE_KEY
      WARP_TOKEN_URL: ""      # 可选, 获取到的TOKEN_URL
    volumes:
      - ./WARP:/var/lib/cloudflare-warp
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    sysctls:
      - net.ipv4.ip_forward=1
    restart: always
```

## 测试
```bash
curl --socks5-hostname 127.0.0.1:1080 https://www.cloudflare.com/cdn-cgi/trace/
```
返回字段中 `warp=on` 或 `warp=plus` 表示成功