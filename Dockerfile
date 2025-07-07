FROM ubuntu:24.04

COPY VERSION /VERSION

ENV WARP_PROXY_PORT=1080
ENV TZ=Asia/Seoul
ENV WARP_LICENSE_KEY=
ENV WARP_TOKEN_URL=

RUN apt-get update && \
    apt-get install -y curl lsb-release netcat-openbsd gnupg iproute2 iptables tzdata dante-server && \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY danted.conf /etc/danted.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]