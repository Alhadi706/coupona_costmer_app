#!/usr/bin/env bash
set -euo pipefail
email="phase1_user_$(date +%Y%m%d%H%M%S)@example.com"
pass="Pass12345!"
signup=$(curl -s -X POST http://127.0.0.1:3005/api/auth/signup -H "Content-Type: application/json" -d "{\"email\":\"$email\",\"password\":\"$pass\",\"role\":\"customer\"}")
login=$(curl -s -X POST http://127.0.0.1:3005/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$email\",\"password\":\"$pass\"}")
token=$(echo "$login" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
roles=$(curl -s -H "Authorization: Bearer $token" http://127.0.0.1:3005/api/roles/me)
userId=$(echo "$signup" | sed -n 's/.*"userId":"\([^"]*\)".*/\1/p')
echo "SIGNUP=$signup"
echo "LOGIN=$login"
echo "ROLES=$roles"
echo "USER_ID=$userId"
docker exec kupuna_postgres psql -U kupuna_user -d kupuna_db -c "SELECT user_id FROM customer_profiles WHERE user_id = '$userId' LIMIT 1;"