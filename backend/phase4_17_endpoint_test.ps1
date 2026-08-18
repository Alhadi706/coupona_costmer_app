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

function Assert-HttpError([string]$Method, [string]$Path, $Body, $Headers, [int]$ExpectedStatus) {
  $uri = "$base$Path"
  try {
    if ($null -ne $Body) {
      $null = Invoke-RestMethod -Method $Method -Uri $uri -ContentType 'application/json' -Body (Json $Body) -Headers $Headers
    } else {
      $null = Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers
    }
    throw "Expected HTTP $ExpectedStatus but call succeeded"
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $status = [int]$_.Exception.Response.StatusCode
      if ($status -ne $ExpectedStatus) {
        throw "Expected HTTP $ExpectedStatus but got $status"
      }
      return $true
    }
    throw
  }
}

$phase = [ordered]@{}
foreach ($i in 4..17) { $phase["phase_$i"] = @{ ok = $false; notes = @() } }

$health = Invoke-Api 'Get' '/health'
if (-not $health.ok) { throw 'health_not_ok' }

$adminEmail = New-Email 'admin'
$merchantEmail = New-Email 'merchant'
$brandEmail = New-Email 'brand'
$customerEmail = New-Email 'customer'
$cashierEmail = New-Email 'cashier'
$password = 'Test1234!'

$null = Invoke-Api 'Post' '/auth/signup' @{ email = $adminEmail; password = $password; role = 'admin' }
$null = Invoke-Api 'Post' '/auth/signup' @{ email = $merchantEmail; password = $password; role = 'customer' }
$null = Invoke-Api 'Post' '/auth/signup' @{ email = $brandEmail; password = $password; role = 'customer' }
$null = Invoke-Api 'Post' '/auth/signup' @{ email = $customerEmail; password = $password; role = 'customer' }
$null = Invoke-Api 'Post' '/auth/signup' @{ email = $cashierEmail; password = $password; role = 'customer' }

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

# Phase 4 setup (role activation and branch/team management)
$merchantReq = Invoke-Api 'Post' '/roles/merchant/request' @{ businessName='Phase Merchant'; commercialRegistration='CR-4'; planType='monthly' } $hMerchant
$brandReq = Invoke-Api 'Post' '/roles/brand/request' @{ businessName='Phase Brand'; commercialRegistration='CR-B'; planType='monthly' } $hBrand
$null = Invoke-Api 'Post' "/admin/role-requests/$($merchantReq.requestId)/approve" @{} $hAdmin
$null = Invoke-Api 'Post' "/admin/role-requests/$($brandReq.requestId)/approve" @{} $hAdmin

$merchantRoles = Invoke-Api 'Get' '/roles/me' $null $hMerchant
$brandRoles = Invoke-Api 'Get' '/roles/me' $null $hBrand
$merchantProfileId = ($merchantRoles.subscriptions | Where-Object { $_.roleType -eq 'merchant' } | Select-Object -First 1).roleProfileId
$brandProfileId = ($brandRoles.subscriptions | Where-Object { $_.roleType -eq 'brand' } | Select-Object -First 1).roleProfileId
if (-not $merchantProfileId) { throw 'merchant_profile_not_found' }
if (-not $brandProfileId) { throw 'brand_profile_not_found' }

$branch = Invoke-Api 'Post' '/merchant/branches' @{ name='Main Branch'; address='Tripoli'; location='Tripoli' } $hMerchant
$null = Invoke-Api 'Post' "/merchant/branches/$($branch.id)/managers" @{ userId = $cashierLogin.userId } $hMerchant
$null = Invoke-Api 'Patch' "/merchant/branches/$($branch.id)/managers/$($cashierLogin.userId)/permissions" @{ canAddCashiers = $true; canViewReports = $true; canManageGroup = $true } $hMerchant
$null = Invoke-Api 'Post' '/brand/team-members' @{ userId = $merchantLogin.userId; canManageProducts = $true; canViewGeoDistribution = $true } $hBrand
$phase.phase_4.ok = $true
$phase.phase_4.notes += 'branch/team endpoints passed'

# Phase 5 points engine v2
$cb = Invoke-Api 'Post' '/wallet/cashback-v2' @{ merchantId = $merchantProfileId; purchaseAmount = 125 } $hCustomer
if ($cb.points -lt 0) { throw 'invalid_cashback_points' }
$null = Invoke-Api 'Post' '/wallet/refund-deduction' @{ points = 1 } $hCustomer
$null = Invoke-Api 'Post' '/admin/points/expire/run' @{} $hAdmin
$phase.phase_5.ok = $true
$phase.phase_5.notes += 'points v2 + refund + expire runner passed'

# Phase 6 cashier flow
$null = Invoke-Api 'Post' '/merchant/cashiers/bind' @{ cashierUserId = $cashierLogin.userId; branchId = $branch.id } $hMerchant
$grant = Invoke-Api 'Post' '/cashier/grant-points' @{ branchId = $branch.id; customerId = $customerLogin.userId; purchaseAmount = 30 } $hCashier
if (-not $grant.ok) { throw 'cashier_grant_failed' }
$phase.phase_6.ok = $true
$phase.phase_6.notes += 'cashier binding and branch grant passed'

