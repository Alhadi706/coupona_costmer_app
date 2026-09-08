part of '../company_server_service.dart';

class _CompanyServerCommunity {
  static Future<List<Map<String, dynamic>>> getGroups() async {
    final data = await _CompanyServerCore.get('/community/groups/my', auth: true);
    return (data as List).map((e) {
      final row = (e as Map).cast<String, dynamic>();
      return <String, dynamic>{
        ...row,
        'desc': row['description'] ?? '',
        'members': row['membersCount'] ?? 0,
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
  }) async {
    final data = await _CompanyServerCore.post('/groups', {
      'name': name,
      'description': description,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getGroupMessages(
    String groupId,
  ) async {
    final data = await _CompanyServerCore.get('/community/groups/$groupId/messages', auth: true);
    final rows = (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    for (final row in rows) {
      final messageId = (row['id'] ?? '').toString();
      if (messageId.isEmpty) continue;
      final key = _CompanyServerCore._groupMessageKey(groupId, messageId);
      final localRepliesCount = _CompanyServerCore._localGroupReplies[key]?.length ?? 0;
      final localReactions = _CompanyServerCore._localGroupReactions[key] ?? const <String, int>{};
      final localThumbs = localReactions['👍'] ?? 0;
      final localHearts = localReactions['❤️'] ?? 0;

      final serverReplies =
          int.tryParse((row['repliesCount'] ?? 0).toString()) ?? 0;
      final serverThumbs =
          int.tryParse((row['thumbsUpCount'] ?? 0).toString()) ?? 0;
      final serverHearts =
          int.tryParse((row['heartCount'] ?? 0).toString()) ?? 0;
      final serverReactions =
          int.tryParse((row['reactionsCount'] ?? 0).toString()) ?? 0;

      row['repliesCount'] = serverReplies + localRepliesCount;
      row['thumbsUpCount'] = serverThumbs + localThumbs;
      row['heartCount'] = serverHearts + localHearts;
      row['reactionsCount'] = serverReactions + localThumbs + localHearts;
    }
    return rows;
  }

  static Future<void> sendGroupMessage({
    required String groupId,
    required String text,
    String? imageUrl,
    Map<String, dynamic>? poll,
  }) async {
    await _CompanyServerCore.post('/community/groups/$groupId/messages', {
      'text': text,
      'imageUrl': imageUrl,
      'poll': poll,
    }, auth: true);
  }

  static Future<Map<String, dynamic>> broadcastToCommunity({
    required String groupId,
    required String text,
  }) async {
    final data = await _CompanyServerCore.post('/community/groups/$groupId/broadcast', {
      'text': text,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> voteOnCommunityPoll({
    required String groupId,
    required String messageId,
    required String option,
  }) async {
    await _CompanyServerCore.post('/community/groups/$groupId/messages/$messageId/poll-vote', {
      'option': option,
    }, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getGroupMessageReplies({
    required String groupId,
    required String messageId,
  }) async {
    try {
      final data = await _CompanyServerCore.get(
        '/community/groups/$groupId/messages/$messageId/replies',
        auth: true,
      );
      final serverRows = (data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final key = _CompanyServerCore._groupMessageKey(groupId, messageId);
      final localRows =
          _CompanyServerCore._localGroupReplies[key] ?? const <Map<String, dynamic>>[];
      return <Map<String, dynamic>>[...serverRows, ...localRows];
    } catch (_) {
      final key = _CompanyServerCore._groupMessageKey(groupId, messageId);
      return List<Map<String, dynamic>>.from(
        _CompanyServerCore._localGroupReplies[key] ?? const <Map<String, dynamic>>[],
      );
    }
  }

  static Future<void> sendGroupMessageReply({
    required String groupId,
    required String messageId,
    required String text,
  }) async {
    try {
      await _CompanyServerCore.post('/community/groups/$groupId/messages/$messageId/replies', {
        'text': text,
      }, auth: true);
    } catch (_) {
      final key = _CompanyServerCore._groupMessageKey(groupId, messageId);
      final replies = _CompanyServerCore._localGroupReplies.putIfAbsent(
        key,
        () => <Map<String, dynamic>>[],
      );
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
      await _CompanyServerCore.post('/community/groups/$groupId/messages/$messageId/reactions', {
        'emoji': emoji,
      }, auth: true);
    } catch (_) {
      final key = _CompanyServerCore._groupMessageKey(groupId, messageId);
      final reactionMap = _CompanyServerCore._localGroupReactions.putIfAbsent(
        key,
        () => <String, int>{},
      );
      reactionMap[emoji] = (reactionMap[emoji] ?? 0) + 1;
    }
  }

  static Future<void> pinGroupMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _CompanyServerCore.post(
      '/community/groups/$groupId/messages/$messageId/pin',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> deleteGroupMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _CompanyServerCore.delete('/community/groups/$groupId/messages/$messageId', auth: true);
  }

  static Future<List<Map<String, dynamic>>> getCommunityGroupMembers(
    String groupId,
  ) async {
    final data = await _CompanyServerCore.get('/community/groups/$groupId/members', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> banCommunityGroupMember({
    required String groupId,
    required String userId,
    String? reason,
  }) async {
    await _CompanyServerCore.post('/community/groups/$groupId/members/$userId/ban', {
      'reason': reason,
    }, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getCustomerCommunityOffers({
    String? category,
    String? visibilityScope,
    String? status,
    String? search,
    bool? myOnly,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (visibilityScope != null && visibilityScope.isNotEmpty) queryParams['visibility_scope'] = visibilityScope;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (myOnly == true) queryParams['my_only'] = 'true';

    final data = await _CompanyServerCore.get('/customer/community-offers', query: queryParams, auth: true);
    if (data is Map && data['offers'] is List) {
      return (data['offers'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createCustomerCommunityOffer({
    required String title,
    required String description,
    required String category,
    List<String>? images,
    double priceLyd = 0.0,
    bool acceptsPointsTrade = false,
    String visibilityScope = 'PUBLIC_COMMUNITY',
  }) async {
    final data = await _CompanyServerCore.post('/customer/community-offers', {
      'title': title,
      'description': description,
      'category': category,
      'images': images ?? [],
      'price_lyd': priceLyd,
      'accepts_points_trade': acceptsPointsTrade,
      'visibility_scope': visibilityScope,
    }, auth: true);
    if (data is Map && data['offer'] is Map) {
      return (data['offer'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateCommunityOfferStatus({
    required String offerId,
    required String status,
  }) async {
    final data = await _CompanyServerCore.patch('/customer/community-offers/$offerId/status', {
      'status': status,
    }, auth: true);
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return {};
  }

  static Future<Map<String, dynamic>> contactCommunityOfferSeller({
    required String offerId,
  }) async {
    final data = await _CompanyServerCore.post('/customer/community-offers/$offerId/contact', {}, auth: true);
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> getPrivateChats() async {
    final userId = await AppSession.userId();
    if (userId == null || userId.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final data = await _CompanyServerCore.get(
      '/private-chats',
      query: {'userId': userId},
      auth: true,
    );
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<Map<String, dynamic>> createPrivateChat({
    required String targetUserId,
    required String title,
  }) async {
    final data = await _CompanyServerCore.post('/private-chats', {
      'targetUserId': targetUserId,
      'title': title,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> hidePrivateChat(String chatId) async {
    await _CompanyServerCore.post('/private-chats/$chatId/hide', <String, dynamic>{}, auth: true);
  }

  static Future<void> unhidePrivateChat(String chatId) async {
    await _CompanyServerCore.post(
      '/private-chats/$chatId/unhide',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> deletePrivateChat(String chatId) async {
    await _CompanyServerCore.post(
      '/private-chats/$chatId/delete',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> restorePrivateChat(String chatId) async {
    await _CompanyServerCore.post(
      '/private-chats/$chatId/restore',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> mutePrivateChat(String chatId) async {
    await _CompanyServerCore.post('/private-chats/$chatId/mute', <String, dynamic>{}, auth: true);
  }

  static Future<void> unmutePrivateChat(String chatId) async {
    await _CompanyServerCore.post(
      '/private-chats/$chatId/unmute',
      <String, dynamic>{},
      auth: true,
    );
  }

  static Future<void> pinPrivateChat(String chatId) async {
    await _CompanyServerCore.post('/private-chats/$chatId/pin', <String, dynamic>{}, auth: true);
  }

  static Future<void> unpinPrivateChat(String chatId) async {
    await _CompanyServerCore.post('/private-chats/$chatId/unpin', <String, dynamic>{}, auth: true);
  }

  static Future<void> markPrivateChatAsRead(String chatId) async {
    await _CompanyServerCore.post('/private-chats/$chatId/read', <String, dynamic>{}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getPrivateMessages(
    String chatId,
  ) async {
    final data = await _CompanyServerCore.get('/private-chats/$chatId/messages', auth: true);
    return (data as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static Future<void> sendPrivateMessage({
    required String chatId,
    required String text,
  }) async {
    await _CompanyServerCore.post('/private-chats/$chatId/messages', {'text': text}, auth: true);
  }
}
