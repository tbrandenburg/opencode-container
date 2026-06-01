FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm config set strict-ssl false \
    && npm install -g opencode-ai@latest \
    && npm config set strict-ssl true

ARG TARGETARCH=amd64
ARG GH_VERSION=2.70.0

RUN case "$TARGETARCH" in \
      amd64|arm64) ;; \
      *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -fsSLk "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" \
      -o /tmp/gh.tar.gz && \
    tar xzf /tmp/gh.tar.gz -C /tmp && \
    mv /tmp/gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh /usr/local/bin/ && \
    rm -rf /tmp/gh*

ENV GIT_SSL_NO_VERIFY=true

COPY generic-worker.sh /usr/local/bin/generic-worker.sh
RUN chmod +x /usr/local/bin/generic-worker.sh

ENTRYPOINT ["/usr/local/bin/generic-worker.sh"]