# Phase 7 fraud/retention
$oldDate = (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
$null = Assert-HttpError 'Post' '/invoices/scan-v2' @{ merchantName='Store A'; invoiceNumber='INV-OLD-1'; invoiceDate=$oldDate; totalAmount=10; imageHash='img-old-1' } $hCustomer 400
$invoiceApproved = Invoke-Api 'Post' '/invoices/scan-v2' @{ merchantName='Store B'; merchantProfileId=$merchantProfileId; invoiceNumber="INV-NEW-$timestamp"; invoiceDate=(Get-Date).ToString('yyyy-MM-dd'); totalAmount=44; imageHash="img-new-$timestamp" } $hCustomer
$invoiceRejected = Invoke-Api 'Post' '/invoices/scan-v2' @{ merchantName='Store C'; merchantProfileId=$merchantProfileId; invoiceNumber="INV-REJ-$timestamp"; invoiceDate=(Get-Date).ToString('yyyy-MM-dd'); totalAmount=21; imageHash="img-rej-$timestamp" } $hCustomer
$phase.phase_7.ok = $true
$phase.phase_7.notes += 'fraud/retention scan guards passed'

# Phase 8 line-items and brand points layer
$product = Invoke-Api 'Post' '/brand/products' @{ name='Brand Product'; imageUrl='https://example.test/p.png'; barcode='123456' } $hBrand
$null = Invoke-Api 'Post' "/invoices/$($invoiceApproved.id)/line-items" @{ items = @(@{ name='Brand Product'; quantity=1; unitPrice=44; lineTotal=44 }) } $hCustomer
$phase.phase_8.ok = $true
$phase.phase_8.notes += "product $($product.id), line-items passed"

# Phase 9 communities + offers + notifications
$null = Invoke-Api 'Post' "/invoices/$($invoiceApproved.id)/state-transition" @{ to='approved' } $hCustomer
$null = Invoke-Api 'Post' "/invoices/$($invoiceRejected.id)/state-transition" @{ to='rejected' } $hCustomer

$merchantGroups = Invoke-Api 'Get' '/community/groups/my' $null $hMerchant
$customerGroups = Invoke-Api 'Get' '/community/groups/my' $null $hCustomer
$merchantGroup = $merchantGroups | Where-Object { $_.roleType -eq 'merchant' -and $_.roleProfileId -eq $merchantProfileId } | Select-Object -First 1
if (-not $merchantGroup) { throw 'merchant_community_group_missing' }
if (-not ($customerGroups | Where-Object { $_.id -eq $merchantGroup.id })) { throw 'customer_auto_join_missing' }

$message = Invoke-Api 'Post' "/community/groups/$($merchantGroup.id)/messages" @{ text='hello community' } $hCustomer
$null = Invoke-Api 'Post' "/community/groups/$($merchantGroup.id)/messages/$($message.id)/pin" @{} $hMerchant
$null = Invoke-Api 'Delete' "/community/groups/$($merchantGroup.id)/messages/$($message.id)" $null $hMerchant
$null = Invoke-Api 'Post' "/community/groups/$($merchantGroup.id)/members/$($cashierLogin.userId)/ban" @{ reason='policy violation test' } $hMerchant

$targetedOffer = Invoke-Api 'Post' '/offers/targeted' @{ description='targeted city offer'; targetType='city'; targetValue=''; category='general' } $hMerchant
if (-not $targetedOffer.ok) { throw 'targeted_offer_failed' }
$notifsCustomer = Invoke-Api 'Get' '/notifications/my' $null $hCustomer
if (-not ($notifsCustomer | Where-Object { $_.type -eq 'points_confirmed' })) { throw 'points_notification_missing' }
if (-not ($notifsCustomer | Where-Object { $_.type -eq 'invoice_approved' })) { throw 'invoice_approved_notification_missing' }
if (-not ($notifsCustomer | Where-Object { $_.type -eq 'invoice_rejected' })) { throw 'invoice_rejected_notification_missing' }
$phase.phase_9.ok = $true
$phase.phase_9.notes += 'community auto-create/join + moderation + targeted offers + notifications passed'

# Phase 10 reports and disputes flow
$report = Invoke-Api 'Post' '/reports' @{ reportType='complaint'; description='phase10 test'; targetStoreId='store-test' } $hCustomer
$null = Invoke-Api 'Post' "/reports/$($report.id)/transition" @{ to='under_review'; rewardGranted=$false } $hCustomer
$null = Invoke-Api 'Post' "/reports/$($report.id)/transition" @{ to='accepted'; rewardGranted=$false } $hCustomer
$null = Invoke-Api 'Post' "/reports/$($report.id)/transition" @{ to='reward_granted'; rewardGranted=$true } $hCustomer
$notifsAfterReport = Invoke-Api 'Get' '/notifications/my' $null $hCustomer
if (-not ($notifsAfterReport | Where-Object { $_.type -eq 'report_thank_you' })) { throw 'report_thank_you_notification_missing' }
if (-not ($notifsAfterReport | Where-Object { $_.type -eq 'report_reward_granted' })) { throw 'report_reward_notification_missing' }
$phase.phase_10.ok = $true
$phase.phase_10.notes += 'reports lifecycle + notifications passed'

# Phase 11 escrow + exchange + rewards + cashier redemption
$escrow = Invoke-Api 'Post' '/escrow/accounts' @{ sourceType='merchant'; sourceId=$merchantProfileId; balance=100 } $hMerchant
$null = Invoke-Api 'Post' '/escrow/settlements' @{ escrowAccountId=$escrow.id; amount=20; settlementType='merchant_payout' } $hMerchant
$exchange = Invoke-Api 'Post' '/points/exchange' @{ sourceType='merchant'; sourceId=$merchantProfileId; destinationType='brand'; destinationId=$brandProfileId; sourcePoints=10; sourcePointValue=1; destinationPointValue=2 } $hCustomer
if ($exchange.destinationPoints -le 0) { throw 'exchange_destination_points_invalid' }
$claim = Invoke-Api 'Post' '/reward-claims/create' @{ sourceType='merchant'; sourceId=$merchantProfileId; pointsCost=1; rewardKind='physical' } $hCustomer
$null = Invoke-Api 'Post' '/cashier/redeem-claim' @{ pickupQrCode = $claim.pickupQrCode } $hCashier
$null = Invoke-Api 'Post' '/reward-claims/refund-expired/run' @{} $hAdmin
$phase.phase_11.ok = $true
$phase.phase_11.notes += 'escrow + exchange + reward claim/redeem passed'

# Phase 12 peer ads and sourcing
$ad = Invoke-Api 'Post' '/peer-ads' @{ content='Need supplier for item X'; targetType='group'; targetValue='north'; feePaid=5 } $hCustomer
$null = Invoke-Api 'Post' "/admin/peer-ads/$($ad.id)/approve" @{} $hAdmin
$inq = Invoke-Api 'Post' '/sourcing/inquiries' @{ peerAdId=$ad.id; ownerUserId=$customerLogin.userId } $hMerchant
if (-not $inq.id) { throw 'inquiry_create_failed' }
$phase.phase_12.ok = $true
$phase.phase_12.notes += 'peer ads moderation + sourcing inquiry passed'

# Phase 13 role/subscription management
$null = Invoke-Api 'Post' '/subscriptions/run-transitions' @{} $hAdmin
$merchantRoles = Invoke-Api 'Get' '/roles/me' $null $hMerchant
$subscriptionId = ($merchantRoles.subscriptions | Where-Object { $_.roleType -eq 'merchant' } | Select-Object -First 1).id
$null = Assert-HttpError 'Post' '/payments/webhook' @{ subscriptionId = ''; paid = $true } $null 400
$null = Invoke-Api 'Post' '/payments/webhook' @{ subscriptionId = $subscriptionId; paid = $true }
$phase.phase_13.ok = $true
$phase.phase_13.notes += 'subscription transitions runner + payment webhook passed'

# Phase 14 predictive engagement
$pred = Invoke-Api 'Post' '/predictive/recommend' @{ monthlyVisits = 6; avgSpend = 80 } $hMerchant
if (-not $pred.recommendation) { throw 'predictive_missing_recommendation' }
$lh = Invoke-Api 'Get' '/merchant/loyalty-health' $null $hMerchant
if (-not $lh.ok) { throw 'loyalty_health_failed' }
$phase.phase_14.ok = $true
$phase.phase_14.notes += 'predictive + loyalty health passed'

# Phase 15 permissions and security
$null = Assert-HttpError 'Get' '/admin/dashboard/summary' $null $hCashier 403
$null = Assert-HttpError 'Post' '/offers/targeted' @{ description='unauthorized'; targetType='all' } $hCashier 403
$phase.phase_15.ok = $true
$phase.phase_15.notes += 'role-based access checks passed'

# Phase 16 admin observability
$null = Invoke-Api 'Post' '/admin/edge-cases/run-catalog' @{} $hAdmin
$summary = Invoke-Api 'Get' '/admin/dashboard/summary' $null $hAdmin
if ($summary.users -lt 1) { throw 'dashboard_summary_invalid' }
$phase.phase_16.ok = $true
$phase.phase_16.notes += 'admin observability endpoints passed'

# Phase 17 e2e final simulation
$sim = Invoke-Api 'Post' '/e2e/simulate' @{} $hAdmin
if (-not $sim.ok) { throw 'e2e_simulate_failed' }
$phase.phase_17.ok = $true
$phase.phase_17.notes += 'e2e simulate endpoint passed'

$result = [ordered]@{
  base = $base
  ranAt = (Get-Date).ToString('o')
  health = $health
  phases = $phase
}

$result | ConvertTo-Json -Depth 20 | Set-Content -Path 'phase4_17_endpoint_test_results.json' -Encoding UTF8
Write-Output 'PHASE_TEST_DONE'
