part of '../company_server_service.dart';

class _CompanyServerMerchantBrand {
  static Future<List<Map<String, dynamic>>> getMerchantBranches() async {
    final data = await _CompanyServerCore.get('/merchant/branches', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> createMerchantBranch({
    required String name,
    String? address,
    String? location,
    required double latitude,
    required double longitude,
    String? category,
    String? workingHours,
    String? status,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/branches', {
      'name': name,
      'address': address,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'workingHours': workingHours,
      'status': status,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> updateMerchantBranch({
    required String branchId,
    String? name,
    String? address,
    String? workingHours,
    String? phone,
    String? status,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    await _CompanyServerCore.patch('/merchant/branches/$branchId', {
      'name': name,
      'address': address,
      'workingHours': workingHours,
      'phone': phone,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
    }, auth: true);
  }

  static Future<Map<String, dynamic>> addMerchantBranchManager({
    required String branchId,
    required String userId,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/branches/$branchId/managers', {
      'userId': userId,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateBranchManagerPermissions({
    required String branchId,
    required String userId,
    bool? canReviewInvoices,
    bool? canCreateOffers,
    bool? canManageGroup,
    bool? canViewReports,
    bool? canViewSettlements,
    bool? canAddCashiers,
    bool? canReplyReports,
    bool? canEditPointValue,
  }) async {
    final data = await _CompanyServerCore.patch(
      '/merchant/branches/$branchId/managers/$userId/permissions',
      {
        'canReviewInvoices': canReviewInvoices,
        'canCreateOffers': canCreateOffers,
        'canManageGroup': canManageGroup,
        'canViewReports': canViewReports,
        'canViewSettlements': canViewSettlements,
        'canAddCashiers': canAddCashiers,
        'canReplyReports': canReplyReports,
        'canEditPointValue': canEditPointValue,
      },
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> bindCashierToBranch({
    required String branchId,
    String? cashierUserId,
    String? cashierPhone,
  }) async {
    if ((cashierUserId ?? '').trim().isEmpty &&
        (cashierPhone ?? '').trim().isEmpty) {
      throw StateError('cashierUserId_or_cashierPhone_required');
    }
    final data = await _CompanyServerCore.post('/merchant/cashiers/bind', {
      'branchId': branchId,
      'cashierUserId': cashierUserId,
      'cashierPhone': cashierPhone,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantTeam() async {
    final data = await _CompanyServerCore.get('/merchant/team', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> inviteMerchantTeamMember({
    required String branchId,
    required String roleType,
    required String emailOrPhone,
    Map<String, bool> permissions = const <String, bool>{},
  }) async {
    final data = await _CompanyServerCore.post('/merchant/team/invitations', {
      'branchId': branchId,
      'roleType': roleType,
      'emailOrPhone': emailOrPhone,
      'permissions': permissions,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>>
  getMyMerchantTeamInvitations() async {
    final data = await _CompanyServerCore.get('/team/invitations/mine', auth: true);
    return (data as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> respondToMerchantTeamInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    final data = await _CompanyServerCore.post('/team/invitations/$invitationId/respond', {
      'action': accept ? 'accept' : 'reject',
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> revokeMerchantTeamAccess({
    required String roleType,
    required String branchId,
    required String userId,
  }) async {
    await _CompanyServerCore.delete('/merchant/team/$roleType/$branchId/$userId', auth: true);
  }

  static Future<void> cancelMerchantTeamInvitation(String invitationId) async {
    await _CompanyServerCore.delete('/merchant/team/invitations/$invitationId', auth: true);
  }

  static Future<Map<String, dynamic>> getManagerScope() async {
    final data = await _CompanyServerCore.get('/merchant/manager/scope', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>>
  getManagerInvoiceReviewQueue() async {
    final data = await _CompanyServerCore.get(
      '/merchant/manager/invoices/review-queue',
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> getMerchantLoyaltyHealth() async {
    final data = await _CompanyServerCore.get('/merchant/loyalty-health', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantAnalytics({
    String range = '30d',
    String? branchId,
  }) async {
    final query = <String, dynamic>{'range': range};
    if ((branchId ?? '').trim().isNotEmpty) {
      query['branchId'] = branchId!.trim();
    }
    final data = await _CompanyServerCore.get('/merchant/analytics', query: query, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantProfile() async {
    final data = await _CompanyServerCore.get('/merchant/profile', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> addBrandTeamMember({
    required String userId,
    bool canManageProducts = false,
    bool canViewGeoDistribution = false,
  }) async {
    final data = await _CompanyServerCore.post('/brand/team-members', {
      'userId': userId,
      'canManageProducts': canManageProducts,
      'canViewGeoDistribution': canViewGeoDistribution,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getBrandTeam() async {
    final data = await _CompanyServerCore.get('/brand/team', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> inviteBrandTeamMember({
    required String emailOrPhone,
    required bool canManageProducts,
    required bool canViewGeoDistribution,
    bool canManageCommunity = false,
    bool canManageCampaigns = false,
    bool canManageAds = false,
    bool canReplyMessages = false,
    bool canViewAnalytics = false,
    bool canRedeemRewards = false,
  }) async {
    final data = await _CompanyServerCore.post('/brand/team/invitations', {
      'emailOrPhone': emailOrPhone,
      'permissions': {
        'canManageProducts': canManageProducts,
        'canViewGeoDistribution': canViewGeoDistribution,
        'canManageCommunity': canManageCommunity,
        'canManageCampaigns': canManageCampaigns,
        'canManageAds': canManageAds,
        'canReplyMessages': canReplyMessages,
        'canViewAnalytics': canViewAnalytics,
        'canRedeemRewards': canRedeemRewards,
      },
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> respondToBrandTeamInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    final data = await _CompanyServerCore.post('/brand/team/invitations/$invitationId/respond', {
      'action': accept ? 'accept' : 'reject',
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyBrandTeamInvitations() async {
    final data = await _CompanyServerCore.get('/brand/team/invitations/mine', auth: true);
    return (data as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> revokeBrandTeamMember(String userId) async {
    await _CompanyServerCore.delete('/brand/team/members/$userId', auth: true);
  }

  static Future<Map<String, dynamic>> createBrandProduct({
    required String name,
    String? imageUrl,
    String? barcode,
  }) async {
    final data = await _CompanyServerCore.post('/brand/products', {
      'name': name,
      'imageUrl': imageUrl,
      'barcode': barcode,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateBrandProduct({
    required String productId,
    required String name,
    String? imageUrl,
    String? barcode,
  }) async {
    final data = await _CompanyServerCore.patch('/brand/products/$productId', {
      'name': name,
      'imageUrl': imageUrl,
      'barcode': barcode,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> deactivateBrandProduct(
    String productId,
  ) async {
    final data = await _CompanyServerCore.delete('/brand/products/$productId', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getBrandProfile() async {
    final data = await _CompanyServerCore.get('/brand/profile', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getBrandProducts() async {
    final data = await _CompanyServerCore.get('/brand/products', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMerchantProducts() async {
    final data = await _CompanyServerCore.get('/merchant/products', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> createMerchantProduct({
    required String name,
    String? imageUrl,
    double? price,
    String? description,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/products', {
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'description': description,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateMerchantProduct({
    required String productId,
    String? name,
    String? imageUrl,
    double? price,
    String? description,
    bool? isActive,
  }) async {
    final data = await _CompanyServerCore.patch('/merchant/products/$productId', {
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'description': description,
      'isActive': isActive,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateMerchantCashbackPercentage({
    required double cashbackPercentage,
  }) async {
    final data = await _CompanyServerCore.put('/merchant/settings', {
      'cashback_percentage': cashbackPercentage,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantSettings() async {
    final data = await _CompanyServerCore.get('/merchant/settings', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> setMerchantPointValue({
    required double pointValue,
  }) async {
    final data = await _CompanyServerCore.patch('/merchant/settings/point-value', {
      'pointValue': pointValue,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMerchantCustomerOffers() async {
    try {
      final data = await _CompanyServerCore.get('/merchant/customer-offers', auth: true);
      if (data is Map && data['offers'] is List) {
        return (data['offers'] as List)
            .map((offer) => (offer as Map).cast<String, dynamic>())
            .toList();
      }
      if (data is List) {
        return data
            .map((offer) => (offer as Map).cast<String, dynamic>())
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMerchantCashiers() async {
    try {
      final data = await _CompanyServerCore.get('/merchant/cashiers', auth: true);
      return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUnassignedCashiers() async {
    try {
      final data = await _CompanyServerCore.get('/merchant/cashiers/unassigned', auth: true);
      return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateMerchantProfile({
    String? businessName,
    String? category,
    String? phone,
    String? logoUrl,
    String? commercialRegistration,
    String? taxNumber,
  }) async {
    final data = await _CompanyServerCore.patch('/merchant/profile', {
      if (businessName != null) 'businessName': businessName,
      if (category != null) 'category': category,
      if (phone != null) 'phone': phone,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (commercialRegistration != null) 'commercialRegistration': commercialRegistration,
      if (taxNumber != null) 'taxNumber': taxNumber,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> assignCashierToBranch({
    required String branchId,
    required String cashierUserId,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/cashiers/assign', {
      'branchId': branchId,
      'cashierUserId': cashierUserId,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getBrandAnalytics({
    String range = '30d',
    String? storeId,
    String? product,
    String? region,
  }) async {
    final data = await _CompanyServerCore.get(
      '/brand/analytics',
      query: {
        'range': range,
        if ((storeId ?? '').isNotEmpty) 'storeId': storeId,
        if ((product ?? '').isNotEmpty) 'product': product,
        if ((region ?? '').isNotEmpty) 'region': region,
      },
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getStores() async {
    final data = await _CompanyServerCore.get('/stores', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> getStoreDetails(String merchantId) async {
    final data = await _CompanyServerCore.get('/stores/$merchantId/details', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getCustomerBanners() async {
    try {
      final data = await _CompanyServerCore.get('/customer/banners', auth: true);
      return (data as List)
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getApprovedBillboardAds() async {
    final offers = await _CompanyServerRewards.getOffers();
    return offers
        .where((offer) {
          final status = (offer['lifecycleStatus'] ?? '')
              .toString()
              .toLowerCase();
          final image = (offer['imageUrl'] ?? offer['image'] ?? '').toString();
          final endDate = DateTime.tryParse(
            (offer['endDate'] ?? '').toString(),
          );
          return status == 'active' &&
              image.isNotEmpty &&
              (endDate == null || endDate.isAfter(DateTime.now()));
        })
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> getBillboardAds() async {
    try {
      final data = await _CompanyServerCore.get('/billboard-ads', auth: true);
      final apiUri = Uri.parse(_CompanyServerCore._baseUrl);
      final ads = (data as List).map((e) {
        final ad = (e as Map).cast<String, dynamic>();
        final imageUrl = (ad['imageUrl'] ?? '').toString();
        if (imageUrl.startsWith('/')) {
          ad['imageUrl'] = apiUri
              .replace(path: imageUrl, query: null)
              .toString();
        }
        return ad;
      }).toList();
      if (ads.isNotEmpty) return ads;
    } catch (_) {
      // Older deployed API instances may not have the dedicated feed yet.
    }

    final offers = await _CompanyServerRewards.getOffers();
    return offers
        .where((offer) {
          final status = (offer['lifecycleStatus'] ?? '')
              .toString()
              .toLowerCase();
          final image = (offer['imageUrl'] ?? offer['image'] ?? '').toString();
          return status == 'active' && image.isNotEmpty;
        })
        .toList(growable: false);
  }

  static Future<void> trackBillboardImpression(String adId) async {
    await _CompanyServerCore.post(
      '/billboard-ads/$adId/impression',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<Map<String, dynamic>> trackBillboardClick(String adId) async {
    final data = await _CompanyServerCore.post(
      '/billboard-ads/$adId/click',
      <String, dynamic>{},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<String?> uploadImageBytes(
    List<int> bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final data = await _CompanyServerCore.post('/uploads/image', {
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    }, auth: true);
    return (data as Map)['url']?.toString();
  }

  static Future<Map<String, dynamic>> checkMerchantTokenBalance({
    required String merchantId,
  }) async {
    final data = await _CompanyServerCore.get('/merchant/tokens/$merchantId/status', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> recordLocalOnlyPoints({
    required String merchantId,
    required int points,
    required String receiptId,
    String? customerUserId,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/tokens/local-points', {
      'merchantId': merchantId,
      'points': points,
      'receiptId': receiptId,
      'customerUserId': customerUserId,
      'is_local_only': true,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> redeemLocalOnlyPoints({
    required String merchantId,
    required int points,
    required String cashierQrCode,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/tokens/local-redeem', {
      'merchantId': merchantId,
      'points': points,
      'cashierQrCode': cashierQrCode,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> rechargeMerchantTokens({
    required String merchantId,
    required double amount,
  }) async {
    final data = await _CompanyServerCore.post('/merchant/tokens/recharge', {
      'merchantId': merchantId,
      'amount': amount,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getCounts() async {
    final userId = await AppSession.userId();
    final query = (userId == null || userId.isEmpty)
        ? null
        : <String, dynamic>{'userId': userId};
    final data = await _CompanyServerCore.get('/stats/counts', query: query, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMerchantTopCustomers({
    String? merchantName,
    int limit = 20,
  }) async {
    final data = await _CompanyServerCore.get(
      '/merchant/customers/top',
      query: {
        if (merchantName != null && merchantName.trim().isNotEmpty)
          'merchantName': merchantName,
        'limit': limit,
      },
      auth: true,
    );
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

  static Future<Map<String, dynamic>> getMerchantPendingPoints() async {
    final data = await _CompanyServerCore.get('/merchant/wallet/pending-points', auth: true);
    return (data as Map).cast<String, dynamic>();
  }
}
