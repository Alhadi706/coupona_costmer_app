$ErrorActionPreference = 'Stop'

$base = 'http://154.12.117.175:3002/api'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

function New-Email([string]$prefix) {
  return "$prefix.$timestamp.$(Get-Random -Maximum 999999)@kupuna.test"
}

function Json($obj) { $obj | ConvertTo-Json -Depth 20 }

function Invoke-Api([string]$Method, [string]$Path, $Body = $null, $Headers = $null) {
  $uri = "$base$Path"
  if ($null -ne $Body) {
    return Invoke-RestMethod -Method $Method -Uri $uri -ContentType 'application/json' -Body (Json $Body) -Headers $Headers
  }
  return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers
}

function Try-Api([string]$Method, [string]$Path, $Body, $Headers, [string]$Label) {
  try {
    $r = Invoke-Api $Method $Path $Body $Headers
    return @{ label = $Label; ok = $true; result = $r }
  } catch {
    $status = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $status = [int]$_.Exception.Response.StatusCode }
    return @{ label = $Label; ok = $false; status = $status; error = $_.Exception.Message }
  }
}

$log = New-Object System.Collections.Generic.List[object]

$health = Try-Api 'Get' '/health' $null $null 'health'
$log.Add($health)

$adminEmail = New-Email 'admin'
$merchantEmail = New-Email 'merchant'
$brandEmail = New-Email 'brand'
$customerEmail = New-Email 'customer'
$cashierEmail = New-Email 'cashier'
$password = 'Test1234!'

$log.Add((Try-Api 'Post' '/auth/signup' @{ email = $adminEmail; password = $password; role = 'admin' } $null 'signup_admin'))
$log.Add((Try-Api 'Post' '/auth/signup' @{ email = $merchantEmail; password = $password; role = 'customer' } $null 'signup_merchant'))
$log.Add((Try-Api 'Post' '/auth/signup' @{ email = $brandEmail; password = $password; role = 'customer' } $null 'signup_brand'))
$log.Add((Try-Api 'Post' '/auth/signup' @{ email = $customerEmail; password = $password; role = 'customer' } $null 'signup_customer'))
$log.Add((Try-Api 'Post' '/auth/signup' @{ email = $cashierEmail; password = $password; role = 'customer' } $null 'signup_cashier'))

$adminLogin = Invoke-Api 'Post' '/auth/login' @{ email = $adminEmail; password = $password }
$merchantLogin = Invoke-Api 'Post' '/auth/login' @{ email = $merchantEmail; password = $password }
$brandLogin = Invoke-Api 'Post' '/auth/login' @{ email = $brandEmail; password = $password }
$customerLogin = Invoke-Api 'Post' '/auth/login' @{ email = $customerEmail; password = $password }
$cashierLogin = Invoke-Api 'Post' '/auth/login' @{ email = $cashierEmail; password = $password }

$hAdmin = @{ Authorization = "Bearer $($adminLogin.token)" }
$hMerchant = @{ Authorization = "Bearer $($merchantLogin.token)" }
$hBrand = @{ Authorization = "Bearer $($brandLogin.token)" }
$hCustomer = @{ Authorization = "Bearer $($customerLogin.token)" }
$hCashier = @{ Authorization = "Bearer $($cashierLogin.token)" }

# Role activation
$merchantReq = Try-Api 'Post' '/roles/merchant/request' @{ businessName='E2E Merchant'; commercialRegistration='CR-E2E'; planType='monthly' } $hMerchant 'merchant_role_request'
$log.Add($merchantReq)
$brandReq = Try-Api 'Post' '/roles/brand/request' @{ businessName='E2E Brand'; commercialRegistration='CR-E2E-B'; planType='monthly' } $hBrand 'brand_role_request'
$log.Add($brandReq)
$log.Add((Try-Api 'Post' "/admin/role-requests/$($merchantReq.result.requestId)/approve" @{} $hAdmin 'approve_merchant'))
$log.Add((Try-Api 'Post' "/admin/role-requests/$($brandReq.result.requestId)/approve" @{} $hAdmin 'approve_brand'))

# Merchant dashboard endpoints
$log.Add((Try-Api 'Get' '/merchant/profile' $null $hMerchant 'merchant_profile_before'))
$log.Add((Try-Api 'Patch' '/merchant/settings/point-value' @{ pointValue = 10 } $hMerchant 'merchant_set_point_value'))
$merchantProfileAfter = Try-Api 'Get' '/merchant/profile' $null $hMerchant 'merchant_profile_after'
$log.Add($merchantProfileAfter)

