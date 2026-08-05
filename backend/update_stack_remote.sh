#!/usr/bin/env bash
set -euo pipefail

cat > /opt/projects/kupuna/docker/nginx/default.conf <<'EOF'
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  location /api/ {
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://kupuna_api:3005/api/;
  }

  location / {
    try_files $uri $uri/ /index.html;
  }

  location = /health {
    add_header Content-Type text/plain;
    return 200 'ok';
  }
}
EOF

cat > /opt/projects/kupuna/docker/docker-compose.yml <<'EOF'
name: kupuna_stack

services:
  kupuna_postgres:
    image: postgres:16-alpine
    container_name: kupuna_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-kupuna_db}
      POSTGRES_USER: ${POSTGRES_USER:-kupuna_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      TZ: ${TZ:-UTC}
    ports:
      - "${POSTGRES_PORT:-5434}:5432"
    volumes:
      - /opt/projects/kupuna/database/postgres:/var/lib/postgresql/data
      - /opt/projects/kupuna/logs/postgres:/var/log/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-kupuna_user} -d ${POSTGRES_DB:-kupuna_db}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - kupuna_net

  kupuna_redis:
    image: redis:7-alpine
    container_name: kupuna_redis
    restart: unless-stopped
    command: ["redis-server", "--appendonly", "yes"]
    ports:
      - "${REDIS_PORT:-6380}:6379"
    volumes:
      - /opt/projects/kupuna/storage/redis:/data
      - /opt/projects/kupuna/logs/redis:/var/log/redis
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - kupuna_net

  kupuna_api:
    image: node:20-alpine
    container_name: kupuna_api
    restart: unless-stopped
    working_dir: /app
    command: sh -c "npm install --omit=dev && node server.js"
    env_file:
      - /opt/projects/kupuna/source/backend/.env
    volumes:
      - /opt/projects/kupuna/source/backend:/app
      - /opt/projects/kupuna/logs:/opt/projects/kupuna/logs
    depends_on:
      - kupuna_postgres
    networks:
      - kupuna_net

  kupuna_app:
    image: nginx:1.27-alpine
    container_name: kupuna_app
    restart: unless-stopped
    ports:
      - "${APP_PORT:-3002}:80"
    volumes:
      - /opt/projects/kupuna/source/web_deploy:/usr/share/nginx/html:ro
      - /opt/projects/kupuna/docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - /opt/projects/kupuna/logs/nginx:/var/log/nginx
    depends_on:
      - kupuna_api
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1/health >/dev/null 2>&1 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 6
    networks:
      - kupuna_net

networks:
  kupuna_net:
    name: kupuna_net
    driver: bridge
EOF

cd /opt/projects/kupuna/docker
docker compose up -d
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
