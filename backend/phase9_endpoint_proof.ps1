$ErrorActionPreference = 'Stop'

$base = 'http://127.0.0.1:3006/api'
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$password = 'Test1234!'

function New-Email([string]$prefix) {
  return "$prefix.$stamp.$(Get-Random -Maximum 999999)@kupuna.test"
}

function Json($obj) { $obj | ConvertTo-Json -Depth 25 }

function Call-Api([string]$method, [string]$path, $body = $null, $headers = $null) {
  $uri = "$base$path"
  if ($null -ne $body) {
    return Invoke-RestMethod -Method $method -Uri $uri -ContentType 'application/json' -Body (Json $body) -Headers $headers
  }
  return Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
}

$result = [ordered]@{}

# 1) bootstrap users
$adminEmail = New-Email 'admin'
$merchantEmail = New-Email 'merchant'
$brandEmail = New-Email 'brand'
$customerEmail = New-Email 'customer'
$memberEmail = New-Email 'member'

$result.signupAdmin = Call-Api 'Post' '/auth/signup' @{ email = $adminEmail; password = $password; role = 'admin' }
$result.signupMerchant = Call-Api 'Post' '/auth/signup' @{ email = $merchantEmail; password = $password; role = 'customer' }
$result.signupBrand = Call-Api 'Post' '/auth/signup' @{ email = $brandEmail; password = $password; role = 'customer' }
$result.signupCustomer = Call-Api 'Post' '/auth/signup' @{ email = $customerEmail; password = $password; role = 'customer' }
$result.signupMember = Call-Api 'Post' '/auth/signup' @{ email = $memberEmail; password = $password; role = 'customer' }

$admin = Call-Api 'Post' '/auth/login' @{ email = $adminEmail; password = $password }
$merchant = Call-Api 'Post' '/auth/login' @{ email = $merchantEmail; password = $password }
$brand = Call-Api 'Post' '/auth/login' @{ email = $brandEmail; password = $password }
$customer = Call-Api 'Post' '/auth/login' @{ email = $customerEmail; password = $password }
$member = Call-Api 'Post' '/auth/login' @{ email = $memberEmail; password = $password }

$hAdmin = @{ Authorization = "Bearer $($admin.token)" }
$hMerchant = @{ Authorization = "Bearer $($merchant.token)" }
$hBrand = @{ Authorization = "Bearer $($brand.token)" }
$hCustomer = @{ Authorization = "Bearer $($customer.token)" }
$hMember = @{ Authorization = "Bearer $($member.token)" }

# 2) register push tokens and push-test
$result.registerPushCustomer = Call-Api 'Post' '/notifications/push-token/register' @{ token = "fake-token-customer-$stamp"; platform = 'web' } $hCustomer
$result.registerPushMerchant = Call-Api 'Post' '/notifications/push-token/register' @{ token = "fake-token-merchant-$stamp"; platform = 'web' } $hMerchant
$result.pushTestCustomer = Call-Api 'Post' '/notifications/push-test' @{ title = 'Phase9 Push'; body = 'Phase9 verification push test' } $hCustomer

# 3) activate merchant + brand and prove auto-group creation
$merchantReq = Call-Api 'Post' '/roles/merchant/request' @{ businessName='Phase9 Merchant'; commercialRegistration='CR-P9-M'; planType='monthly' } $hMerchant
$brandReq = Call-Api 'Post' '/roles/brand/request' @{ businessName='Phase9 Brand'; commercialRegistration='CR-P9-B'; planType='monthly' } $hBrand
$result.approveMerchant = Call-Api 'Post' "/admin/role-requests/$($merchantReq.requestId)/approve" @{} $hAdmin
$result.approveBrand = Call-Api 'Post' "/admin/role-requests/$($brandReq.requestId)/approve" @{} $hAdmin

$merchantRoles = Call-Api 'Get' '/roles/me' $null $hMerchant
$brandRoles = Call-Api 'Get' '/roles/me' $null $hBrand
$merchantProfileId = ($merchantRoles.subscriptions | Where-Object { $_.roleType -eq 'merchant' } | Select-Object -First 1).roleProfileId
$brandProfileId = ($brandRoles.subscriptions | Where-Object { $_.roleType -eq 'brand' } | Select-Object -First 1).roleProfileId

