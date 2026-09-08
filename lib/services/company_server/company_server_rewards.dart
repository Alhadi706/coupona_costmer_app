part of '../company_server_service.dart';

class _CompanyServerRewards {
  static Future<List<Map<String, dynamic>>> getEligibleReportStores({
    String query = '',
  }) async {
    final data = await _CompanyServerCore.get(
      '/reports/store-options',
      query: query.isEmpty ? null : {'q': query},
      auth: true,
    );
    return (data as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getReportProductOptions(
    String query,
  ) async {
    final data = await _CompanyServerCore.get(
      '/reports/product-options',
      query: {'q': query},
      auth: true,
    );
    return (data as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> createReport({
    required String reportType,
    String? targetStoreId,
    String? targetBrandId,
    required String description,
    String? productName,
    String? imageUrl,
    double? locationLat,
    double? locationLng,
    String? locationAddress,
  }) async {
    final data = await _CompanyServerCore.post('/reports', {
      'reportType': reportType,
      if (targetStoreId != null) 'targetStoreId': targetStoreId,
      if (targetBrandId != null) 'targetBrandId': targetBrandId,
      'description': description,
      if (productName != null) 'productName': productName,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (locationLat != null) 'locationLat': locationLat,
      if (locationLng != null) 'locationLng': locationLng,
      if (locationAddress != null) 'locationAddress': locationAddress,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getBrandReportsInbox() async {
    final data = await _CompanyServerCore.get('/brand/reports/inbox', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMyReports() async {
    final data = await _CompanyServerCore.get('/reports/my', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> respondToReport(
    String reportId,
    String message,
  ) async {
    final data = await _CompanyServerCore.post('/reports/$reportId/respond', {
      'message': message.trim(),
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMerchantReportsInbox() async {
    final data = await _CompanyServerCore.get('/merchant/reports/inbox', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> acceptMerchantReport(
    String reportId, {
    String action = 'accept',
    bool grantReward = false,
    int rewardPoints = 10,
    String? resolutionNote,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/reports/$reportId/accept', {
      'action': action,
      'grantReward': grantReward,
      'rewardPoints': rewardPoints,
      'resolutionNote': resolutionNote,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> resolveBrandReport(
    String reportId, {
    String action = 'accept',
    bool grantReward = false,
    int rewardPoints = 10,
    String? resolutionNote,
  }) async {
    final data = await _CompanyServerCore.post('/brand/reports/$reportId/resolve', {
      'action': action,
      'grantReward': grantReward,
      'rewardPoints': rewardPoints,
      'resolutionNote': resolutionNote,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final data = await _CompanyServerCore.get('/notifications/my', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _CompanyServerCore.post(
      '/notifications/$notificationId/read',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<Map<String, dynamic>> createMerchantGiftTrigger({
    required int thresholdPoints,
    required String merchantName,
    required String messageTemplate,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/gifts/trigger', {
      'thresholdPoints': thresholdPoints,
      'merchantName': merchantName,
      'messageTemplate': messageTemplate,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> dispatchDirectGift({
    required String customerUserId,
    required String merchantName,
    required int thresholdPoints,
    List<Map<String, dynamic>>? voucherOptions,
  }) async {
    final data = await _CompanyServerCore.post('/customer/gifts/dispatch', {
      'customerUserId': customerUserId,
      'merchantName': merchantName,
      'thresholdPoints': thresholdPoints,
      'voucherOptions': voucherOptions ?? const <Map<String, dynamic>>[],
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> showGiftSelectionDialog(
    BuildContext context, {
    required String merchantName,
    required int thresholdPoints,
    List<Map<String, dynamic>>? vouchers,
  }) async {
    await GiftSelectionDialog.show(
      context,
      merchantName: merchantName,
      thresholdPoints: thresholdPoints,
      vouchers: vouchers,
    );
  }

  static Future<void> showCoBrandedRewardDialog(
    BuildContext context, {
    required String rewardTitle,
    required List<String> sponsorNames,
  }) async {
    await CoBrandedRewardDialog.show(
      context,
      rewardTitle: rewardTitle,
      sponsorNames: sponsorNames,
    );
  }

  static Future<void> showDegradedLocalModeGuard(
    BuildContext context, {
    required String merchantName,
  }) async {
    await DegradedLocalModeGuard.show(context, merchantName: merchantName);
  }

  static Future<List<Map<String, dynamic>>> getGiftVoucherOptions({
    String? merchantName,
    String? category,
  }) async {
    final data = await _CompanyServerCore.get(
      '/customer/gifts/vouchers',
      query: {
        if (merchantName != null && merchantName.isNotEmpty)
          'merchantName': merchantName,
        if (category != null && category.isNotEmpty) 'category': category,
      },
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getOffers({
    String? category,
    String? targetType,
    String? targetValue,
    int? minPoints,
  }) async {
    final query = <String, String>{};
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (targetType != null && targetType.trim().isNotEmpty) {
      query['targetType'] = targetType.trim();
    }
    if (targetValue != null && targetValue.trim().isNotEmpty) {
      query['targetValue'] = targetValue.trim();
    }
    if (minPoints != null) {
      query['minPoints'] = minPoints.toString();
    }

    final data = await _CompanyServerCore.get(
      '/offers',
      query: query.isEmpty ? null : query,
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMyOffers() async {
    final data = await _CompanyServerCore.get('/offers/mine', auth: true);
    return (data as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> createOffer(Map<String, dynamic> payload) async {
    await _CompanyServerCore.post('/offers', payload, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getRewards({
    String? merchantId,
    String? coalitionId,
  }) async {
    final queryParams = <String>[];
    if (merchantId != null && merchantId.isNotEmpty) {
      queryParams.add('merchant_id=${Uri.encodeComponent(merchantId)}');
    }
    if (coalitionId != null && coalitionId.isNotEmpty) {
      queryParams.add('coalition_id=${Uri.encodeComponent(coalitionId)}');
    }
    final path = queryParams.isEmpty
        ? '/rewards'
        : '/rewards?${queryParams.join('&')}';
    final data = await _CompanyServerCore.get(path, auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMerchantRewards() async {
    final data = await _CompanyServerCore.get('/merchant/rewards', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMerchantRewardClaims() async {
    final data = await _CompanyServerCore.get('/merchant/reward-claims', auth: true);
    return (data as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> getRewardFundingSummary(
    String sourceType,
  ) async {
    final data = await _CompanyServerCore.get('/reward-funding/$sourceType/summary', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> fundRewardEscrow(
    String sourceType, {
    required int amount,
  }) async {
    final data = await _CompanyServerCore.post('/reward-funding/$sourceType/fund', {
      'amount': amount,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> referRewardFundingToAdmin(
    String sourceType, {
    required int amount,
  }) async {
    final data = await _CompanyServerCore.post('/reward-funding/$sourceType/refer-to-admin', {
      'amount': amount,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getBrandRewards() async {
    final data = await _CompanyServerCore.get('/brand/rewards', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> getBrandTokenWallet() async {
    final data = await _CompanyServerCore.get('/brand/token-wallet/balance', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getBrandPendingPoints() async {
    final data = await _CompanyServerCore.get('/brand/wallet/pending-points', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createBrandReward({
    required String rewardName,
    required int points,
    String? description,
    String? imageUrl,
    String kind = 'physical',
    DateTime? expiresAt,
    int? quantityLimit,
    String? pickupInstructions,
    bool drawEnabled = false,
    DateTime? drawAt,
  }) async {
    final data = await _CompanyServerCore.post('/brand/rewards', {
      'rewardName': rewardName,
      'value': points,
      'description': description,
      'imageUrl': imageUrl,
      'kind': kind,
      'expiresAt': expiresAt?.toIso8601String(),
      'quantityLimit': quantityLimit,
      'pickupInstructions': pickupInstructions,
      'drawEnabled': drawEnabled,
      'drawAt': drawAt?.toIso8601String(),
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateBrandReward(
    String rewardId, {
    bool? isActive,
    int? quantityLimit,
    DateTime? expiresAt,
    String? description,
  }) async {
    final data = await _CompanyServerCore.patch('/brand/rewards/$rewardId', {
      if (isActive != null) 'isActive': isActive,
      if (quantityLimit != null) 'quantityLimit': quantityLimit,
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      if (description != null) 'description': description,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getBrandRewardClaims() async {
    final data = await _CompanyServerCore.get('/brand/reward-claims', auth: true);
    return (data as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> drawBrandReward(String rewardId) async {
    final data = await _CompanyServerCore.post(
      '/brand/rewards/$rewardId/draw',
      <String, dynamic>{},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createMerchantReward({
    required String rewardName,
    required int points,
    String? description,
    String? imageUrl,
    String kind = 'physical',
    DateTime? expiresAt,
    int? quantityLimit,
    String? pickupInstructions,
    bool drawEnabled = false,
    DateTime? drawAt,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/rewards', {
      'rewardName': rewardName,
      'value': points,
      'description': description,
      'imageUrl': imageUrl,
      'kind': kind,
      'expiresAt': expiresAt?.toIso8601String(),
      'quantityLimit': quantityLimit,
      'pickupInstructions': pickupInstructions,
      'drawEnabled': drawEnabled,
      'drawAt': drawAt?.toIso8601String(),
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> updateMerchantReward(
    String rewardId, {
    bool? isActive,
    int? quantityLimit,
    DateTime? expiresAt,
    String? description,
  }) async {
    await _CompanyServerCore.patch('/merchant/rewards/$rewardId', {
      'isActive': isActive,
      'quantityLimit': quantityLimit,
      'expiresAt': expiresAt?.toIso8601String(),
      'description': description,
    }, auth: true);
  }

  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    await _CompanyServerCore.post('/users/$userId/profile', payload, auth: true);
  }

  static Future<Map<String, dynamic>> getMerchantPendingPoints() async {
    final data = await _CompanyServerCore.get('/merchant/wallet/pending-points', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getActivityLogs({
    required String customerEmail,
  }) async {
    final data = await _CompanyServerCore.get(
      '/activity-logs',
      query: {'customerEmail': customerEmail},
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> ensureAccountingDocuments() async {
    await _CompanyServerCore.post('/wallet/ensure', <String, dynamic>{}, auth: true);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final data = await _CompanyServerCore.get('/wallet', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getPointAccount() async {
    final data = await _CompanyServerCore.get('/wallet/points', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCustomerPointTiers() async {
    final data = await _CompanyServerCore.get('/customer/wallet/tiers', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCustomerPendingPoints() async {
    final data = await _CompanyServerCore.get('/customer/wallet/pending-points', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCustomerGiftCatalog() async {
    final data = await _CompanyServerCore.get('/customer/gifts/catalog', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createDynamicVoucher({
    required double cashValueLyD,
    int? points,
    String? coalitionId,
    String? merchantId,
  }) async {
    final data = await _CompanyServerCore.post('/customer/redemptions/dynamic-voucher', {
      'cashValueLyD': cashValueLyD,
      if (points != null) 'points': points,
      if (coalitionId != null && coalitionId.isNotEmpty)
        'coalitionId': coalitionId,
      if (merchantId != null && merchantId.isNotEmpty) 'merchantId': merchantId,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getLedgerEntries({
    int limit = 50,
  }) async {
    final data = await _CompanyServerCore.get(
      '/wallet/ledger',
      query: {'limit': limit},
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> applyCashbackFromPurchase({
    required double purchaseAmount,
    required String reference,
  }) async {
    await _CompanyServerCore.post('/wallet/cashback', {
      'purchaseAmount': purchaseAmount,
      'reference': reference,
    }, auth: true);
  }

  static Future<void> redeemPoints({
    required int points,
    required String reference,
  }) async {
    await _CompanyServerCore.post('/wallet/redeem', {
      'points': points,
      'reference': reference,
    }, auth: true);
  }

  static Future<Map<String, dynamic>?> saveInvoiceScan({
    required String rawText,
    required String category,
    double? totalAmount,
    String? invoiceNumber,
    String? orderNumber,
    String? invoiceDate,
    String? merchantName,
    List<Map<String, dynamic>>? items,
    String? currency,
    bool rewardApplied = false,
    String? imageBase64,
  }) async {
    try {
      final data = await _CompanyServerCore.post('/invoices/scan', {
        'rawText': rawText,
        'category': category,
        'totalAmount': totalAmount,
        'invoiceNumber': invoiceNumber,
        'orderNumber': orderNumber,
        'invoiceDate': invoiceDate,
        'merchantName': merchantName,
        'items': items ?? const <Map<String, dynamic>>[],
        'currency': currency ?? 'SAR',
        'rewardApplied': rewardApplied,
        'imageBase64': imageBase64,
      }, auth: true);
      if (data == null) return null;
      return (data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> analyzeInvoiceWithAi({
    required String rawText,
    String? imageBase64,
    String? mimeType,
  }) async {
    try {
      final response = await http.post(
        _CompanyServerCore._aiUri('/invoices/analyze-ai'),
        headers: await _CompanyServerCore._headers(auth: true),
        body: jsonEncode({
          'rawText': rawText,
          'imageBase64': imageBase64,
          'mimeType': mimeType ?? 'image/jpeg',
        }),
      );
      if (response.statusCode >= 400) {
        return null;
      }
      final data = _CompanyServerCore._decode(response);
      if (data == null) return null;
      return (data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getOfferLifecycle(String offerId) async {
    final data = await _CompanyServerCore.get('/offers/$offerId/lifecycle', auth: true);
    if (data == null) return null;
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> ensureOfferLifecycleDefaults(String offerId) async {
    await _CompanyServerCore.post(
      '/offers/$offerId/lifecycle/ensure-defaults',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> transitionOfferLifecycle({
    required String offerId,
    required String targetStatus,
    String? reason,
  }) async {
    await _CompanyServerCore.post('/offers/$offerId/lifecycle/transition', {
      'targetStatus': targetStatus,
      'reason': reason,
    }, auth: true);
  }

  static Future<void> syncOfferTemporalStatus(String offerId) async {
    await _CompanyServerCore.post(
      '/offers/$offerId/lifecycle/sync-temporal',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<List<Map<String, dynamic>>> getMyInvoices({
    int limit = 20,
  }) async {
    final data = await _CompanyServerCore.get('/invoices/my', query: {'limit': limit}, auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> getMerchantInvoices({
    String state = 'all',
    int limit = 100,
  }) async {
    final data = await _CompanyServerCore.get(
      '/merchant/invoices',
      query: {'state': state, 'limit': limit},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> transitionInvoiceState({
    required String invoiceId,
    required String to,
    String? note,
  }) async {
    final data = await _CompanyServerCore.post('/invoices/$invoiceId/state-transition', {
      'to': to,
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createInvoiceDispute({
    required String invoiceId,
    required String reason,
    String? evidence,
  }) async {
    final data = await _CompanyServerCore.post('/invoices/$invoiceId/disputes', {
      'reason': reason,
      if ((evidence ?? '').trim().isNotEmpty) 'evidence': evidence!.trim(),
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getPosGrantQrToken() async {
    final data = await _CompanyServerCore.post('/customer/pos-qr-token', const {}, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> grantCashierPoints({
    required String branchId,
    required double purchaseAmount,
    String? qrToken,
    bool manualOverride = false,
    String? manualCustomerId,
    String? manualOverrideReason,
  }) async {
    final data = await _CompanyServerCore.post('/cashier/grant-points', {
      'branchId': branchId,
      'purchaseAmount': purchaseAmount,
      if (qrToken != null && qrToken.isNotEmpty) 'qrToken': qrToken,
      if (manualOverride) 'manualOverride': true,
      if (manualOverride) 'customerId': manualCustomerId ?? '',
      if (manualOverride) 'manualOverrideReason': manualOverrideReason ?? '',
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> exchangePoints({
    required double sourcePoints,
    required double sourcePointValue,
    required double destinationPointValue,
    String sourceType = 'merchant',
    String sourceId = '',
    String destinationType = 'merchant',
    String destinationId = '',
  }) async {
    final data = await _CompanyServerCore.post('/points/exchange', {
      'sourcePoints': sourcePoints,
      'sourcePointValue': sourcePointValue,
      'destinationPointValue': destinationPointValue,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'destinationType': destinationType,
      'destinationId': destinationId,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createRewardClaim({
    required int pointsCost,
    String? rewardId,
    String sourceType = 'merchant',
    String sourceId = '',
    String rewardKind = 'physical',
    String? idempotencyKey,
  }) async {
    final data = await _CompanyServerCore.post('/reward-claims/create', {
      'pointsCost': pointsCost,
      'rewardId': rewardId,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'rewardKind': rewardKind,
      if ((idempotencyKey ?? '').isNotEmpty) 'idempotencyKey': idempotencyKey,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> redeemRewardClaim({
    required String pickupQrCode,
  }) async {
    final data = await _CompanyServerCore.post('/cashier/redeem-claim', {
      'pickupQrCode': pickupQrCode,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createCampaign({
    required String campaignType,
    required String title,
    required String segmentFilter,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    num? discountPercentage,
    String? giftDescription,
    num? minInvoiceAmount,
    Map<String, dynamic>? segmentParams,
    String? partnerMerchantId,
    String launchMode = 'active',
    int? maxRecipients,
    num? maxCampaignSpend,
    num? estimatedCostPerRecipient,
  }) async {
    final data = await _CompanyServerCore.post('/campaigns', {
      'campaignType': campaignType,
      'title': title,
      'description': description,
      'discountPercentage': discountPercentage,
      'giftDescription': giftDescription,
      'minInvoiceAmount': minInvoiceAmount,
      'segmentFilter': segmentFilter,
      'segmentParams': segmentParams ?? const <String, dynamic>{},
      if ((partnerMerchantId ?? '').isNotEmpty)
        'partnerMerchantId': partnerMerchantId,
      'launchMode': launchMode,
      if (maxRecipients != null && maxRecipients > 0)
        'maxRecipients': maxRecipients,
      if (maxCampaignSpend != null && maxCampaignSpend > 0)
        'maxCampaignSpend': maxCampaignSpend,
      if (estimatedCostPerRecipient != null && estimatedCostPerRecipient > 0)
        'estimatedCostPerRecipient': estimatedCostPerRecipient,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> previewCampaign({
    required String segmentFilter,
    Map<String, dynamic>? segmentParams,
    String? partnerMerchantId,
    int? maxRecipients,
    num? maxCampaignSpend,
    num? estimatedCostPerRecipient,
  }) async {
    final data = await _CompanyServerCore.post('/campaigns/preview', {
      'segmentFilter': segmentFilter,
      'segmentParams': segmentParams ?? const <String, dynamic>{},
      if ((partnerMerchantId ?? '').isNotEmpty)
        'partnerMerchantId': partnerMerchantId,
      if (maxRecipients != null && maxRecipients > 0)
        'maxRecipients': maxRecipients,
      if (maxCampaignSpend != null && maxCampaignSpend > 0)
        'maxCampaignSpend': maxCampaignSpend,
      if (estimatedCostPerRecipient != null && estimatedCostPerRecipient > 0)
        'estimatedCostPerRecipient': estimatedCostPerRecipient,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> launchCampaign(String campaignId) async {
    final data = await _CompanyServerCore.post(
      '/campaigns/$campaignId/launch',
      const {},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateCampaignStatus(
    String campaignId,
    String status,
  ) async {
    final data = await _CompanyServerCore.patch('/campaigns/$campaignId/status', {
      'status': status,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyCampaigns() async {
    final data = await _CompanyServerCore.get('/campaigns/mine', auth: true);
    final campaigns = (data as Map)['campaigns'] as List? ?? const <dynamic>[];
    return campaigns.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<List<Map<String, dynamic>>> getCampaignCustomers({
    String? partnerMerchantId,
    String? query,
  }) async {
    final parameters = <String, String>{
      if ((partnerMerchantId ?? '').isNotEmpty)
        'partnerMerchantId': partnerMerchantId!,
      if ((query ?? '').trim().isNotEmpty) 'query': query!.trim(),
    };
    final suffix = parameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: parameters).query}';
    final data = await _CompanyServerCore.get('/campaigns/customers$suffix', auth: true);
    final customers = (data as Map)['customers'] as List? ?? const <dynamic>[];
    return customers
        .map((entry) => (entry as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMyCampaignCoupons() async {
    final data = await _CompanyServerCore.get('/customer/campaigns/my-coupons', auth: true);
    final coupons = (data as Map)['coupons'] as List? ?? const <dynamic>[];
    return coupons.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<List<Map<String, dynamic>>> getMyRaffleTickets() async {
    final data = await _CompanyServerCore.get('/customer/campaigns/my-raffle-tickets', auth: true);
    final tickets = (data as Map)['tickets'] as List? ?? const <dynamic>[];
    return tickets.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> getWalletPointSources() async {
    final data = await _CompanyServerCore.get('/wallet/points/sources', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> redeemCampaignCoupon({
    required String qrCode,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/campaigns/redeem', {
      'qrCode': qrCode,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyRewardClaims({
    int limit = 50,
  }) async {
    final data = await _CompanyServerCore.get(
      '/reward-claims/my',
      query: {'limit': limit},
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMyGiftDefinitions() async {
    final data = await _CompanyServerCore.get('/api/gifts/definitions/mine', auth: true);
    final list = (data as Map)['gifts'] as List? ?? const <dynamic>[];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> getMyGiftAnalytics() async {
    final data = await _CompanyServerCore.get('/api/gifts/analytics/mine', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createGiftDefinition({
    required String giftType,
    required String title,
    String? description,
    num? valueAmount,
    int? discountPercentage,
    String? terms,
    String? pickupInstructions,
    String status = 'ACTIVE',
    DateTime? expiresAt,
  }) async {
    final payload = {
      'giftType': giftType,
      'title': title,
      if (description != null) 'description': description,
      if (valueAmount != null) 'valueAmount': valueAmount,
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (terms != null) 'terms': terms,
      if (pickupInstructions != null) 'pickupInstructions': pickupInstructions,
      'status': status,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    };
    final data = await _CompanyServerCore.post('/api/gifts/definitions', payload, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> launchGiftCampaign({
    required String giftDefinitionId,
    required String title,
    String segmentFilter = 'all',
    Map<String, dynamic>? segmentParams,
    int? maxRecipients,
    DateTime? endsAt,
  }) async {
    final payload = {
      'title': title,
      'segmentFilter': segmentFilter,
      if (segmentParams != null) 'segmentParams': segmentParams,
      if (maxRecipients != null) 'maxRecipients': maxRecipients,
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
    };
    final data = await _CompanyServerCore.post('/api/gifts/definitions/$giftDefinitionId/campaigns/launch', payload, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyGiftAssignments() async {
    final data = await _CompanyServerCore.get('/customer/gifts/assignments', auth: true);
    final list = (data as Map)['assignments'] as List? ?? const <dynamic>[];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> markGiftAssignmentViewed(String assignmentId) async {
    final data = await _CompanyServerCore.post('/customer/gifts/assignments/$assignmentId/view', <String, dynamic>{}, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> claimGiftAssignment(String assignmentId) async {
    final data = await _CompanyServerCore.post('/customer/gifts/assignments/$assignmentId/claim', <String, dynamic>{}, auth: true);
    return (data as Map).cast<String, dynamic>();
  }
}
