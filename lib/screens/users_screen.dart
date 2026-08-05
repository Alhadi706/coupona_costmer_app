import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';
import 'community_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = fetchUsers();
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      return CompanyServerService.getUsers();
    } catch (e) {
      debugPrint('Fetch users error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('users_list_title'.tr()),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('generic_error_with_message'.tr(namedArgs: {'error': '${snapshot.error}'})));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('no_users_found'.tr()));
          } else {
            final users = snapshot.data!;
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = (user['id'] ?? '').toString();
                final email = (user['email'] ?? '').toString();
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(user['full_name'] ?? user['email'] ?? 'بدون اسم'),
                  subtitle: Text(user['email'] ?? ''),
                  trailing: TextButton.icon(
                    onPressed: userId.isEmpty
                        ? null
                        : () async {
                            try {
                              final chats = await CompanyServerService.getPrivateChats();
                              final existing = chats.firstWhere(
                                (chat) => (chat['peerUserId'] ?? '').toString() == userId,
                                orElse: () => <String, dynamic>{},
                              );
                              if (existing.isNotEmpty) {
                                if (!context.mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PrivateChatScreen(
                                      chatId: (existing['id'] ?? '').toString(),
                                      title: email.isEmpty ? 'private_chat_default_title'.tr() : email,
                                    ),
                                  ),
                                );
                                return;
                              }

                              final created = await CompanyServerService.createPrivateChat(
                                targetUserId: userId,
                                title: email.isEmpty ? 'محادثة خاصة' : email,
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PrivateChatScreen(
                                    chatId: (created['id'] ?? '').toString(),
                                    title: email.isEmpty ? 'private_chat_default_title'.tr() : email,
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('open_private_chat_error'.tr(namedArgs: {'error': error.toString()}))),
                              );
                            }
                          },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text('message'.tr()),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