$result.communityGroupsMerchant = Call-Api 'Get' '/community/groups/my' $null $hMerchant
$result.communityGroupsBrand = Call-Api 'Get' '/community/groups/my' $null $hBrand

$merchantGroup = ($result.communityGroupsMerchant | Where-Object { $_.roleType -eq 'merchant' -and $_.roleProfileId -eq $merchantProfileId } | Select-Object -First 1)
$brandGroup = ($result.communityGroupsBrand | Where-Object { $_.roleType -eq 'brand' -and $_.roleProfileId -eq $brandProfileId } | Select-Object -First 1)
if (-not $merchantGroup) { throw 'merchant_group_not_created' }
if (-not $brandGroup) { throw 'brand_group_not_created' }

# 4) build approved invoice flow and prove auto-join
$result.cashbackV2 = Call-Api 'Post' '/wallet/cashback-v2' @{ merchantId = $merchantProfileId; purchaseAmount = 120 } $hCustomer
$invoice = Call-Api 'Post' '/invoices/scan-v2' @{ merchantName='Phase9 Store'; merchantProfileId=$merchantProfileId; invoiceNumber="INV-P9-$stamp"; invoiceDate=(Get-Date).ToString('yyyy-MM-dd'); totalAmount=40; imageHash="img-p9-$stamp" } $hCustomer
$result.scanInvoice = $invoice

$lineItems = Call-Api 'Post' "/invoices/$($invoice.id)/line-items" @{ items = @(@{ name='Brand Product Phase9'; quantity=1; unitPrice=40; lineTotal=40 }) } $hCustomer
$result.addLineItems = $lineItems
$lineItemId = ($lineItems.lineItemIds | Select-Object -First 1)

$result.brandMatches = Call-Api 'Post' "/invoices/$($invoice.id)/brand-matches" @{ matches = @(@{ invoiceLineItemId = $lineItemId; brandId = $brandProfileId; confidence = 95 }) } $hCustomer
$result.approveInvoice = Call-Api 'Post' "/invoices/$($invoice.id)/state-transition" @{ to = 'approved' } $hCustomer

$result.communityGroupsCustomerAfterApprovedInvoice = Call-Api 'Get' '/community/groups/my' $null $hCustomer

# 5) community moderation endpoints with real authorization checks
$result.postMessage = Call-Api 'Post' "/community/groups/$($merchantGroup.id)/messages" @{ text = 'phase9 message sample' } $hCustomer
$messageId = $result.postMessage.id
$result.pinMessage = Call-Api 'Post' "/community/groups/$($merchantGroup.id)/messages/$messageId/pin" @{} $hMerchant
$result.deleteMessage = Call-Api 'Delete' "/community/groups/$($merchantGroup.id)/messages/$messageId" $null $hMerchant
$result.banMember = Call-Api 'Post' "/community/groups/$($merchantGroup.id)/members/$($member.userId)/ban" @{ reason = 'phase9 test ban' } $hMerchant

# 6) offer targeting rules wired to /offers list
$result.createTargetedOffer = Call-Api 'Post' '/offers/targeted' @{ description='city targeted offer'; targetType='city'; targetValue=''; category='general'; offerType='targeted' } $hMerchant
$result.offersAllForCustomer = Call-Api 'Get' '/offers' $null $hCustomer
$result.offersFilteredByType = Call-Api 'Get' '/offers?targetType=city' $null $hCustomer

# 7) notification events proof
$result.notificationsCustomer = Call-Api 'Get' '/notifications/my' $null $hCustomer
$result.notificationsMerchant = Call-Api 'Get' '/notifications/my' $null $hMerchant

$result.meta = [ordered]@{
  ranAt = (Get-Date).ToString('o')
  merchantProfileId = $merchantProfileId
  brandProfileId = $brandProfileId
  merchantGroupId = $merchantGroup.id
  brandGroupId = $brandGroup.id
  invoiceId = $invoice.id
  lineItemId = $lineItemId
}

$result | ConvertTo-Json -Depth 25 | Set-Content -Path 'backend/phase9_endpoint_proof_results.json' -Encoding UTF8
Write-Output 'PHASE9_PROOF_DONE'
