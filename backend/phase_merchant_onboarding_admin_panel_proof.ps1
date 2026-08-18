$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

function Invoke-ApiRaw {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $false)]$Body,
    [Parameter(Mandatory = $false)][string]$Token
  )

  $base = 'http://127.0.0.1:3006/api'
  $uri = "$base$Path"
  $headers = @{}
  if ($Token) {
    $headers['Authorization'] = "Bearer $Token"
  }

  $payload = $null
  if ($null -ne $Body) {
    $payload = $Body | ConvertTo-Json -Depth 20 -Compress
  }

  try {
    $resp = Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers -ContentType 'application/json' -Body $payload -UseBasicParsing
    $json = $null
    try { $json = $resp.Content | ConvertFrom-Json } catch { }
    return [pscustomobject]@{
      Status = [int]$resp.StatusCode
      Body = [string]$resp.Content
      Json = $json
    }
  } catch {
    $status = 0
    $bodyText = ''
    try {
      $status = [int]$_.Exception.Response.StatusCode.value__
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $bodyText = $reader.ReadToEnd()
      $reader.Close()
    } catch {
      $bodyText = $_.Exception.Message
    }

    $json = $null
    try { $json = $bodyText | ConvertFrom-Json } catch { }

    return [pscustomobject]@{
      Status = $status
      Body = [string]$bodyText
      Json = $json
    }
  }
}

function Write-ListenerSnapshot {
  Write-Output 'LISTENER_SNAPSHOT_BEGIN'
  Get-NetTCPConnection -LocalPort 3006 -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, OwningProcess |
    Format-Table -AutoSize
  Write-Output 'LISTENER_SNAPSHOT_END'
}

function Write-DbSnapshots {
  param(
    [Parameter(Mandatory = $false)][string]$RequestId
  )

  $tmpJs = Join-Path $PSScriptRoot ('tmp_db_snapshot_' + [guid]::NewGuid().ToString('N') + '.js')

  $js = @'
const fs = require("fs");
const path = require("path");
const { Pool } = require("pg");

const envPath = path.join(process.cwd(), ".env");
if (fs.existsSync(envPath)) {
  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const raw of lines) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const idx = line.indexOf("=");
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim();
    if (!(key in process.env)) process.env[key] = value;
  }
}

(async () => {
  const pool = new Pool({
    host: process.env.PGHOST || "127.0.0.1",
    port: Number(process.env.PGPORT || "5432"),
    user: process.env.PGUSER || "postgres",
    password: process.env.PGPASSWORD || "",
    database: process.env.PGDATABASE || "postgres",
  });

  const rr = await pool.query(`
    SELECT status, COUNT(*)::int AS count
    FROM role_requests
    GROUP BY status
    ORDER BY status
  `);

  const pa = await pool.query(`
    SELECT status, COUNT(*)::int AS count
    FROM peer_ads
    GROUP BY status
    ORDER BY status
  `);

  console.log("ROLE_REQUEST_STATUS_VALUES=" + JSON.stringify(rr.rows));
  console.log("PEER_ADS_STATUS_VALUES=" + JSON.stringify(pa.rows));

  const reqId = process.argv[2];
  if (reqId) {
    const verify = await pool.query(`
      SELECT status, reviewed_at
      FROM role_requests
      WHERE id = $1
    `, [reqId]);
    console.log("DB_VERIFICATION=" + JSON.stringify(verify.rows));
  }

  await pool.end();
})().catch(async (err) => {
  console.error("DB_SNAPSHOT_ERROR=" + err.message);
  process.exit(1);
});
'@

  Set-Content -Path $tmpJs -Value $js -Encoding UTF8

  if ($RequestId) {
    node $tmpJs $RequestId
  } else {
    node $tmpJs
  }

  Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
}

$health = Invoke-ApiRaw -Method 'GET' -Path '/health'
if ($health.Status -ne 200) {
  Start-Process -FilePath 'node' -ArgumentList 'server.js' -WorkingDirectory $PSScriptRoot | Out-Null
  Start-Sleep -Seconds 3
}

