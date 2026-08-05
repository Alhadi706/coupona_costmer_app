$base = 'http://154.12.117.175:3002/api'
function New-Email([string]$prefix) { "$prefix`_$(Get-Random)@kupuna.test" }
function Json($obj) { $obj | ConvertTo-Json -Depth 8 }
function Invoke-Json($Method, $Uri, $Body = $null, $Headers = $null) {
  if ($null -ne $Body) {
    return Invoke-RestMethod -Method $Method -Uri $Uri -ContentType 'application/json' -Body (Json $Body) -Headers $Headers
  }
  return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
}

$results = @()

for ($i = 1; $i -le 20; $i++) {
  $email = New-Email "customer$i"
  $password = 'Test1234!'
  try {
    $signup = Invoke-Json Post "$base/auth/signup" @{ email = $email; password = $password; role = 'customer' }
    $login = Invoke-Json Post "$base/auth/login" @{ email = $email; password = $password }
    $headers = @{ Authorization = "Bearer $($login.token)" }
    $offers = Invoke-Json Get "$base/offers" $null $headers
    $stores = Invoke-Json Get "$base/stores" $null $headers
    $groups = Invoke-Json Get "$base/groups" $null $headers
    $rewards = Invoke-Json Get "$base/rewards" $null $headers
    $counts = Invoke-Json Get "$base/stats/counts?userId=$($login.userId)" $null $headers
    $null = Invoke-Json Post "$base/wallet/ensure" @{} $headers
    $walletInfo = Invoke-Json Get "$base/wallet" $null $headers
    $pointsInfo = Invoke-Json Get "$base/wallet/points" $null $headers
    $ledger = Invoke-Json Get "$base/wallet/ledger?limit=5" $null $headers
    $results += [pscustomobject]@{
      role='customer'; idx=$i; email=$email; success=$true; offers=@($offers).Count; stores=@($stores).Count; groups=@($groups).Count; rewards=@($rewards).Count; counts=$counts; wallet=$walletInfo; points=$pointsInfo; ledger=@($ledger).Count
    }
  } catch {
    $results += [pscustomobject]@{ role='customer'; idx=$i; email=$email; success=$false; error=$_.Exception.Message }
  }
}

for ($i = 1; $i -le 10; $i++) {
  $email = New-Email "merchant$i"
  $password = 'Test1234!'
  try {
    $signup = Invoke-Json Post "$base/auth/signup" @{ email = $email; password = $password; role = 'merchant' }
    $login = Invoke-Json Post "$base/auth/login" @{ email = $email; password = $password }
    $headers = @{ Authorization = "Bearer $($login.token)" }
    $offerCreate = Invoke-Json Post "$base/offers" @{ offerType='discount'; category='restaurants'; titleType='merchant_offer'; discountValue='10'; description='merchant test offer'; location='Tripoli'; imageUrl='assets/img/map_sample.png'; createdAt=(Get-Date).ToUniversalTime().ToString('o'); lifecycleStatus='pending_review'; lifecycleUpdatedAt=(Get-Date).ToUniversalTime().ToString('o'); lifecycleReason='merchant_created' } $headers
    $offerId = $offerCreate.id
    $lifecycle = Invoke-Json Get "$base/offers/$offerId/lifecycle" $null $headers
    $null = Invoke-Json Post "$base/offers/$offerId/lifecycle/transition" @{ targetStatus='approved'; reason='merchant_approved' } $headers
    $null = Invoke-Json Post "$base/offers/$offerId/lifecycle/transition" @{ targetStatus='active'; reason='merchant_activated' } $headers
    $offers = Invoke-Json Get "$base/offers" $null $headers
    $results += [pscustomobject]@{ role='merchant'; idx=$i; email=$email; success=$true; createdOfferId=$offerId; lifecycle=$lifecycle.lifecycleStatus; offers=@($offers).Count }
  } catch {
    $results += [pscustomobject]@{ role='merchant'; idx=$i; email=$email; success=$false; error=$_.Exception.Message }
  }
}

for ($i = 1; $i -le 10; $i++) {
  $email = New-Email "agent$i"
  $password = 'Test1234!'
  try {
    $signup = Invoke-Json Post "$base/auth/signup" @{ email = $email; password = $password; role = 'agent' }
    $login = Invoke-Json Post "$base/auth/login" @{ email = $email; password = $password }
    $headers = @{ Authorization = "Bearer $($login.token)" }
    $users = Invoke-Json Get "$base/users" $null $headers
    $activity = Invoke-Json Get "$base/activity-logs?customerEmail=$email" $null $headers
    $counts = Invoke-Json Get "$base/stats/counts?userId=$($login.userId)" $null $headers
    $results += [pscustomobject]@{ role='agent'; idx=$i; email=$email; success=$true; users=@($users).Count; activity=@($activity).Count; counts=$counts }
  } catch {
    $results += [pscustomobject]@{ role='agent'; idx=$i; email=$email; success=$false; error=$_.Exception.Message }
  }
}

$summary = [ordered]@{
  total = $results.Count
  passed = @($results | Where-Object { $_.success }).Count
  failed = @($results | Where-Object { -not $_.success }).Count
  customersPassed = @($results | Where-Object { $_.role -eq 'customer' -and $_.success }).Count
  merchantsPassed = @($results | Where-Object { $_.role -eq 'merchant' -and $_.success }).Count
  agentsPassed = @($results | Where-Object { $_.role -eq 'agent' -and $_.success }).Count
  sample = @($results | Select-Object -First 5)
}
$summary | ConvertTo-Json -Depth 8
