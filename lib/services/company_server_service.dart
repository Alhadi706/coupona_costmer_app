import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_session.dart';

class CompanyServerService {
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
      queryParameters: query.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  static Uri _aiUri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('$_aiBaseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    return base.replace(
      queryParameters: query.map((key, value) => MapEntry(key, value.toString())),
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

  static Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = false}) async {
    final response = await http.get(_uri(path, query), headers: await _headers(auth: auth));
    if (response.statusCode >= 400) {
      throw StateError('GET $path failed (${response.statusCode}): ${response.body}');
    }
    return _decode(response);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> payload, {bool auth = false}) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw StateError('POST $path failed (${response.statusCode}): ${response.body}');
    }
    return _decode(response);
  }

  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String role,
  }) async {
    final data = await post('/auth/signup', {
      'email': email,
      'password': password,
      'role': role,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final data = await post('/auth/login', {
      'email': email,
      'password': password,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getOffers({String? category}) async {
    final data = await get('/offers', query: category == null ? null : {'category': category}, auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> createOffer(Map<String, dynamic> payload) async {
    await post('/offers', payload, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getStores() async {
    final data = await get('/stores', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<List<Map<String, dynamic>>> getGroups() async {
    final data = await get('/groups', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
  }) async {
    final data = await post('/groups', {
      'name': name,
      'description': description,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getGroupMessages(String groupId) async {
    final data = await get('/groups/$groupId/messages', auth: true);
    final rows = (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    for (final row in rows) {
      final messageId = (row['id'] ?? '').toString();
      if (messageId.isEmpty) continue;
      final key = _groupMessageKey(groupId, messageId);
      final localRepliesCount = _localGroupReplies[key]?.length ?? 0;
      final localReactions = _localGroupReactions[key] ?? const <String, int>{};
      final localThumbs = localReactions['👍'] ?? 0;
      final localHearts = localReactions['❤️'] ?? 0;

      final serverReplies = int.tryParse((row['repliesCount'] ?? 0).toString()) ?? 0;
      final serverThumbs = int.tryParse((row['thumbsUpCount'] ?? 0).toString()) ?? 0;
      final serverHearts = int.tryParse((row['heartCount'] ?? 0).toString()) ?? 0;
      final serverReactions = int.tryParse((row['reactionsCount'] ?? 0).toString()) ?? 0;

      row['repliesCount'] = serverReplies + localRepliesCount;
      row['thumbsUpCount'] = serverThumbs + localThumbs;
      row['heartCount'] = serverHearts + localHearts;
      row['reactionsCount'] = serverReactions + localThumbs + localHearts;
    }
    return rows;
  }

  static Future<void> sendGroupMessage({required String groupId, required String text}) async {
    await post('/groups/$groupId/messages', {'text': text}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getGroupMessageReplies({
    required String groupId,
    required String messageId,
  }) async {
    try {
      final data = await get('/groups/$groupId/messages/$messageId/replies', auth: true);
      final serverRows = (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
      final key = _groupMessageKey(groupId, messageId);
      final localRows = _localGroupReplies[key] ?? const <Map<String, dynamic>>[];
      return <Map<String, dynamic>>[...serverRows, ...localRows];
    } catch (_) {
      final key = _groupMessageKey(groupId, messageId);
      return List<Map<String, dynamic>>.from(_localGroupReplies[key] ?? const <Map<String, dynamic>>[]);
    }
  }

  static Future<void> sendGroupMessageReply({
    required String groupId,
    required String messageId,
    required String text,
  }) async {
    try {
      await post('/groups/$groupId/messages/$messageId/replies', {'text': text}, auth: true);
    } catch (_) {
      final key = _groupMessageKey(groupId, messageId);
      final replies = _localGroupReplies.putIfAbsent(key, () => <Map<String, dynamic>>[]);
      final senderName = (await AppSession.email()) ?? 'مستخدم';
      replies.add(<String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'senderId': (await AppSession.userId()) ?? '',
        'senderName': senderName,
        'text': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<void> reactToGroupMessage({
    required String groupId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await post('/groups/$groupId/messages/$messageId/reactions', {'emoji': emoji}, auth: true);
    } catch (_) {
      final key = _groupMessageKey(groupId, messageId);
      final reactionMap = _localGroupReactions.putIfAbsent(key, () => <String, int>{});
      reactionMap[emoji] = (reactionMap[emoji] ?? 0) + 1;
    }
  }

  static Future<List<Map<String, dynamic>>> getPrivateChats() async {
    final userId = await AppSession.userId();
    if (userId == null || userId.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final data = await get('/private-chats', query: {'userId': userId}, auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> createPrivateChat({
    required String targetUserId,
    required String title,
  }) async {
    final data = await post('/private-chats', {
      'targetUserId': targetUserId,
      'title': title,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> hidePrivateChat(String chatId) async {
    await post('/private-chats/$chatId/hide', <String, dynamic>{}, auth: true);
  }

  static Future<void> unhidePrivateChat(String chatId) async {
    await post('/private-chats/$chatId/unhide', <String, dynamic>{}, auth: true);
  }

  static Future<void> deletePrivateChat(String chatId) async {
    await post('/private-chats/$chatId/delete', <String, dynamic>{}, auth: true);
  }

  static Future<void> restorePrivateChat(String chatId) async {
    await post('/private-chats/$chatId/restore', <String, dynamic>{}, auth: true);
  }

  static Future<void> mutePrivateChat(String chatId) async {
    await post('/private-chats/$chatId/mute', <String, dynamic>{}, auth: true);
  }

  static Future<void> unmutePrivateChat(String chatId) async {
    await post('/private-chats/$chatId/unmute', <String, dynamic>{}, auth: true);
  }

  static Future<void> pinPrivateChat(String chatId) async {
    await post('/private-chats/$chatId/pin', <String, dynamic>{}, auth: true);
  }

  static Future<void> unpinPrivateChat(String chatId) async {
    await post('/private-chats/$chatId/unpin', <String, dynamic>{}, auth: true);
  }

  static Future<void> markPrivateChatAsRead(String chatId) async {
    await post('/private-chats/$chatId/read', <String, dynamic>{}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getPrivateMessages(String chatId) async {
    final data = await get('/private-chats/$chatId/messages', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> sendPrivateMessage({required String chatId, required String text}) async {
    await post('/private-chats/$chatId/messages', {'text': text}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final data = await get('/blocks', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> blockUser(String userId) async {
    await post('/users/$userId/block', <String, dynamic>{}, auth: true);
  }

  static Future<void> unblockUser(String userId) async {
    await post('/users/$userId/unblock', <String, dynamic>{}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await get('/users', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    if (userId.trim().isEmpty) return null;
    final data = await get('/users/$userId', auth: true);
    if (data == null) return null;
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getRewards() async {
    final data = await get('/rewards', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    await post('/users/$userId/profile', payload, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getActivityLogs({
    required String customerEmail,
  }) async {
    final data = await get(
      '/activity-logs',
      query: {'customerEmail': customerEmail},
      auth: true,
    );
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> ensureAccountingDocuments() async {
    await post('/wallet/ensure', <String, dynamic>{}, auth: true);
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final data = await get('/wallet', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getPointAccount() async {
    final data = await get('/wallet/points', auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getLedgerEntries({int limit = 50}) async {
    final data = await get('/wallet/ledger', query: {'limit': limit}, auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> applyCashbackFromPurchase({
    required double purchaseAmount,
    required String reference,
  }) async {
    await post('/wallet/cashback', {
      'purchaseAmount': purchaseAmount,
      'reference': reference,
    }, auth: true);
  }

  static Future<void> redeemPoints({
    required int points,
    required String reference,
  }) async {
    await post('/wallet/redeem', {
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
  }) async {
    try {
      final data = await post('/invoices/scan', {
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
      }, auth: true);
      if (data == null) return null;
      return (data as Map).cast<String, dynamic>();
    } catch (_) {
      // Keeps client flow usable even if backend has not yet been upgraded.
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
        _aiUri('/invoices/analyze-ai'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
        'rawText': rawText,
        'imageBase64': imageBase64,
        'mimeType': mimeType ?? 'image/jpeg',
        }),
      );
      if (response.statusCode >= 400) {
        return null;
      }
      final data = _decode(response);
      if (data == null) return null;
      return (data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getMerchantTopCustomers({
    String? merchantName,
    int limit = 20,
  }) async {
    final data = await get(
      '/merchant/customers/top',
      query: {
        if (merchantName != null && merchantName.trim().isNotEmpty) 'merchantName': merchantName,
        'limit': limit,
      },
      auth: true,
    );
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>?> getOfferLifecycle(String offerId) async {
    final data = await get('/offers/$offerId/lifecycle', auth: true);
    if (data == null) return null;
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> ensureOfferLifecycleDefaults(String offerId) async {
    await post('/offers/$offerId/lifecycle/ensure-defaults', <String, dynamic>{}, auth: true);
  }

  static Future<void> transitionOfferLifecycle({
    required String offerId,
    required String targetStatus,
    String? reason,
  }) async {
    await post('/offers/$offerId/lifecycle/transition', {
      'targetStatus': targetStatus,
      'reason': reason,
    }, auth: true);
  }

  static Future<void> syncOfferTemporalStatus(String offerId) async {
    await post('/offers/$offerId/lifecycle/sync-temporal', <String, dynamic>{}, auth: true);
  }

  static Future<Map<String, dynamic>> getCounts() async {
    final userId = await AppSession.userId();
    final query = (userId == null || userId.isEmpty)
        ? null
        : <String, dynamic>{'userId': userId};
    final data = await get('/stats/counts', query: query, auth: true);
    return (data as Map).cast<String, dynamic>();
  }
}
