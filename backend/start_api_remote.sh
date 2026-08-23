#!/usr/bin/env bash
set -euo pipefail

DBPASS=$(grep '^POSTGRES_PASSWORD=' /opt/projects/kupuna/docker/.env | cut -d= -f2-)
GEMINI_API_KEY=$(grep '^GEMINI_API_KEY=' /opt/projects/kupuna/source/backend/.env 2>/dev/null | cut -d= -f2- || true)
GEMINI_MODEL=$(grep '^GEMINI_MODEL=' /opt/projects/kupuna/source/backend/.env 2>/dev/null | cut -d= -f2- || true)
cd /opt/projects/kupuna/source/backend

cat > .env <<EOF
PORT=3005
JWT_SECRET=kupuna_prod_$(date +%s)
PGHOST=127.0.0.1
PGPORT=5434
PGUSER=kupuna_user
PGPASSWORD=${DBPASS}
PGDATABASE=kupuna_db
GEMINI_API_KEY=${GEMINI_API_KEY}
GEMINI_MODEL=${GEMINI_MODEL:-gemini-1.5-flash}
EOF

npm install --omit=dev
pkill -f 'node server.js' || true
nohup node server.js > /opt/projects/kupuna/logs/company_api.log 2>&1 &
sleep 2

ss -ltnp | grep ':3005' || true
tail -n 20 /opt/projects/kupuna/logs/company_api.log
