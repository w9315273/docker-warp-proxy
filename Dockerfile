FROM ubuntu:24.04

ENV SOCKS5_PROXY_PORT=1080
ENV HTTP_PROXY_PORT=1081
ENV WARP_LICENSE_KEY=
ENV WARP_TOKEN_URL=

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl gnupg ca-certificates && \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    . /etc/os-release; echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${VERSION_CODENAME:-$UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get purge -y --auto-remove curl gnupg && \
    apt-get update && \
    apt-get install -y --no-install-recommends dante-server privoxy cloudflare-warp && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 start.sh /start.sh
COPY VERSION /VERSION

ENTRYPOINT ["/start.sh"]
