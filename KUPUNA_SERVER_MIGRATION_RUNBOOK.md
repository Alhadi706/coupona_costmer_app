# KUPUNA SERVER MIGRATION RUNBOOK

## Status
- Execution owner: GitHub Copilot
- Date: 2026-07-21
- Objective: Prepare isolated Kupuna server environment on private host with zero overlap with existing projects.

## Received Access Parameters
- SERVER_IP: `154.12.117.175`
- SSH_USER: `alhadi`
- SSH_METHOD: `password`
- TARGET_DIRECTORY: `/opt/projects/kupuna`

## Isolation Policy (Mandatory)
- Dedicated project root: `/opt/projects/kupuna`
- No shared files with other projects
- No use of existing project path: `/home/alhadi/digital-dashboard`
- No use of occupied port `3000`
- Separate env files, db, docker network, logs, and backups
- No shared database tables

## Provisioning Result (Executed)
The following directories were created on server:
- `/opt/projects/kupuna/source`
- `/opt/projects/kupuna/database`
- `/opt/projects/kupuna/storage`
- `/opt/projects/kupuna/backups`
- `/opt/projects/kupuna/docker`
- `/opt/projects/kupuna/logs`
- `/opt/projects/kupuna/documentation`

Permissions applied:
- Owner: `alhadi:alhadi`
- Root dir mode: `750`
- Subdirs mode: `750`

## Server Verification Snapshot
- Host: `digital-worker-1`
- OS: `Ubuntu 24.04.3 LTS`
- Kernel: `6.8.0-111-generic`
- Current user: `alhadi`

## Active Ports Found (Pre-migration)
- `22` SSH
- `80` HTTP
- `443` HTTPS
- `3000` existing app (occupied)
- `5433` local PostgreSQL
- `6379` local Redis
- `7860` other service

## Reserved Kupuna Ports (No conflict)
- App: `3002`
- PostgreSQL (if local instance for Kupuna): `5434`
- Redis (if needed): `6380`

## Migration Checklist
1. Confirm Kupuna Git repository URL and branch policy.
2. Backup source and data before transfer.
3. Transfer source into `/opt/projects/kupuna/source`.
4. Validate integrity with checksums.
5. Create isolated `.env` files under Kupuna scope only.
6. Build dedicated Docker Compose stack in `/opt/projects/kupuna/docker`.
7. Bind only approved Kupuna ports.
8. Route logs to `/opt/projects/kupuna/logs`.
9. Configure backups to `/opt/projects/kupuna/backups`.
10. Run build/health checks and produce final migration report.

## Command Set (For Next Execution Phase)
Use only after repository URL is provided.

```bash
# Connect
ssh alhadi@154.12.117.175

# Verify structure
ls -la /opt/projects/kupuna
find /opt/projects/kupuna -maxdepth 2 -type d | sort

# Prepare source checkout (replace REPO_URL)
cd /opt/projects/kupuna/source
git init
git remote add origin REPO_URL
git fetch --all
git checkout -b main origin/main

# Create checksum manifest (local source side before transfer)
# sha256sum -b <files> > checksums.sha256

# Verify ports prior to startup
ss -tuln | egrep ':22|:80|:443|:3000|:5433|:6379|:7860|:3002|:5434|:6380'
```

## Security Requirements
- Use SSH key auth in production phase (recommended upgrade from password login).
- Keep firewall default deny inbound except required ports.
- Restrict folder access to owner/group only.
- Store secrets outside git-tracked files.
- Do not place any non-Kupuna project files under `/opt/projects/kupuna`.

## KUPUNA SERVER MIGRATION REPORT TEMPLATE

### 1) Files transferred
- List of transferred directories/files
- Total file count
- Checksum verification result

### 2) Services installed
- Docker/Docker Compose status
- Database service status
- Any additional runtime dependencies

### 3) Configuration created
- Env files created (names only, no secret values)
- Docker compose files and network names
- Port mapping
- Backup schedule

### 4) Problems found
- Any permission, network, dependency, or build issues
- Resolution applied

### 5) Verification results
- Build result
- Service health checks
- Port checks
- Log checks
- Backup test result

### 6) Final isolation confirmation
- Confirmed no shared tables
- Confirmed no shared configuration
- Confirmed no shared project files inside Kupuna root
