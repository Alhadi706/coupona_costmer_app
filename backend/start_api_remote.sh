#!/usr/bin/env bash
set -euo pipefail

DBPASS=$(grep '^POSTGRES_PASSWORD=' /opt/projects/kupuna/docker/.env | cut -d= -f2-)
cd /opt/projects/kupuna/source/backend

cat > .env <<EOF
PORT=3005
JWT_SECRET=kupuna_prod_$(date +%s)
PGHOST=127.0.0.1
PGPORT=5434
PGUSER=kupuna_user
PGPASSWORD=${DBPASS}
PGDATABASE=kupuna_db
EOF

npm install --omit=dev
pkill -f 'node server.js' || true
nohup node server.js > /opt/projects/kupuna/logs/company_api.log 2>&1 &
sleep 2

ss -ltnp | grep ':3005' || true
tail -n 20 /opt/projects/kupuna/logs/company_api.log
