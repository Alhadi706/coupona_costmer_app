part of '../company_server_service.dart';

class _CompanyServerAuth {
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String role,
    String? phone,
    String? fullName,
    String? gender,
    String? birthDate,
    double? locationLat,
    double? locationLng,
  }) async {
    final data = await _CompanyServerCore.post('/auth/signup', {
      'email': email,
      'password': password,
      'role': role,
      'phone': phone,
      'fullName': fullName,
      'gender': gender,
      'birthDate': birthDate,
      'locationLat': locationLat,
      'locationLng': locationLng,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _CompanyServerCore.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> ownerLogin({
    required String email,
    required String password,
  }) async {
    final data = await _CompanyServerCore.post('/auth/owner/login', {
      'email': email,
      'password': password,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> ownerVerify({
    required String challengeId,
    required String code,
  }) async {
    final data = await _CompanyServerCore.post('/auth/owner/verify', {
      'challengeId': challengeId,
      'code': code,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> ownerResend({
    required String challengeId,
  }) async {
    final data = await _CompanyServerCore.post('/auth/owner/resend', {'challengeId': challengeId});
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _CompanyServerCore.patch('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String email,
    String? fullName,
  }) async {
    final data = await _CompanyServerCore.patch('/auth/update-profile', {
      'email': email,
      'fullName': fullName ?? '',
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    await _CompanyServerCore.post('/users/$userId/profile', payload, auth: true);
  }

  static Future<Map<String, dynamic>> getMyRoles() async {
    final data = await _CompanyServerCore.get('/roles/me', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getMyCustomerLocation() async {
    final data = await _CompanyServerCore.get('/customer/location/me', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateMyCustomerLocation({
    required double latitude,
    required double longitude,
  }) async {
    final data = await _CompanyServerCore.post('/customer/location/me', {
      'latitude': latitude,
      'longitude': longitude,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> requestMerchantRole({
    required String businessName,
    required String commercialRegistration,
    required String planType,
    required String phone,
    required double locationLat,
    required double locationLng,
    String? locationAddress,
  }) async {
    final data = await _CompanyServerCore.post('/roles/merchant/request', {
      'businessName': businessName,
      'commercialRegistration': commercialRegistration,
      'planType': planType,
      'phone': phone,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationAddress': locationAddress,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> requestBrandRole({
    required String businessName,
    required String commercialRegistration,
    required String planType,
    required String phone,
    required double locationLat,
    required double locationLng,
    String? locationAddress,
  }) async {
    final data = await _CompanyServerCore.post('/roles/brand/request', {
      'businessName': businessName,
      'commercialRegistration': commercialRegistration,
      'planType': planType,
      'phone': phone,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationAddress': locationAddress,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getMyRoleRequests() async {
    final data = await _CompanyServerCore.get('/roles/requests/me', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await _CompanyServerCore.get('/users', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    if (userId.trim().isEmpty) return null;
    final data = await _CompanyServerCore.get('/users/$userId', auth: true);
    if (data == null) return null;
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final data = await _CompanyServerCore.get('/blocks', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> blockUser(String userId) async {
    await _CompanyServerCore.post('/users/$userId/block', <String, dynamic>{}, auth: true);
  }

  static Future<void> unblockUser(String userId) async {
    await _CompanyServerCore.post('/users/$userId/unblock', <String, dynamic>{}, auth: true);
  }
}
