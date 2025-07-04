FROM ubuntu:24.04

COPY VERSION /VERSION

ENV WARP_PROXY_PORT=1080
ENV WARP_LICENSE_KEY=
ENV TZ=Asia/Seoul

EXPOSE ${WARP_PROXY_PORT}

RUN apt-get update && \
    apt-get install -y curl lsb-release gnupg socat dnsutils netcat-openbsd tzdata && \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]