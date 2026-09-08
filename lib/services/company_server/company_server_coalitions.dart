part of '../company_server_service.dart';

class _CompanyServerCoalitions {
  static Future<Map<String, dynamic>> getPublicCoalitionWalletBalance() async {
    final data = await _CompanyServerCore.get('/merchant/token-wallet/balance', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>?> getPublicCoalitionMembershipRequest({
    required String applicantType,
  }) async {
    final data = await _CompanyServerCore.get(
      '/public-coalition/membership/me',
      query: {'applicantType': applicantType},
      auth: true,
    );
    final request = (data as Map)['request'];
    return request is Map ? request.cast<String, dynamic>() : null;
  }

  static Future<Map<String, dynamic>> requestPublicCoalitionMembership({
    required String applicantType,
  }) async {
    final data = await _CompanyServerCore.post('/public-coalition/membership/request', {
      'applicantType': applicantType,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantCoalitions() async {
    final data = await _CompanyServerCore.get('/merchant/coalitions', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantCoalitionsMine() async {
    final data = await _CompanyServerCore.get('/merchant/coalitions/mine', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantCoalitionSuggestions({
    String activityFilter = 'all',
    int radiusKm = 50,
    int limit = 20,
  }) async {
    final data = await _CompanyServerCore.get(
      '/merchant/coalitions/suggestions',
      query: {
        'activity_filter': activityFilter,
        'radius_km': radiusKm,
        'limit': limit,
      },
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createMerchantCoalition({
    required String name,
    String type = 'general',
    String? category,
    String? region,
    int? monthlyPointsCap,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/coalitions', {
      'name': name,
      'type': type,
      'category': category,
      'region': region,
      if (monthlyPointsCap != null) 'monthly_points_cap': monthlyPointsCap,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> joinMerchantCoalition(String coalitionId) async {
    await _CompanyServerCore.post(
      '/merchant/coalitions/$coalitionId/join',
      const <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> inviteMerchantToCoalition(
    String coalitionId,
    String invitedMerchantId,
  ) async {
    await _CompanyServerCore.post('/merchant/coalitions/$coalitionId/invite', {
      'invited_merchant_id': invitedMerchantId,
    }, auth: true);
  }

  static Future<Map<String, dynamic>> getMerchantCoalitionInvitations() async {
    final data = await _CompanyServerCore.get('/merchant/coalitions/invitations', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> acceptMerchantCoalitionInvitation(
    String invitationId,
  ) async {
    final invitations = await getMerchantCoalitionInvitations();
    final match = (invitations['invitations'] as List? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (entry) => (entry['id'] ?? '').toString() == invitationId,
          orElse: () => <String, dynamic>{},
        );
    final coalitionId = (match['coalition_id'] ?? '').toString();
    if (coalitionId.isEmpty) {
      throw StateError('coalition_id_not_found_for_invitation');
    }
    await _CompanyServerCore.post(
      '/merchant/coalitions/invitations/$invitationId/accept',
      const <String, dynamic>{},
      auth: true,
    );
    await _CompanyServerCore.post(
      '/merchant/coalitions/$coalitionId/join',
      const <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> rejectMerchantCoalitionInvitation(
    String invitationId,
  ) async {
    final invitations = await getMerchantCoalitionInvitations();
    final match = (invitations['invitations'] as List? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (entry) => (entry['id'] ?? '').toString() == invitationId,
          orElse: () => <String, dynamic>{},
        );
    final coalitionId = (match['coalition_id'] ?? '').toString();
    if (coalitionId.isNotEmpty) {
      await _CompanyServerCore.post(
        '/merchant/coalitions/$coalitionId/reject-invite',
        const <String, dynamic>{},
        auth: true,
      );
      return;
    }
    await _CompanyServerCore.post(
      '/merchant/coalitions/invitations/$invitationId/reject',
      const <String, dynamic>{},
      auth: true,
    );
  }

  static Future<Map<String, dynamic>> getMerchantCoalitionLedger({
    String? period,
  }) async {
    final data = await _CompanyServerCore.get(
      '/merchant/coalitions/ledger',
      query: period == null ? null : {'period': period},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>>
  getMerchantCoalitionClearinghouse() async {
    final data = await _CompanyServerCore.get('/merchant/coalitions/clearinghouse', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> settleMerchantCoalitionClearinghouse({
    required String coalitionId,
    required String toMerchantId,
    required String period,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/coalitions/clearinghouse/settle', {
      'coalition_id': coalitionId,
      'to_merchant_id': toMerchantId,
      'period': period,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> respondToBrandSettlementDispute({
    required String disputeId,
    required String status,
    required String note,
  }) async {
    final data = await _CompanyServerCore.post(
      '/merchant/coalitions/clearinghouse/disputes/$disputeId/respond',
      {'status': status, 'note': note},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCoalitionGiftCatalog(
    String coalitionId,
  ) async {
    final data = await _CompanyServerCore.get(
      '/merchant/coalitions/$coalitionId/gifts',
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createCoalitionGift({
    required String coalitionId,
    required String title,
    String? description,
    required int requiredPoints,
    double? monetaryValue,
    String campaignType = 'standard',
    int discountPercentage = 0,
    int? quantityLimit,
    String? expiresAt,
    bool targetNewCustomers = false,
    bool targetVipCustomers = false,
    int? minPurchaseFrequency,
    int? maxDaysSinceLastVisit,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/coalitions/$coalitionId/gifts', {
      'title': title,
      'description': description,
      'required_points': requiredPoints,
      'monetary_value': monetaryValue,
      'campaign_type': campaignType,
      'discount_percentage': discountPercentage,
      'quantity_limit': quantityLimit,
      'expires_at': expiresAt,
      'target_new_customers': targetNewCustomers,
      'target_vip_customers': targetVipCustomers,
      'min_purchase_frequency': minPurchaseFrequency,
      'max_days_since_last_visit': maxDaysSinceLastVisit,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCustomerCoalitionBalances(
    String coalitionId,
  ) async {
    final data = await _CompanyServerCore.get(
      '/customer/coalitions/$coalitionId/balances',
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyCustomerCoalitions() async {
    final data = await _CompanyServerCore.get('/customer/coalitions/mine', auth: true);
    final rows = (data as Map)['coalitions'] as List? ?? const <dynamic>[];
    return rows.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> redeemCoalitionGift({
    required String giftId,
    required String fulfillerMerchantId,
  }) async {
    final data = await _CompanyServerCore.post('/customer/coalitions/redeem-gift', {
      'gift_id': giftId,
      'fulfiller_merchant_id': fulfillerMerchantId,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCoalitionImpactReport(
    String coalitionId,
  ) async {
    final data = await _CompanyServerCore.get(
      '/merchant/coalitions/$coalitionId/gift-impact',
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getBrandCoalitions() async {
    final data = await _CompanyServerCore.get('/brand/coalitions', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> joinBrandCoalition(
    String coalitionId,
  ) async {
    final data = await _CompanyServerCore.post(
      '/brand/coalitions/$coalitionId/join',
      const {},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getBrandCoalitionClearinghouse() async {
    final data = await _CompanyServerCore.get('/brand/coalitions/clearinghouse', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createBrandSettlementDispute({
    required String claimId,
    required String reason,
  }) async {
    final data = await _CompanyServerCore.post('/brand/coalitions/clearinghouse/disputes', {
      'claimId': claimId,
      'reason': reason,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }
}
