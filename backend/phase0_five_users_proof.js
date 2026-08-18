const fs = require('fs');
const path = require('path');

const apiBase = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3006/api';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const password = 'Test1234!';

const users = [
  { name: 'أحمد', alias: 'ahmed', gender: 'male', birth: '1994-04-12', lat: 32.8872, lng: 13.1913, role: 'customer' },
  { name: 'سارة', alias: 'sara', gender: 'female', birth: '1997-08-22', lat: 32.9012, lng: 13.2050, role: 'customer' },
  { name: 'خالد', alias: 'khaled', gender: 'prefer_not_to_say', birth: '1992-12-03', lat: 32.8750, lng: 13.1702, role: 'customer' },
  { name: 'فاطمة', alias: 'fatima', gender: 'female', birth: '1990-06-18', lat: 32.9120, lng: 13.2230, role: 'customer' },
  { name: 'يوسف', alias: 'yousef_admin', gender: 'male', birth: '1988-01-09', lat: 32.8890, lng: 13.1988, role: 'admin' },
];

async function api(pathName, method = 'GET', body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${apiBase}${pathName}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const txt = await res.text();
  let data;
  try {
    data = txt ? JSON.parse(txt) : {};
  } catch {
    data = { raw: txt };
  }

  if (!res.ok) {
    const err = new Error(`HTTP ${res.status} ${res.statusText}`);
    err.response = data;
    throw err;
  }
  return data;
}

async function run() {
  const lines = [];
  lines.push(`PHASE0_PROOF_START=${new Date().toISOString()}`);
  lines.push(`API_BASE=${apiBase}`);

  for (const u of users) {
    const email = `${u.alias}.${stamp}@kupuna.test`;
    lines.push(`USER=${u.name} EMAIL=${email} ROLE=${u.role}`);

    const signupPayload = {
      email,
      password,
      role: u.role,
      fullName: u.name,
      gender: u.gender,
      birthDate: u.birth,
      locationLat: u.lat,
      locationLng: u.lng,
    };

    let signup;
    try {
      signup = await api('/auth/signup', 'POST', signupPayload);
      lines.push(`SIGNUP_OK_${u.alias}=true`);
    } catch (e) {
      lines.push(`SIGNUP_OK_${u.alias}=false`);
      lines.push(`SIGNUP_ERR_${u.alias}=${JSON.stringify(e.response || e.message)}`);
      continue;
    }

    const login = await api('/auth/login', 'POST', { email, password });
    lines.push(`LOGIN_OK_${u.alias}=true`);

    const token = login.token;
    try {
      const loc = await api('/customer/location/me', 'GET', null, token);
      lines.push(`LOCATION_${u.alias}=${JSON.stringify(loc)}`);
    } catch (e) {
      lines.push(`LOCATION_${u.alias}=ERROR:${JSON.stringify(e.response || e.message)}`);
    }

    if (u.alias === 'ahmed') {
      try {
        const roles = await api('/roles/me', 'GET', null, token);
        lines.push(`AHMED_ROLES=${JSON.stringify(roles)}`);
      } catch (e) {
        lines.push(`AHMED_ROLES_ERROR=${JSON.stringify(e.response || e.message)}`);
      }
    }

    if (u.alias === 'yousef_admin') {
      lines.push(`ADMIN_READY_yousef=${signup.role === 'admin'}`);
    }
  }

  const outPath = path.join(__dirname, 'phase0_five_users_proof_output.txt');
  fs.writeFileSync(outPath, lines.join('\n'), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('PHASE0_SCRIPT_FAILED');
  console.error(e.message || e);
  if (e.response) console.error(JSON.stringify(e.response));
  process.exit(1);
});
