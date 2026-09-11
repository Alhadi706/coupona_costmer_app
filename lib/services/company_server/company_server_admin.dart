part of '../company_server_service.dart';

class _CompanyServerAdmin {
  static Future<List<Map<String, dynamic>>> getAdminRoleRequests({
    String status = 'pending_admin_review',
  }) async {
    final data = await _CompanyServerCore.get(
      '/admin/role-requests',
      query: {'status': status},
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> approveAdminRoleRequest(
    String requestId,
  ) async {
    final data = await _CompanyServerCore.post(
      '/admin/role-requests/$requestId/approve',
      <String, dynamic>{},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> rejectAdminRoleRequest(
    String requestId, {
    String reason = 'Rejected by admin',
  }) async {
    final data = await _CompanyServerCore.post('/admin/role-requests/$requestId/reject', {
      'reason': reason,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getAdminPeerAds({
    String status = 'pending_admin_review',
  }) async {
    final data = await _CompanyServerCore.get(
      '/admin/peer-ads',
      query: {'status': status},
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> approveAdminPeerAd(String adId) async {
    final data = await _CompanyServerCore.post(
      '/admin/peer-ads/$adId/approve',
      <String, dynamic>{},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> rejectAdminPeerAd(
    String adId, {
    String reason = 'Rejected by admin',
  }) async {
    final data = await _CompanyServerCore.post('/admin/peer-ads/$adId/reject', {
      'reason': reason,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getAdminDashboardSummary() async {
    final data = await _CompanyServerCore.get('/admin/dashboard/summary', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getAdminOperationsQueue({
    int limit = 25,
  }) async {
    final data = await _CompanyServerCore.get(
      '/admin/operations/queue',
      query: {'limit': limit},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getAdminSubscriptions({
    String? roleType,
    String? status,
  }) async {
    final query = <String, dynamic>{
      if (roleType != null) 'roleType': roleType,
      if (status != null) 'status': status,
    };
    final data = await _CompanyServerCore.get('/admin/subscriptions', query: query, auth: true);
    return (data as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> activateAdminSubscription(
    String id,
  ) async {
    final data = await _CompanyServerCore.post(
      '/admin/subscriptions/$id/activate-now',
      const {},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> expireAdminSubscriptionTrial(
    String id,
  ) async {
    final data = await _CompanyServerCore.post(
      '/admin/subscriptions/$id/expire-trial-now',
      const {},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> endAdminSubscriptionGrace(
    String id,
  ) async {
    final data = await _CompanyServerCore.post(
      '/admin/subscriptions/$id/end-grace-now',
      const {},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMerchantEscrowSummary() async {
    final data = await _CompanyServerCore.get('/merchant/escrow/summary', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> transitionAdminReport(
    String reportId, {
    required String to,
    bool rewardGranted = false,
  }) async {
    final data = await _CompanyServerCore.post('/reports/$reportId/transition', {
      'to': to,
      'rewardGranted': rewardGranted,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getAdminBillboardAds() async {
    final data = await _CompanyServerCore.get('/admin/billboard-ads', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> approveAdminBillboardAd(
    String adId,
  ) async {
    final data = await _CompanyServerCore.post(
      '/admin/billboard-ads/$adId/approve',
      <String, dynamic>{},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> rejectAdminBillboardAd(
    String adId, {
    String reason = 'Rejected by admin',
  }) async {
    final data = await _CompanyServerCore.post('/admin/billboard-ads/$adId/reject', {
      'reason': reason,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>>
  getAdminPublicCoalitionMembershipRequests({
    String status = 'pending_admin_review',
  }) async {
    final data = await _CompanyServerCore.get(
      '/admin/public-coalition/membership-requests',
      query: {'status': status},
      auth: true,
    );
    return (data as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> approvePublicCoalitionMembershipRequest(
    String requestId, {
    required String adminMessage,
    String? paymentUrl,
  }) async {
    final data = await _CompanyServerCore.post(
      '/admin/public-coalition/membership-requests/$requestId/approve',
      {'adminMessage': adminMessage, 'paymentUrl': paymentUrl},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> rejectPublicCoalitionMembershipRequest(
    String requestId, {
    required String reason,
  }) async {
    final data = await _CompanyServerCore.post(
      '/admin/public-coalition/membership-requests/$requestId/reject',
      {'reason': reason},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> activatePublicCoalitionMembershipRequest(
    String requestId, {
    required String paymentReference,
    required num goldPoints,
  }) async {
    final data = await _CompanyServerCore.post(
      '/admin/public-coalition/membership-requests/$requestId/activate',
      {'paymentReference': paymentReference, 'goldPoints': goldPoints},
      auth: true,
    );
    return (data as Map).cast<String, dynamic>();
  }
}