$log.Add((Try-Api 'Get' '/brand/profile' $null $hBrand 'brand_profile_before'))
$log.Add((Try-Api 'Patch' '/brand/settings/point-value' @{ pointValue = 5 } $hBrand 'brand_set_point_value'))
$brandProfileAfter = Try-Api 'Get' '/brand/profile' $null $hBrand 'brand_profile_after'
$log.Add($brandProfileAfter)

$branch = Try-Api 'Post' '/merchant/branches' @{ name='E2E Branch'; address='Tripoli'; location='Tripoli' } $hMerchant 'create_branch'
$log.Add($branch)
$log.Add((Try-Api 'Get' '/merchant/branches' $null $hMerchant 'list_branches'))
$log.Add((Try-Api 'Post' "/merchant/branches/$($branch.result.id)/managers" @{ userId = $cashierLogin.userId } $hMerchant 'add_manager'))
$log.Add((Try-Api 'Patch' "/merchant/branches/$($branch.result.id)/managers/$($cashierLogin.userId)/permissions" @{ canAddCashiers = $true; canViewReports = $true; canManageGroup = $true; canEditPointValue = $true } $hMerchant 'update_manager_permissions'))
$log.Add((Try-Api 'Post' '/merchant/cashiers/bind' @{ cashierUserId = $cashierLogin.userId; branchId = $branch.result.id } $hMerchant 'bind_cashier'))
$log.Add((Try-Api 'Get' '/merchant/loyalty-health' $null $hMerchant 'loyalty_health'))
$log.Add((Try-Api 'Get' '/invoices/my' $null $hMerchant 'merchant_invoices_my'))

# Brand dashboard endpoints
$log.Add((Try-Api 'Post' '/brand/team-members' @{ userId = $merchantLogin.userId; canManageProducts = $true; canViewGeoDistribution = $true } $hBrand 'brand_add_team_member'))
$product = Try-Api 'Post' '/brand/products' @{ name='E2E Product'; imageUrl='https://example.test/p.png'; barcode='999888' } $hBrand 'brand_create_product'
$log.Add($product)

# Cashier grant-points (core points engine, uses merchant.point_value = 10)
$grant = Try-Api 'Post' '/cashier/grant-points' @{ branchId = $branch.result.id; customerId = $customerLogin.userId; purchaseAmount = 30 } $hCashier 'cashier_grant_points'
$log.Add($grant)

# Points exchange (merchant -> brand), using saved point values (10 and 5)
$exchange = Try-Api 'Post' '/points/exchange' @{ sourceType='merchant'; sourceId=$merchantReq.result.roleProfileId; destinationType='brand'; destinationId=$brandReq.result.roleProfileId; sourcePoints=10; sourcePointValue=10; destinationPointValue=5 } $hCustomer 'points_exchange'
$log.Add($exchange)

# Reward claim create + cashier redeem
$claim = Try-Api 'Post' '/reward-claims/create' @{ sourceType='merchant'; sourceId=$merchantReq.result.roleProfileId; pointsCost=1; rewardKind='physical' } $hCustomer 'reward_claim_create'
$log.Add($claim)
$log.Add((Try-Api 'Post' '/cashier/redeem-claim' @{ pickupQrCode = $claim.result.pickupQrCode } $hCashier 'cashier_redeem_claim'))

# Customer-facing basics
$log.Add((Try-Api 'Get' '/offers' $null $hCustomer 'offers_list'))
$log.Add((Try-Api 'Get' '/stores' $null $hCustomer 'stores_list'))
$log.Add((Try-Api 'Post' '/wallet/ensure' @{} $hCustomer 'wallet_ensure'))
$log.Add((Try-Api 'Get' '/wallet' $null $hCustomer 'wallet_get'))
$log.Add((Try-Api 'Get' '/wallet/points' $null $hCustomer 'wallet_points'))
$log.Add((Try-Api 'Get' '/rewards' $null $hCustomer 'rewards_list'))
$log.Add((Try-Api 'Get' '/roles/me' $null $hCustomer 'roles_me_customer'))
$log.Add((Try-Api 'Get' '/notifications/my' $null $hCustomer 'notifications_my'))

$result = [ordered]@{
  base = $base
  ranAt = (Get-Date).ToString('o')
  merchantEmail = $merchantEmail
  brandEmail = $brandEmail
  customerEmail = $customerEmail
  cashierEmail = $cashierEmail
  log = $log
}

$result | ConvertTo-Json -Depth 20 | Set-Content -Path 'phase18_full_app_e2e_test_results.json' -Encoding UTF8
Write-Output 'E2E_TEST_DONE'
