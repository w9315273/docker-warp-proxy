FROM ubuntu:24.04

COPY VERSION /VERSION

ENV WARP_PROXY_PORT=1080
ENV WARP_LICENSE_KEY=
ENV WARP_TOKEN_URL=

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl gnupg ca-certificates dante-server && \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    . /etc/os-release; echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${VERSION_CODENAME:-$UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    apt-get purge -y --auto-remove curl gnupg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY danted.conf /etc/danted.conf
COPY --chmod=755 start.sh /start.sh

ENTRYPOINT ["/start.sh"]
