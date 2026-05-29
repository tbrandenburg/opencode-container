FROM node:22-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest

RUN mkdir /project
WORKDIR /project

RUN git config --global user.email "dev@opencode.local" && \
    git config --global user.name "OpenCode Dev" && \
    git init && echo "# OpenCode Server" > README.md && git add README.md && git commit -m "init"

ENV OPENCODE_SERVER_PASSWORD=changeme
EXPOSE 4096

CMD ["opencode", "serve", "--port", "4096", "--hostname", "0.0.0.0"]
