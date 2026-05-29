FROM node:22-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    socat \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest

RUN mkdir /project
WORKDIR /project

RUN git config --global user.email "dev@opencode.local" && \
    git config --global user.name "OpenCode Dev" && \
    git init && echo "# OpenCode ACP" > README.md && git add README.md && git commit -m "init"

EXPOSE 4097

CMD socat TCP-LISTEN:4097,reuseaddr,fork EXEC:"opencode acp",pty,stderr
