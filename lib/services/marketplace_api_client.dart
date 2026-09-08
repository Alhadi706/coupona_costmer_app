import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_session.dart';

/// Thrown when the customer session is missing/expired locally or rejected by
/// the API (401/403). UI layers should route the user to login when catching
/// this exception.
class MarketplaceSessionExpiredException implements Exception {
  const MarketplaceSessionExpiredException();

  @override
  String toString() => 'unauthorized';
}

/// Dedicated networking client for the customer marketplace ("سوق الزبائن").
///
/// Single responsibility: JWT header propagation + the community-offers
/// endpoints. All requests attach the active session token as
/// `Authorization: Bearer <token>`; a missing or rejected token clears the
/// stored session and throws [MarketplaceSessionExpiredException] so callers
/// can route to login instead of failing silently.
class MarketplaceApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'COMPANY_API_BASE_URL',
    defaultValue: 'http://154.12.117.175:3002/api',
  );

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    return base.replace(queryParameters: query);
  }

  /// Builds JSON headers with the active session token attached.
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AppSession.token();
    if (token == null || token.isEmpty) {
      throw const MarketplaceSessionExpiredException();
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _decode(
    http.Response response,
    String op,
    String path,
  ) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Server rejected the token: drop the stale session so callers and
      // guards observe a signed-out state immediately.
      await AppSession.clear();
      throw const MarketplaceSessionExpiredException();
    }
    if (response.statusCode >= 400) {
      throw StateError(
        '$op $path failed (${response.statusCode}): ${response.body}',
      );
    }
    final body = response.body.trim();
    return body.isEmpty ? null : jsonDecode(body);
  }

  /// Fetches the marketplace feed (`GET /customer/community-offers`).
  static Future<List<Map<String, dynamic>>> fetchOffers({
    String? category,
    String? visibilityScope,
    String? status,
    String? search,
    bool? myOnly,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (visibilityScope != null && visibilityScope.isNotEmpty) {
      queryParams['visibility_scope'] = visibilityScope;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (myOnly == true) queryParams['my_only'] = 'true';

    final response = await http.get(
      _uri('/customer/community-offers', queryParams),
      headers: await _authHeaders(),
    );
    final data = await _decode(response, 'GET', '/customer/community-offers');
    if (data is Map && data['offers'] is List) {
      return (data['offers'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Publishes a new offer (`POST /customer/community-offers`).
  static Future<Map<String, dynamic>> createOffer({
    required String title,
    required String description,
    required String category,
    List<String>? images,
    double priceLyd = 0.0,
    bool acceptsPointsTrade = false,
    String visibilityScope = 'PUBLIC_COMMUNITY',
  }) async {
    final response = await http.post(
      _uri('/customer/community-offers'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'images': images ?? <String>[],
        'price_lyd': priceLyd,
        'accepts_points_trade': acceptsPointsTrade,
        'visibility_scope': visibilityScope,
      }),
    );
    final data = await _decode(response, 'POST', '/customer/community-offers');
    if (data is Map && data['offer'] is Map) {
      return (data['offer'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  /// Updates an offer status (`PATCH /customer/community-offers/:id/status`).
  static Future<Map<String, dynamic>> updateOfferStatus({
    required String offerId,
    required String status,
  }) async {
    final response = await http.patch(
      _uri('/customer/community-offers/$offerId/status'),
      headers: await _authHeaders(),
      body: jsonEncode({'status': status}),
    );
    final data = await _decode(
      response,
      'PATCH',
      '/customer/community-offers/$offerId/status',
    );
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  /// Opens a chat with the seller (`POST /customer/community-offers/:id/contact`).
  static Future<Map<String, dynamic>> contactSeller({
    required String offerId,
  }) async {
    final response = await http.post(
      _uri('/customer/community-offers/$offerId/contact'),
      headers: await _authHeaders(),
      body: jsonEncode(<String, dynamic>{}),
    );
    final data = await _decode(
      response,
      'POST',
      '/customer/community-offers/$offerId/contact',
    );
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }
}
