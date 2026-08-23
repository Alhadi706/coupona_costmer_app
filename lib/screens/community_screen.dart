import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_session.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_chat_bubble.dart';

class CommunityScreen extends StatefulWidget {
  final bool embedded;
  final String? initialGroupId;

  const CommunityScreen({super.key, this.initialGroupId}) : embedded = false;

  const CommunityScreen.embedded({super.key, this.initialGroupId}) : embedded = true;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        TabBarView(
          controller: _tabController,
          children: [
            _GroupsTab(initialGroupId: widget.initialGroupId),
            _PrivateChatsTab(),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TabBar(
              controller: _tabController,
              labelColor: kTeal,
              unselectedLabelColor: kInk,
              indicatorColor: kGold,
              indicatorWeight: 3,
              indicator: BoxDecoration(
                color: kGold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              tabs: [
                Tab(text: 'groups_tab'.tr(), icon: const Icon(Icons.groups)),
                Tab(text: 'private_messages_tab'.tr(), icon: const Icon(Icons.chat)),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('community_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: body,
    );
  }
}

enum _GroupSort { mostMembers, alphabetic }

class _GroupsTab extends StatefulWidget {
  final String? initialGroupId;

  const _GroupsTab({this.initialGroupId});

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  final TextEditingController _searchController = TextEditingController();
  _GroupSort _sort = _GroupSort.mostMembers;
  bool _openedInitialGroup = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateGroupDialog() async {
    String? groupName;
    String? groupDescription;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('create_new_group'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'group_name'.tr(),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => groupName = val,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'group_description_optional'.tr(),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => groupDescription = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (groupName != null && groupName!.trim().isNotEmpty) {
                Navigator.pop(context);
                try {
                  await CompanyServerService.createGroup(
                    name: groupName!.trim(),
                    description: groupDescription?.trim(),
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('group_created_success'.tr())),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('group_create_error'.tr(namedArgs: {'error': error.toString()}))),
                  );
                }
              }
            },
            child: Text('create'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _poll<List<Map<String, dynamic>>>(CompanyServerService.getGroups),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = List<Map<String, dynamic>>.from(snapshot.data!);
        final query = _searchController.text.trim().toLowerCase();
        final filteredGroups = groups.where((group) {
          final name = (group['name'] ?? '').toString().toLowerCase();
          final desc = (group['desc'] ?? '').toString().toLowerCase();
          return query.isEmpty || name.contains(query) || desc.contains(query);
        }).toList();

        if (!_openedInitialGroup && widget.initialGroupId != null) {
          final initialGroup = groups.cast<Map<String, dynamic>?>().firstWhere(
            (group) => group?['id']?.toString() == widget.initialGroupId,
            orElse: () => null,
          );
          if (initialGroup != null) {
            _openedInitialGroup = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => _GroupChatScreen(
                    groupId: widget.initialGroupId!,
                    groupName: (initialGroup['name'] ?? '').toString(),
                    ownerUserId: (initialGroup['ownerUserId'] ?? '').toString(),
                  )));
            });
          }
        }

