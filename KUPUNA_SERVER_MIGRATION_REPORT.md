# KUPUNA SERVER MIGRATION REPORT

Date: 2026-07-21
Executor: GitHub Copilot
Target Server: 154.12.117.175
Target User: alhadi
Target Directory: /opt/projects/kupuna

## 1) Files transferred
- Repository cloned to:
  - /opt/projects/kupuna/source
- Source repository:
  - https://github.com/Alhadi706/coupona_costmer_app.git
- Verification:
  - git repository initialized in target folder
  - branch detected: master
  - project files visible under /opt/projects/kupuna/source

## 2) Services installed
Detected on server (already available):
- Docker version 29.1.4
- Docker Compose version v5.0.1

Services started for Kupuna isolated environment:
- kupuna_postgres (postgres:16-alpine)
- kupuna_redis (redis:7-alpine)
- kupuna_app (nginx:1.27-alpine) serving Kupuna Flutter Web build on port 3002

## 3) Configuration created
Created isolated directory structure:
- /opt/projects/kupuna/source
- /opt/projects/kupuna/database
- /opt/projects/kupuna/storage
- /opt/projects/kupuna/backups
- /opt/projects/kupuna/docker
- /opt/projects/kupuna/logs
- /opt/projects/kupuna/documentation

Permissions applied:
- owner: alhadi:alhadi
- mode: 750 (root and subfolders)

Docker configuration files created:
- /opt/projects/kupuna/docker/.env.example
- /opt/projects/kupuna/docker/docker-compose.yml
- /opt/projects/kupuna/docker/README.md
- /opt/projects/kupuna/docker/.env (generated from example)

Isolation choices:
- Docker network: kupuna_net
- Runtime endpoint port: 3002 (real Kupuna app runtime)
- PostgreSQL port: 5434
- Redis port: 6380

## 4) Problems found
- Git push from local machine to GitHub via SSH failed due to missing GitHub SSH key authorization (publickey denied).
- SSH config file on Windows had BOM at line 1 causing "Bad configuration option"; fixed by rewriting as ASCII.
- One PowerShell quoting error occurred when running remote shell commands containing $(ls -A); fixed by using safe scripted remote execution.

## 5) Verification results
Connectivity and host identity:
- SSH connection successful to 154.12.117.175 as alhadi.

Folder verification:
- /opt/projects/kupuna exists with all required subfolders.

Compose validation:
- docker compose config rendering succeeded (COMPOSE_VALID).

Runtime status:
- /kupuna_postgres running=true health=healthy
- /kupuna_redis running=true health=healthy
- /kupuna_app running=true health=healthy

Port verification:
- 3002 listening (Kupuna app runtime)
- 5434 listening (postgres)
- 6380 listening (redis)

HTTP verification:
- http://127.0.0.1:3002 returns HTTP/1.1 200 OK

Deployment method for app runtime:
- Local prebuilt Flutter Web artifacts from build/web were transferred to:
  - /opt/projects/kupuna/source/web_deploy
- Container kupuna_app serves these files through isolated Nginx.

Network verification:
- kupuna_net created and in use by Kupuna containers.

## 6) Final isolation confirmation
Confirmed:
- No files from other projects were placed under /opt/projects/kupuna.
- Existing project path /home/alhadi/digital-dashboard was not modified.
- Kupuna services use separate ports and separate Docker network.
- Kupuna directories for logs, backups, storage, and database are isolated.

## 7) Pending items (for full production cutover)
- Replace all project secrets with secure production values (environment management policy).
- Configure firewall restrictions for only required ports.
- Implement scheduled backups and restore test procedure.
- Optional hardening: move SSH authentication from password to key-only.
