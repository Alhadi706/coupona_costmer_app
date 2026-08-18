$ErrorActionPreference = 'Stop'

$apiBase = if ($env:KUPUNA_API_BASE) { $env:KUPUNA_API_BASE } else { 'http://localhost:3006/api' }
$stamp = Get-Date -Format 'yyyyMMddHHmmssfff'

function Invoke-Api {
  param(
    [Parameter(Mandatory = $true)] [ValidateSet('GET', 'POST')] [string] $Method,
    [Parameter(Mandatory = $true)] [string] $Path,
    [Parameter()] $Body,
    [Parameter()] [hashtable] $Headers
  )

  $url = "$apiBase$Path"
  try {
    if ($Method -eq 'GET') {
      return Invoke-RestMethod -Method Get -Uri $url -Headers $Headers -UseBasicParsing
    }
    $json = if ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Depth 8 }
    return Invoke-RestMethod -Method Post -Uri $url -Headers $Headers -Body $json -ContentType 'application/json' -UseBasicParsing
  } catch {
    $message = $_.Exception.Message
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
      $message = "$message | $($_.ErrorDetails.Message)"
    }
    throw $message
  }
}

function Signup-And-Login {
  param(
    [string] $FullName,
    [string] $Email,
    [string] $Password,
    [string] $Gender,
    [string] $BirthDate,
    [double] $Lat,
    [double] $Lng,
    [string] $Role
  )

  $signupPayload = @{
    email = $Email
    password = $Password
    role = $Role
    fullName = $FullName
    gender = $Gender
    birthDate = $BirthDate
    locationLat = $Lat
    locationLng = $Lng
  }

  $signup = $null
  try {
    $signup = Invoke-Api -Method 'POST' -Path '/auth/signup' -Body $signupPayload
  } catch {
    if (-not ($_ -match 'signup_failed')) {
      throw
    }
  }

  $login = Invoke-Api -Method 'POST' -Path '/auth/login' -Body @{ email = $Email; password = $Password }
  return @{
    signup = $signup
    login = $login
  }
}

$pw = 'Test1234!'

$users = @(
  @{ name = 'أحمد'; alias = 'ahmed'; gender = 'male'; birth = '1994-04-12'; lat = 32.8872; lng = 13.1913; role = 'customer' },
  @{ name = 'سارة'; alias = 'sara'; gender = 'female'; birth = '1997-08-22'; lat = 32.9012; lng = 13.2050; role = 'customer' },
  @{ name = 'خالد'; alias = 'khaled'; gender = 'prefer_not_to_say'; birth = '1992-12-03'; lat = 32.8750; lng = 13.1702; role = 'customer' },
  @{ name = 'فاطمة'; alias = 'fatima'; gender = 'female'; birth = '1990-06-18'; lat = 32.9120; lng = 13.2230; role = 'customer' },
  @{ name = 'يوسف'; alias = 'yousef_admin'; gender = 'male'; birth = '1988-01-09'; lat = 32.8890; lng = 13.1988; role = 'admin' }
)

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("PHASE0_PROOF_START=$((Get-Date).ToString('s'))")
$report.Add("API_BASE=$apiBase")

foreach ($u in $users) {
  $email = "$($u.alias).$stamp@kupuna.test"
  $report.Add("USER=$($u.name) EMAIL=$email ROLE=$($u.role)")

  $auth = Signup-And-Login -FullName $u.name -Email $email -Password $pw -Gender $u.gender -BirthDate $u.birth -Lat $u.lat -Lng $u.lng -Role $u.role
  $token = $auth.login.token
  $headers = @{ Authorization = "Bearer $token" }

  if ($auth.signup) {
    $report.Add("SIGNUP_OK_$($u.alias)=true")
  } else {
    $report.Add("SIGNUP_OK_$($u.alias)=already_exists_or_conflict")
  }
  $report.Add("LOGIN_OK_$($u.alias)=true")

  $loc = Invoke-Api -Method 'GET' -Path '/customer/location/me' -Headers $headers
  $report.Add("LOCATION_$($u.alias)=$($loc | ConvertTo-Json -Compress)")

  if ($u.alias -eq 'ahmed') {
    $roles = Invoke-Api -Method 'GET' -Path '/roles/me' -Headers $headers
    $report.Add("AHMED_ROLES=$($roles | ConvertTo-Json -Compress)")
  }
}

$outFile = Join-Path $PSScriptRoot 'phase0_five_users_proof_output.txt'
$report | Set-Content -Path $outFile -Encoding utf8
Write-Output "WROTE=$outFile"
