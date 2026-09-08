part of '../company_server_service.dart';

class _CompanyServerCore {
  static const String _baseUrl = String.fromEnvironment(
    'COMPANY_API_BASE_URL',
    defaultValue: 'http://154.12.117.175:3002/api',
  );

  static const String _aiBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: _baseUrl,
  );

  static final Map<String, List<Map<String, dynamic>>> _localGroupReplies =
      <String, List<Map<String, dynamic>>>{};
  static final Map<String, Map<String, int>> _localGroupReactions =
      <String, Map<String, int>>{};

  static String _groupMessageKey(String groupId, String messageId) =>
      '$groupId::$messageId';

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    return base.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  static Uri _aiUri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('$_aiBaseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    return base.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await AppSession.token();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static dynamic _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = false,
  }) async {
    final response = await http.get(
      _uri(path, query),
      headers: await _headers(auth: auth),
    );
    if (response.statusCode >= 400) {
      throw StateError(
        'GET $path failed (${response.statusCode}): ${response.body}',
      );
    }
    return _decode(response);
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> payload, {
    bool auth = false,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw StateError(
        'POST $path failed (${response.statusCode}): ${response.body}',
      );
    }
    return _decode(response);
  }

  static Future<dynamic> put(
    String path,
    Map<String, dynamic> payload, {
    bool auth = false,
  }) async {
    final response = await http.put(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw StateError(
        'PUT $path failed (${response.statusCode}): ${response.body}',
      );
    }
    return _decode(response);
  }

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> payload, {
    bool auth = false,
  }) async {
    final response = await http.patch(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw StateError(
        'PATCH $path failed (${response.statusCode}): ${response.body}',
      );
    }
    return _decode(response);
  }

  static Future<dynamic> delete(String path, {bool auth = false}) async {
    final response = await http.delete(
      _uri(path),
      headers: await _headers(auth: auth),
    );
    if (response.statusCode >= 400) {
      throw StateError(
        'DELETE $path failed (${response.statusCode}): ${response.body}',
      );
    }
    return _decode(response);
  }
}
