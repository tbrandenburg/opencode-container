FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest

ARG TARGETARCH
RUN case "$TARGETARCH" in \
    amd64) ARCH=amd64;; \
    arm64) ARCH=arm64;; \
    *) ARCH=amd64;; \
    esac && \
    curl -fsSL "https://github.com/cli/cli/releases/download/v2.70.0/gh_2.70.0_linux_${ARCH}.tar.gz" -o /tmp/gh.tar.gz && \
    tar xzf /tmp/gh.tar.gz -C /tmp && \
    cp /tmp/gh_2.70.0_linux_${ARCH}/bin/gh /usr/local/bin/ && \
    rm -rf /tmp/gh*

COPY generic-worker.sh /usr/local/bin/generic-worker.sh
RUN chmod +x /usr/local/bin/generic-worker.sh

ENTRYPOINT ["/usr/local/bin/generic-worker.sh"]
