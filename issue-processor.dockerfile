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

RUN mkdir /project
WORKDIR /project

RUN git config --global user.email "dev@opencode.local" && \
    git config --global user.name "OpenCode Dev" && \
    git init && echo "# Issue Processor" > README.md && \
    git add README.md && git commit -m "init"

COPY process-issues.sh /usr/local/bin/process-issues.sh
RUN chmod +x /usr/local/bin/process-issues.sh

CMD ["/usr/local/bin/process-issues.sh"]
