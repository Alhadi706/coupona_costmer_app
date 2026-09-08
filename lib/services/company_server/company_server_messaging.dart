part of 'package:coupona_app/services/company_server_service.dart';

class _CompanyServerMessaging {
  static Future<List<Map<String, dynamic>>> getPrivateChats() async {
    final userId = await AppSession.userId();
    if (userId == null || userId.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final data = await CompanyServerService.get('/private-chats', query: {'userId': userId}, auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> createPrivateChat({
    required String targetUserId,
    required String title,
  }) async {
    final data = await CompanyServerService.post('/private-chats', {
      'targetUserId': targetUserId,
      'title': title,
    }, auth: true);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> hidePrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/hide', <String, dynamic>{}, auth: true);
  }

  static Future<void> unhidePrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/unhide', <String, dynamic>{}, auth: true);
  }

  static Future<void> deletePrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/delete', <String, dynamic>{}, auth: true);
  }

  static Future<void> restorePrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/restore', <String, dynamic>{}, auth: true);
  }

  static Future<void> mutePrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/mute', <String, dynamic>{}, auth: true);
  }

  static Future<void> unmutePrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/unmute', <String, dynamic>{}, auth: true);
  }

  static Future<void> pinPrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/pin', <String, dynamic>{}, auth: true);
  }

  static Future<void> unpinPrivateChat(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/unpin', <String, dynamic>{}, auth: true);
  }

  static Future<void> markPrivateChatAsRead(String chatId) async {
    await CompanyServerService.post('/private-chats/$chatId/read', <String, dynamic>{}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getPrivateMessages(String chatId) async {
    final data = await CompanyServerService.get('/private-chats/$chatId/messages', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> sendPrivateMessage({
    required String chatId,
    required String text,
  }) async {
    await CompanyServerService.post('/private-chats/$chatId/messages', {'text': text}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final data = await CompanyServerService.get('/blocks', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> blockUser(String userId) async {
    await CompanyServerService.post('/users/$userId/block', <String, dynamic>{}, auth: true);
  }

  static Future<void> unblockUser(String userId) async {
    await CompanyServerService.post('/users/$userId/unblock', <String, dynamic>{}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await CompanyServerService.get('/users', auth: true);
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    if (userId.trim().isEmpty) return null;
    final data = await CompanyServerService.get('/users/$userId', auth: true);
    if (data == null) return null;
    return (data as Map).cast<String, dynamic>();
  }
}
