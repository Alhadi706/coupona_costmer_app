#!/usr/bin/env bash
set -euo pipefail

DBPASS=$(grep '^POSTGRES_PASSWORD=' /opt/projects/kupuna/docker/.env | cut -d= -f2-)
cd /opt/projects/kupuna/source/backend

cat > .env <<EOF
PORT=3006
JWT_SECRET=kupuna_isolated_3006_$(date +%s)
PGHOST=127.0.0.1
PGPORT=5434
PGUSER=kupuna_user
PGPASSWORD=${DBPASS}
PGDATABASE=kupuna_db
EOF

npm install --omit=dev >/dev/null 2>&1

PIDS=$(ss -ltnp | awk '/:3006/{print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u)
if [ -n "${PIDS}" ]; then
  kill ${PIDS} || true
  sleep 1
fi

nohup node server.js > /opt/projects/kupuna/logs/company_api_3006.log 2>&1 &
sleep 3

ss -ltnp | grep ':3006' || true
tail -n 40 /opt/projects/kupuna/logs/company_api_3006.log || true
