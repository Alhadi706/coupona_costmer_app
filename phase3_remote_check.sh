#!/usr/bin/env bash
set -u
cd /opt/projects/kupuna/source/backend
set -a
. ./.env
set +a
PORT=3006 node server.js > /tmp/kupuna_phase3_api.log 2>&1 &
PID=$!
sleep 2
echo "PID=$PID"

cust_email="phase3_customer_$(date +%Y%m%d%H%M%S)@example.com"
admin_email="phase3_admin_$(date +%Y%m%d%H%M%S)@example.com"
pass="Pass12345!"

cust_signup=$(curl -s -X POST http://127.0.0.1:3006/api/auth/signup -H "Content-Type: application/json" -d "{\"email\":\"$cust_email\",\"password\":\"$pass\",\"role\":\"customer\"}")
echo "CUST_SIGNUP=$cust_signup"

cust_login=$(curl -s -X POST http://127.0.0.1:3006/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$cust_email\",\"password\":\"$pass\"}")
echo "CUST_LOGIN=$cust_login"
cust_token=$(echo "$cust_login" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

merchant_req=$(curl -s -X POST http://127.0.0.1:3006/api/roles/merchant/request -H "Authorization: Bearer $cust_token" -H "Content-Type: application/json" -d "{\"businessName\":\"Demo Merchant\",\"commercialRegistration\":\"CR-123\",\"planType\":\"basic\"}")
echo "MERCHANT_REQUEST=$merchant_req"
request_id=$(echo "$merchant_req" | sed -n 's/.*"requestId":"\([^"]*\)".*/\1/p')

admin_signup=$(curl -s -X POST http://127.0.0.1:3006/api/auth/signup -H "Content-Type: application/json" -d "{\"email\":\"$admin_email\",\"password\":\"$pass\",\"role\":\"admin\"}")
echo "ADMIN_SIGNUP=$admin_signup"
admin_login=$(curl -s -X POST http://127.0.0.1:3006/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$admin_email\",\"password\":\"$pass\"}")
echo "ADMIN_LOGIN=$admin_login"
admin_token=$(echo "$admin_login" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

approve=$(curl -s -X POST http://127.0.0.1:3006/api/admin/role-requests/$request_id/approve -H "Authorization: Bearer $admin_token" -H "Content-Type: application/json" -d "{}")
echo "APPROVE=$approve"

roles_after=$(curl -s -H "Authorization: Bearer $cust_token" http://127.0.0.1:3006/api/roles/me)
echo "ROLES_AFTER_APPROVE=$roles_after"

cust_user_id=$(echo "$cust_signup" | sed -n 's/.*"userId":"\([^"]*\)".*/\1/p')
docker exec kupuna_postgres psql -U kupuna_user -d kupuna_db -c "UPDATE subscriptions SET trial_end_date = NOW() - INTERVAL '1 day' WHERE role_type='merchant' AND role_profile_id IN (SELECT id FROM merchant_profiles WHERE user_id='${cust_user_id}');"

transition=$(curl -s -X POST http://127.0.0.1:3006/api/subscriptions/run-transitions -H "Authorization: Bearer $admin_token" -H "Content-Type: application/json" -d "{}")
echo "TRANSITION_RUN=$transition"
roles_after_transition=$(curl -s -H "Authorization: Bearer $cust_token" http://127.0.0.1:3006/api/roles/me)
echo "ROLES_AFTER_TRANSITION=$roles_after_transition"

kill $PID || true