        filteredGroups.sort((a, b) {
          if (_sort == _GroupSort.alphabetic) {
            final aName = (a['name'] ?? '').toString();
            final bName = (b['name'] ?? '').toString();
            return aName.compareTo(bName);
          }
          final aMembers = int.tryParse((a['members'] ?? 0).toString()) ?? 0;
          final bMembers = int.tryParse((b['members'] ?? 0).toString()) ?? 0;
          return bMembers.compareTo(aMembers);
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'community_groups'.tr(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGold, width: 1.2),
              ),
              child: Text(
                'إعلانات الأفراد مثبتة أولاً',
                style: kBodyTextStyle(weight: FontWeight.w600, color: kInk),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: kSand,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'groups_count_value'.tr(namedArgs: {'count': '${groups.length}'}),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openCreateGroupDialog,
                      icon: const Icon(Icons.add),
                      label: Text('create_group'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: kWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'search_group_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('most_members'.tr()),
                  selected: _sort == _GroupSort.mostMembers,
                  onSelected: (_) => setState(() => _sort = _GroupSort.mostMembers),
                ),
                ChoiceChip(
                  label: Text('alphabetical_order'.tr()),
                  selected: _sort == _GroupSort.alphabetic,
                  onSelected: (_) => setState(() => _sort = _GroupSort.alphabetic),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filteredGroups.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('no_group_results'.tr()),
                ),
              )
            else
              ...filteredGroups.map((group) {
                final id = (group['id'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.groups, color: kTeal, size: 32),
                    title: Text(
                      (group['name'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text((group['desc'] ?? '').toString()),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people, size: 18, color: Colors.grey),
                        Text('${group['members'] ?? 0}'),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _GroupChatScreen(
                            groupId: id,
                            groupName: (group['name'] ?? '').toString(),
                            ownerUserId: (group['ownerUserId'] ?? '').toString(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            const SizedBox(height: 26),
          ],
        );
      },
    );
  }
}

class _GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String ownerUserId;

  const _GroupChatScreen({required this.groupId, required this.groupName, this.ownerUserId = ''});

  @override
  State<_GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<_GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _replyToMessageId;
  String _replyToPreview = '';
  final Map<String, Map<String, int>> _localReactionCounts = <String, Map<String, int>>{};
  final Map<String, String> _myLocalReaction = <String, String>{};
  List<Map<String, dynamic>> _latestMessages = const <Map<String, dynamic>>[];
  bool _sending = false;
  XFile? _postImage;
  Map<String, dynamic>? _postPoll;

  Future<void> _pickPostImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => _postImage = image);
  }