Write-ListenerSnapshot
Write-DbSnapshots

$stamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfff')
$rand = Get-Random -Minimum 100000 -Maximum 999999
$adminEmail = "admin.$stamp.$rand@kupuna.test"
$merchantEmail = "merchant.$stamp.$rand@kupuna.test"
$pw = 'Test1234!'

$signupAdmin = Invoke-ApiRaw -Method 'POST' -Path '/auth/signup' -Body @{
  email = $adminEmail
  password = $pw
  role = 'admin'
}
Write-Output ("SIGNUP_ADMIN_STATUS=" + $signupAdmin.Status)
Write-Output ("SIGNUP_ADMIN_BODY=" + $signupAdmin.Body)

$signupMerchant = Invoke-ApiRaw -Method 'POST' -Path '/auth/signup' -Body @{
  email = $merchantEmail
  password = $pw
  role = 'customer'
}
Write-Output ("SIGNUP_MERCHANT_STATUS=" + $signupMerchant.Status)
Write-Output ("SIGNUP_MERCHANT_BODY=" + $signupMerchant.Body)

$loginAdmin = Invoke-ApiRaw -Method 'POST' -Path '/auth/login' -Body @{
  email = $adminEmail
  password = $pw
}
Write-Output ("LOGIN_ADMIN_STATUS=" + $loginAdmin.Status)
Write-Output ("LOGIN_ADMIN_BODY=" + $loginAdmin.Body)
$adminToken = [string]$loginAdmin.Json.token

$loginMerchant = Invoke-ApiRaw -Method 'POST' -Path '/auth/login' -Body @{
  email = $merchantEmail
  password = $pw
}
Write-Output ("LOGIN_MERCHANT_STATUS=" + $loginMerchant.Status)
Write-Output ("LOGIN_MERCHANT_BODY=" + $loginMerchant.Body)
$merchantToken = [string]$loginMerchant.Json.token

$missingFields = Invoke-ApiRaw -Method 'POST' -Path '/roles/merchant/request' -Body @{
  businessName = 'Proof Merchant Missing'
  commercialRegistration = "CR-MISS-$stamp"
  planType = 'basic'
} -Token $merchantToken
Write-Output ("MISSING_FIELDS_STATUS=" + $missingFields.Status)
Write-Output ("MISSING_FIELDS_BODY=" + $missingFields.Body)

$fullRequest = Invoke-ApiRaw -Method 'POST' -Path '/roles/merchant/request' -Body @{
  businessName = 'Proof Merchant Full'
  commercialRegistration = "CR-FULL-$stamp"
  planType = 'basic'
  phone = '0911111111'
  locationLat = 32.8872
  locationLng = 13.1913
  locationAddress = 'Tripoli Proof Address'
} -Token $merchantToken
Write-Output ("FULL_REQUEST_STATUS=" + $fullRequest.Status)
Write-Output ("FULL_REQUEST_BODY=" + $fullRequest.Body)
$requestId = [string]$fullRequest.Json.requestId

$pendingList = Invoke-ApiRaw -Method 'GET' -Path '/admin/role-requests?status=pending_admin_review' -Token $adminToken
Write-Output ("ADMIN_PENDING_LIST_STATUS=" + $pendingList.Status)
Write-Output ("ADMIN_PENDING_LIST_BODY=" + $pendingList.Body)

$approve = Invoke-ApiRaw -Method 'POST' -Path ("/admin/role-requests/" + $requestId + '/approve') -Body @{} -Token $adminToken
Write-Output ("APPROVE_STATUS=" + $approve.Status)
Write-Output ("APPROVE_BODY=" + $approve.Body)

$myRequests = Invoke-ApiRaw -Method 'GET' -Path '/roles/requests/me' -Token $merchantToken
Write-Output ("MY_REQUESTS_STATUS=" + $myRequests.Status)
Write-Output ("MY_REQUESTS_BODY=" + $myRequests.Body)

Write-DbSnapshots -RequestId $requestId
