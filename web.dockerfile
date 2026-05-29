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
    git init && echo "# OpenCode Web" > README.md && git add README.md && git commit -m "init"

ENV OPENCODE_SERVER_PASSWORD=changeme
EXPOSE 4098

CMD ["opencode", "web", "--port", "4098", "--hostname", "0.0.0.0"]