  Future<void> _createPoll() async {
    String question = '';
    final options = <String>['', ''];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('community_create_poll'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'community_poll_question'.tr()),
                  onChanged: (value) => question = value,
                ),
                ...options.asMap().entries.map((entry) => TextField(
                  decoration: InputDecoration(labelText: 'community_poll_option'.tr(namedArgs: {'number': '${entry.key + 1}'})),
                  onChanged: (value) => options[entry.key] = value,
                )),
                TextButton.icon(
                  onPressed: () => setDialogState(() => options.add('')),
                  icon: const Icon(Icons.add),
                  label: Text('community_add_poll_option'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () {
                final cleanOptions = options.map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
                if (question.trim().isEmpty || cleanOptions.length < 2) return;
                setState(() => _postPoll = {'question': question.trim(), 'options': cleanOptions});
                Navigator.of(dialogContext).pop();
              },
              child: Text('create'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _broadcast() async {
    String text = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('community_broadcast_title'.tr()),
        content: TextField(
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: 'community_broadcast_hint'.tr()),
          onChanged: (value) => text = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (text.trim().isEmpty) return;
              await CompanyServerService.broadcastToCommunity(groupId: widget.groupId, text: text.trim());
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text('send'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _moderateMessage(Map<String, dynamic> message, {required bool delete}) async {
    final messageId = (message['id'] ?? '').toString();
    if (messageId.isEmpty) return;
    try {
      if (delete) {
        await CompanyServerService.deleteGroupMessage(groupId: widget.groupId, messageId: messageId);
      } else {
        await CompanyServerService.pinGroupMessage(groupId: widget.groupId, messageId: messageId);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showMembers() async {
    try {
      final members = await CompanyServerService.getCommunityGroupMembers(widget.groupId);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final userId = (member['userId'] ?? '').toString();
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text((member['label'] ?? userId).toString()),
                trailing: userId == widget.ownerUserId ? null : IconButton(
                  tooltip: 'ban'.tr(),
                  icon: const Icon(Icons.block, color: Colors.red),
                  onPressed: () async {
                    await CompanyServerService.banCommunityGroupMember(groupId: widget.groupId, userId: userId);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _postImage == null && _postPoll == null || _sending) return;

    setState(() => _sending = true);
    try {
      if (_replyToMessageId != null) {
        try {
          await CompanyServerService.sendGroupMessageReply(
            groupId: widget.groupId,
            messageId: _replyToMessageId!,
            text: text,
          );
        } catch (_) {
          // Fallback for environments where reply endpoint is not deployed yet.
          await CompanyServerService.sendGroupMessage(
            groupId: widget.groupId,
            text: '[reply:${_replyToMessageId!}] $text',
          );
        }
      } else {
        String? imageUrl;
        if (_postImage != null) {
          imageUrl = await CompanyServerService.uploadImageBytes(
            await _postImage!.readAsBytes(),
            mimeType: _postImage!.mimeType ?? 'image/jpeg',
          );
        }
        await CompanyServerService.sendGroupMessage(
          groupId: widget.groupId,
          text: text,
          imageUrl: imageUrl,
          poll: _postPoll,
        );
      }
      _messageController.clear();
      _postImage = null;
      _postPoll = null;
      _replyToMessageId = null;
      _replyToPreview = '';
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('send_message_error'.tr(namedArgs: {'error': error.toString()}))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _setReplyTarget(Map<String, dynamic> message) {
    final senderName = (message['senderName'] ?? 'user_generic'.tr()).toString();
    final text = (message['text'] ?? '').toString();
    setState(() {
      _replyToMessageId = (message['id'] ?? '').toString();
      _replyToPreview = '$senderName: $text';
    });
  }

  Future<void> _reactToMessage(Map<String, dynamic> message, String emoji) async {
    final messageId = (message['id'] ?? '').toString();
    if (messageId.isEmpty) return;
    try {
      await CompanyServerService.reactToGroupMessage(
        groupId: widget.groupId,
        messageId: messageId,
        emoji: emoji,
      );
      if (mounted) setState(() {});
    } catch (_) {
      // Fallback for environments where reactions endpoint is not deployed yet.
      final existing = _myLocalReaction[messageId];
      if (existing == emoji) {
        return;
      }
      if (existing != null) {
        final oldMap = _localReactionCounts[messageId];
        if (oldMap != null && (oldMap[existing] ?? 0) > 0) {
          oldMap[existing] = (oldMap[existing] ?? 1) - 1;
        }
      }
      final map = _localReactionCounts.putIfAbsent(messageId, () => <String, int>{});
      map[emoji] = (map[emoji] ?? 0) + 1;
      _myLocalReaction[messageId] = emoji;
      if (mounted) {
        setState(() {});
      }
    }
  }

  int _fallbackReplyCount(String messageId) {
    if (messageId.isEmpty) return 0;
    final marker = '[reply:$messageId]';
    return _latestMessages.where((m) {
      final text = (m['text'] ?? '').toString().trim();
      return text.startsWith(marker);
    }).length;
  }

  String _cleanMessageText(Map<String, dynamic> message) {
    final raw = (message['text'] ?? '').toString();
    final replyPattern = RegExp(r'^\[reply:[^\]]+\]\s*');
    return raw.replaceFirst(replyPattern, '');
  }

  Future<void> _openPrivateChatForMember({
    required String targetUserId,
    required String title,
  }) async {
    if (targetUserId.isEmpty) return;
    try {
      final chats = await CompanyServerService.getPrivateChats();
      final existing = chats.where((chat) {
        final participant = (chat['participantId'] ?? '').toString();
        return participant == targetUserId;
      }).toList();

      Map<String, dynamic> chat;
      if (existing.isNotEmpty) {
        chat = existing.first;
      } else {
        chat = await CompanyServerService.createPrivateChat(
          targetUserId: targetUserId,
          title: title,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrivateChatScreen(
            chatId: (chat['id'] ?? '').toString(),
            title: title,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('open_private_chat_error'.tr(namedArgs: {'error': error.toString()}))),
      );
    }
  }

  Future<void> _showReplies(Map<String, dynamic> message) async {
    final messageId = (message['id'] ?? '').toString();
    if (messageId.isEmpty) return;
    List<Map<String, dynamic>> replies;
    try {
      replies = await CompanyServerService.getGroupMessageReplies(
        groupId: widget.groupId,
        messageId: messageId,
      );
    } catch (_) {
      final marker = '[reply:$messageId]';
      replies = _latestMessages.where((m) {
        final text = (m['text'] ?? '').toString().trim();
        return text.startsWith(marker);
      }).map((m) {
        return <String, dynamic>{
          'id': m['id'],
          'senderName': m['senderName'],
          'text': _cleanMessageText(m),
        };
      }).toList();
    }
    final localReplies = List<Map<String, dynamic>>.from(replies);
    if (!mounted) return;
    final replyController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        final maxHeight = MediaQuery.of(context).size.height * 0.75;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: SizedBox(
              height: maxHeight,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  Future<void> submitReply() async {
                    final text = replyController.text.trim();
                    if (text.isEmpty) return;
                    await CompanyServerService.sendGroupMessageReply(
                      groupId: widget.groupId,
                      messageId: messageId,
                      text: text,
                    );
                    List<Map<String, dynamic>> refreshed;
                    try {
                      refreshed = await CompanyServerService.getGroupMessageReplies(
                        groupId: widget.groupId,
                        messageId: messageId,
                      );
                    } catch (_) {
                      final marker = '[reply:$messageId]';
                      await CompanyServerService.sendGroupMessage(
                        groupId: widget.groupId,
                        text: '$marker $text',
                      );
                      refreshed = _latestMessages.where((m) {
                        final raw = (m['text'] ?? '').toString().trim();
                        return raw.startsWith(marker);
                      }).map((m) {
                        return <String, dynamic>{
                          'id': m['id'],
                          'senderName': m['senderName'],
                          'text': _cleanMessageText(m),
                        };
                      }).toList();
                    }
                    replyController.clear();
                    setSheetState(() {
                      localReplies
                        ..clear()
                        ..addAll(refreshed);
                    });
                    if (mounted) setState(() {});
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (message['text'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Expanded(
                          child: localReplies.isEmpty
                              ? Center(
                                  child: Text(
                                    'no_replies_yet'.tr(),
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: localReplies.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final reply = localReplies[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${(reply['senderName'] ?? 'user_generic'.tr()).toString()}: ${(reply['text'] ?? '').toString()}',
                                        style: const TextStyle(color: Colors.black87),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: replyController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'write_reply_hint'.tr(),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => submitReply(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: submitReply,
                            child: Text('send_reply'.tr()),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    replyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: kTealDark,
      ),
      body: FutureBuilder<String?>(
        future: AppSession.userId(),
        builder: (context, userSnap) {
          final currentUserId = userSnap.data ?? '';
          final canModerate = widget.ownerUserId.isNotEmpty && widget.ownerUserId == currentUserId;
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _poll<List<Map<String, dynamic>>>(
                    () => CompanyServerService.getGroupMessages(widget.groupId),
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    _latestMessages = messages;
                    if (messages.isEmpty) {
                      return Center(child: Text('no_messages_yet'.tr()));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        final senderId = (msg['senderId'] ?? '').toString();
                        final isMe = senderId.isNotEmpty && senderId == currentUserId;
                        final senderName = (msg['senderName'] ?? 'user_generic'.tr()).toString();
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment:
                                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              KupunaChatBubble(
                                message: _cleanMessageText(msg),
                                isCurrentUser: isMe,
                                senderKind: ChatSenderKind.customer,
                              ),
                              if ((msg['imageUrl'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network((msg['imageUrl']).toString(), width: 220, height: 130, fit: BoxFit.cover),
                                  ),
                                ),
                              if (msg['poll'] is Map)
                                Card(
                                  margin: const EdgeInsets.only(top: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${(msg['poll'] as Map)['question'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ...(((msg['poll'] as Map)['options'] as List?) ?? const []).map((option) {
                                          final poll = msg['poll'] as Map;
                                          final votes = poll['votes'] is Map ? poll['votes'] as Map : const {};
                                          final optionText = option.toString();
                                          return TextButton(
                                            onPressed: () async {
                                              await CompanyServerService.voteOnCommunityPoll(groupId: widget.groupId, messageId: (msg['id'] ?? '').toString(), option: optionText);
                                              if (mounted) setState(() {});
                                            },
                                            child: Align(alignment: AlignmentDirectional.centerStart, child: Text('$optionText  (${votes[optionText] ?? 0})')),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(
                                    senderName,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
                                  children: [
                                    ActionChip(
                                      avatar: const Icon(Icons.reply, size: 14),
                                      label: Text('reply'.tr(), style: const TextStyle(fontSize: 12)),
                                      onPressed: () => _setReplyTarget(msg),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (canModerate) ...[
                                      ActionChip(
                                        avatar: const Icon(Icons.push_pin_outlined, size: 14),
                                        label: Text('pin'.tr(), style: const TextStyle(fontSize: 12)),
                                        onPressed: () => _moderateMessage(msg, delete: false),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      ActionChip(
                                        avatar: const Icon(Icons.delete_outline, size: 14),
                                        label: Text('delete'.tr(), style: const TextStyle(fontSize: 12)),
                                        onPressed: () => _moderateMessage(msg, delete: true),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                    ActionChip(
                                      avatar: const Text('👍', style: TextStyle(fontSize: 12)),
                                      label: Text('like'.tr(), style: const TextStyle(fontSize: 12)),
                                      onPressed: () => _reactToMessage(msg, '👍'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    ActionChip(
                                      avatar: const Text('❤️', style: TextStyle(fontSize: 12)),
                                      label: Text('heart'.tr(), style: const TextStyle(fontSize: 12)),
                                      onPressed: () => _reactToMessage(msg, '❤️'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (!isMe)
                                      ActionChip(
                                        avatar: const Icon(Icons.mail_outline, size: 14),
                                        label: Text('message'.tr(), style: const TextStyle(fontSize: 12)),
                                        onPressed: () => _openPrivateChatForMember(
                                          targetUserId: senderId,
                                          title: senderName,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ActionChip(
                                      avatar: const Icon(Icons.forum_outlined, size: 14),
                                      label: Text(
                                        'replies_count'.tr(namedArgs: {
                                          'count': (() {
                                          final serverCount = int.tryParse((msg['repliesCount'] ?? 0).toString()) ?? 0;
                                          final localCount = _fallbackReplyCount((msg['id'] ?? '').toString());
                                          return (serverCount > localCount ? serverCount : localCount).toString();
                                        })(),
                                        }),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () => _showReplies(msg),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                if (((int.tryParse((msg['reactionsCount'] ?? 0).toString()) ?? 0) +
                                        ((_localReactionCounts[(msg['id'] ?? '').toString()]?['👍'] ?? 0)) +
                                        ((_localReactionCounts[(msg['id'] ?? '').toString()]?['❤️'] ?? 0))) >
                                    0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '👍 ${((int.tryParse((msg['thumbsUpCount'] ?? 0).toString()) ?? 0) + (_localReactionCounts[(msg['id'] ?? '').toString()]?['👍'] ?? 0)).toString()}   ❤️ ${((int.tryParse((msg['heartCount'] ?? 0).toString()) ?? 0) + (_localReactionCounts[(msg['id'] ?? '').toString()]?['❤️'] ?? 0)).toString()}',
                                      style: TextStyle(
                                        color: isMe ? Colors.white70 : Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_replyToMessageId != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kSand,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kLine),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text('reply_to_value'.tr(namedArgs: {'value': _replyToPreview}))),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _replyToMessageId = null;
                                        _replyToPreview = '';
                                      });
                                    },
                                    child: Text('cancel'.tr()),
                                  ),
                                ],
                              ),
                            ),
                          TextField(
                            controller: _messageController,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'write_message_hint'.tr(),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_postImage != null || _postPoll != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  if (_postImage != null) const Icon(Icons.image_outlined, size: 16, color: kTeal),
                                  if (_postImage != null) const SizedBox(width: 4),
                                  if (_postImage != null) Expanded(child: Text(_postImage!.name, overflow: TextOverflow.ellipsis)),
                                  if (_postPoll != null) Text('community_poll_ready'.tr(), style: const TextStyle(color: kTeal)),
                                  IconButton(onPressed: () => setState(() { _postImage = null; _postPoll = null; }), icon: const Icon(Icons.close, size: 18)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: _pickPostImage, icon: const Icon(Icons.image_outlined), tooltip: 'community_attach_image'.tr()),
                    IconButton(onPressed: _createPoll, icon: const Icon(Icons.poll_outlined), tooltip: 'community_create_poll'.tr()),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kTeal),
                      onPressed: _sending ? null : _sendMessage,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
              if (canModerate)
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: _showMembers,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text('manage_group_members'.tr()),
                    ),
                  ),
                ),
              if (canModerate)
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: _broadcast,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text('community_broadcast_title'.tr()),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PrivateChatsTab extends StatefulWidget {
  const _PrivateChatsTab();

  @override
  State<_PrivateChatsTab> createState() => _PrivateChatsTabState();
}

class _PrivateChatsTabState extends State<_PrivateChatsTab> {
  Future<void> _hideChat(String chatId) async {
    await CompanyServerService.hidePrivateChat(chatId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('chat_hidden'.tr())),
    );
    setState(() {});
  }

  Future<void> _deleteChat(String chatId) async {
    await CompanyServerService.deletePrivateChat(chatId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('chat_deleted_from_list'.tr())),
    );
    setState(() {});
  }

  Future<void> _muteChat(String chatId) async {
    await CompanyServerService.mutePrivateChat(chatId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('chat_muted'.tr())),
    );
    setState(() {});
  }

  Future<void> _unmuteChat(String chatId) async {
    await CompanyServerService.unmutePrivateChat(chatId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('chat_unmuted'.tr())),
    );
    setState(() {});
  }

  Future<void> _pinChat(String chatId) async {
    await CompanyServerService.pinPrivateChat(chatId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('chat_pinned'.tr())),
    );
    setState(() {});
  }

  Future<void> _unpinChat(String chatId) async {
    await CompanyServerService.unpinPrivateChat(chatId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('chat_unpinned'.tr())),
    );
    setState(() {});
  }

  Future<void> _blockUser(String userId, String label) async {
    await CompanyServerService.blockUser(userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('user_blocked'.tr(namedArgs: {'label': label}))),
    );
    setState(() {});
  }

  Future<void> _showBlockedUsersDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('manage_blocked_users'.tr()),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: CompanyServerService.getBlockedUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final blocked = snapshot.data!;
                if (blocked.isEmpty) {
                  return Text('no_blocked_users'.tr());
                }
                return SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: blocked.length,
                    itemBuilder: (context, index) {
                      final item = blocked[index];
                      final userId = (item['blockedUserId'] ?? '').toString();
                      final email = (item['blockedEmail'] ?? userId).toString();
                      return ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text(email),
                        trailing: TextButton(
                          onPressed: () async {
                            try {
                              await CompanyServerService.unblockUser(userId);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('user_unblocked'.tr(namedArgs: {'email': email}))),
                              );
                              setState(() {});
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('unblock_error'.tr(namedArgs: {'error': error.toString()}))),
                              );
                            }
                          },
                          child: Text('unblock'.tr()),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('close'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _poll<List<Map<String, dynamic>>>(CompanyServerService.getPrivateChats),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return Center(child: Text('no_private_chats_yet'.tr()));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'private_messages_tab'.tr(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showBlockedUsersDialog,
                  icon: const Icon(Icons.block),
                  label: Text('blocked_users'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...chats.map((chat) {
              final chatId = (chat['id'] ?? '').toString();
              final title = (chat['title'] ?? 'private_chat_default_title'.tr()).toString();
              final preview = (chat['lastMessage'] ?? 'no_messages_yet'.tr()).toString();
              final peerUserId = (chat['peerUserId'] ?? '').toString();
              final peerEmail = (chat['peerEmail'] ?? '').toString();
              final blockedByMe = chat['blockedByMe'] == true;
              final isMuted = chat['isMuted'] == true;
              final isPinned = chat['isPinned'] == true;
              final unreadCount = (chat['unreadCount'] is num)
                  ? (chat['unreadCount'] as num).toInt()
                  : int.tryParse((chat['unreadCount'] ?? '0').toString()) ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.person, color: kTeal),
                  title: Row(
                    children: [
                      Expanded(child: Text(title)),
                      if (isPinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.push_pin, size: 16, color: Colors.orange),
                        ),
                      if (isMuted)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.volume_off, size: 16, color: Colors.grey),
                        ),
                    ],
                  ),
                  subtitle: Text(preview),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          try {
                            if (value == 'hide') {
                              await _hideChat(chatId);
                            } else if (value == 'delete') {
                              await _deleteChat(chatId);
                            } else if (value == 'block') {
                              if (peerUserId.isEmpty) {
                                throw StateError('peer_user_not_found'.tr());
                              }
                              await _blockUser(peerUserId, peerEmail.isNotEmpty ? peerEmail : title);
                            } else if (value == 'mute') {
                              await _muteChat(chatId);
                            } else if (value == 'unmute') {
                              await _unmuteChat(chatId);
                            } else if (value == 'pin') {
                              await _pinChat(chatId);
                            } else if (value == 'unpin') {
                              await _unpinChat(chatId);
                            }
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('action_failed'.tr(namedArgs: {'error': error.toString()}))),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: isPinned ? 'unpin' : 'pin',
                            child: Text(isPinned ? 'unpin_chat'.tr() : 'pin_chat'.tr()),
                          ),
                          PopupMenuItem<String>(
                            value: isMuted ? 'unmute' : 'mute',
                            child: Text(isMuted ? 'unmute_chat'.tr() : 'mute_notifications'.tr()),
                          ),
                          PopupMenuItem<String>(
                            value: 'hide',
                            child: Text('hide_chat'.tr()),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('delete_from_list'.tr()),
                          ),
                          if (!blockedByMe)
                            PopupMenuItem<String>(
                              value: 'block',
                              child: Text('block_user'.tr()),
                            ),
                        ],
                      ),
                    ],
                  ),
                  onTap: blockedByMe
                      ? null
                      : () async {
                          try {
                            await CompanyServerService.markPrivateChatAsRead(chatId);
                          } catch (_) {}
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PrivateChatScreen(
                                chatId: chatId,
                                title: title,
                              ),
                            ),
                          );
                        },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key, required this.chatId, required this.title});

  final String chatId;
  final String title;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    try {
      await CompanyServerService.markPrivateChatAsRead(widget.chatId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendPrivateMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await CompanyServerService.sendPrivateMessage(chatId: widget.chatId, text: text);
      _messageController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('send_message_error'.tr(namedArgs: {'error': error.toString()}))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AppSession.userId(),
      builder: (context, userSnap) {
        final currentUserId = userSnap.data ?? '';
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: kTealDark,
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _poll<List<Map<String, dynamic>>>(
                    () => CompanyServerService.getPrivateMessages(widget.chatId),
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    _markAsRead();
                    if (messages.isEmpty) {
                      return Center(child: Text('no_messages_yet'.tr()));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final senderId = (msg['senderId'] ?? '').toString();
                        final isMe = senderId.isNotEmpty && senderId == currentUserId;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: KupunaChatBubble(
                            message: (msg['text'] ?? '').toString(),
                            isCurrentUser: isMe,
                            senderKind: ChatSenderKind.customer,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendPrivateMessage(),
                        decoration: InputDecoration(
                          hintText: 'write_private_message_hint'.tr(),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sending ? null : _sendPrivateMessage,
                      style: ElevatedButton.styleFrom(backgroundColor: kTeal),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Stream<T> _poll<T>(Future<T> Function() loader) {
  return Stream.periodic(const Duration(seconds: 4))
      .asyncMap((_) => loader())
      .startWithFuture(loader());
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
