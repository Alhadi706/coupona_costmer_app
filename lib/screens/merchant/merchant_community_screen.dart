import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/community.dart';
import '../../services/firestore/community_repository.dart';
import '../../services/user_merchant_link_service.dart';

class MerchantCommunityScreen extends StatefulWidget {
  final String merchantId;
  const MerchantCommunityScreen({super.key, required this.merchantId});

  @override
  State<MerchantCommunityScreen> createState() =>
      _MerchantCommunityScreenState();
}

class _MerchantCommunityScreenState extends State<MerchantCommunityScreen> {
  late final CommunityRepository _communityRepository;

  @override
  void initState() {
    super.initState();
    _communityRepository = CommunityRepository();
  }

  Future<void> _createRoom() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('merchant_community_add_room'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'merchant_community_room_name'.tr(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'merchant_community_room_description'.tr(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('create'.tr()),
          ),
        ],
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty) {
      final docRef = await _communityRepository.createRoom(
        merchantId: widget.merchantId,
        name: titleController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );
      await _seedExistingCustomers(docRef.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_community_room_created'.tr())),
      );
    }
  }

  Future<void> _seedExistingCustomers(String communityId) async {
    try {
      final customers =
          await UserMerchantLinkService.fetchDistinctCustomerIdsForMerchant(
            widget.merchantId,
          );
      if (customers.isEmpty) {
        return;
      }
      await _communityRepository.addMembers(
        communityId: communityId,
        memberIds: customers,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to seed community members: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _openRoom(CommunityRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CommunityChatScreen(
          room: room,
          communityRepository: _communityRepository,
          merchantId: widget.merchantId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('merchant_community_title'.tr()),
        actions: [
          IconButton(
            onPressed: _createRoom,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<CommunityRoom>>(
        stream: _communityRepository.watchRooms(widget.merchantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_community_error'.tr()));
          }
          final rooms = snapshot.data ?? const [];
          if (rooms.isEmpty) {
            return Center(child: Text('merchant_community_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final room = rooms[index];
              return Card(
                child: ListTile(
                  title: Text(
                    room.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    room.description ??
                        'merchant_community_no_description'.tr(),
                  ),
                  trailing: Chip(label: Text('${room.members.length}')),
                  onTap: () => _openRoom(room),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CommunityChatScreen extends StatefulWidget {
  final CommunityRoom room;
  final CommunityRepository communityRepository;
  final String merchantId;
  const _CommunityChatScreen({
    required this.room,
    required this.communityRepository,
    required this.merchantId,
  });

  @override
  State<_CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<_CommunityChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, _ChatParticipant> _participants =
      <String, _ChatParticipant>{};
  final Set<String> _pendingLookups = <String>{};
  _ReplyContext? _replyContext;

  @override
  void initState() {
    super.initState();
    _primeMerchantProfile();
    _primeRoomMembers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _primeRoomMembers() {
    for (final memberId in widget.room.members) {
      if (memberId.isEmpty || memberId == widget.merchantId) continue;
      _queueCustomerLookup(memberId);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final replyContext = _replyContext;
    List<String>? privateRecipients;
    if (replyContext?.isPrivate == true && replyContext?.targetUserId != null) {
      privateRecipients = <String>{
        widget.merchantId,
        replyContext!.targetUserId!,
      }.toList();
    }
    await widget.communityRepository.sendMessage(
      communityId: widget.room.id,
      senderId: widget.merchantId,
      body: text,
      parentMessageId: replyContext?.messageId,
      privateRecipients: privateRecipients,
    );
    _messageController.clear();
    setState(() => _replyContext = null);
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = _firestore
        .collection('communities')
        .doc(widget.room.id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: Column(
        children: [
          if (_replyContext != null)
            _ReplyComposerBanner(
              contextInfo: _replyContext!,
              onCancel: () => setState(() => _replyContext = null),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs =
                    snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return Center(
                    child: Text('merchant_community_no_messages'.tr()),
                  );
                }
                final messageIndex = <String, Map<String, dynamic>>{
                  for (final doc in docs) doc.id: doc.data(),
                };
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final snapshotData = docs[index].data();
                    final messageId = docs[index].id;
                    final senderId = snapshotData['senderId']?.toString() ?? '';
                    final isMe = senderId == widget.merchantId;
                    if (senderId.isNotEmpty &&
                        senderId != widget.merchantId &&
                        !_participants.containsKey(senderId)) {
                      _queueCustomerLookup(senderId);
                    }
                    final participant = _participantFor(senderId, isMe);
                    final reactions =
                        (snapshotData['reactions'] as Map<String, dynamic>?) ??
                        const <String, dynamic>{};
                    final likeCount = _countLikes(reactions);
                    final isLiked = _hasLiked(reactions);
                    final privateRecipients =
                        ((snapshotData['privateRecipients'] as List<dynamic>?)
                            ?.whereType<String>()
                            .toList()) ??
                        const <String>[];
                    final isPrivateMessage = privateRecipients.isNotEmpty;
                    final canSeePrivate =
                        !isPrivateMessage ||
                        privateRecipients.contains(widget.merchantId) ||
                        senderId == widget.merchantId;
                    if (!canSeePrivate) {
                      return const SizedBox.shrink();
                    }
                    final parentId = snapshotData['parentMessageId']
                        ?.toString();
                    final parentData = parentId != null
                        ? messageIndex[parentId]
                        : null;
                    final parentSenderId =
                        parentData?['senderId']?.toString() ?? '';
                    final parentParticipant = parentSenderId.isNotEmpty
                        ? _participantFor(
                            parentSenderId,
                            parentSenderId == widget.merchantId,
                          )
                        : null;
                    final parentBody = parentData?['body']?.toString();
                    final messageBody = snapshotData['body']?.toString() ?? '';
                    return _ChatMessageTile(
                      messageId: messageId,
                      participant: participant,
                      message: messageBody,
                      isCurrentUser: isMe,
                      likeCount: likeCount,
                      isLiked: isLiked,
                      onToggleReaction: () =>
                          _toggleReaction(docs[index].reference, isLiked),
                      onReply: () => _startReply(
                        messageId: messageId,
                        participant: participant,
                        message: messageBody,
                        isPrivate: false,
                      ),
                      onPrivateReply:
                          (!isMe &&
                              (!isPrivateMessage ||
                                  privateRecipients.contains(
                                    widget.merchantId,
                                  )))
                          ? () => _startReply(
                              messageId: messageId,
                              participant: participant,
                              message: messageBody,
                              isPrivate: true,
                            )
                          : null,
                      parentSenderName: parentParticipant?.displayName,
                      parentBody: parentBody,
                      isPrivate: isPrivateMessage,
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
                    decoration: InputDecoration(
                      hintText: 'merchant_community_write_message'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _primeMerchantProfile() {
    if (widget.merchantId.isEmpty) return;
    FirebaseFirestore.instance
        .collection('merchants')
        .doc(widget.merchantId)
        .get()
        .then((doc) {
          final data = doc.data();
          final name = data?['name']?.toString();
          final logo = data?['logoUrl']?.toString();
          if (!mounted) return;
          setState(() {
            _participants[widget.merchantId] = _ChatParticipant(
              id: widget.merchantId,
              displayName: (name?.isNotEmpty == true
                  ? name!
                  : widget.room.name),
              avatarUrl: logo,
              isMerchant: true,
              isCurrentUser: true,
            );
          });
        })
        .catchError((error, stackTrace) {
          debugPrint('Failed to load merchant profile: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) return;
          setState(() {
            _participants[widget.merchantId] = _ChatParticipant(
              id: widget.merchantId,
              displayName: widget.room.name,
              isMerchant: true,
              isCurrentUser: true,
            );
          });
        });
  }

  void _queueCustomerLookup(String userId) {
    if (_pendingLookups.contains(userId) || userId.isEmpty) {
      return;
    }
    _pendingLookups.add(userId);
    _firestore
        .collection('customers')
        .doc(userId)
        .get()
        .then((doc) {
          final data = doc.data();
          final name = data?['name']?.toString();
          final avatar = data?['photoUrl']?.toString();
          if (!mounted) return;
          setState(() {
            final existing = _participants[userId];
            if (existing != null) {
              _participants[userId] = existing.copyWith(
                displayName: name?.isNotEmpty == true ? name : null,
                avatarUrl: avatar?.isNotEmpty == true ? avatar : null,
              );
            } else {
              _participants[userId] = _ChatParticipant(
                id: userId,
                displayName: name?.isNotEmpty == true ? name! : 'Member',
                avatarUrl: avatar,
              );
            }
          });
        })
        .catchError((error, stackTrace) {
          debugPrint('Customer profile lookup failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) return;
          setState(() {
            _participants[userId] =
                _participants[userId] ??
                _ChatParticipant(id: userId, displayName: 'Member');
          });
        })
        .whenComplete(() {
          _pendingLookups.remove(userId);
        });
  }

  _ChatParticipant _participantFor(String senderId, bool isMe) {
    final participant = _participants[senderId];
    if (participant != null) {
      return participant;
    }
    final isMerchant = senderId == widget.merchantId;
    return _ChatParticipant(
      id: senderId,
      displayName: isMe ? 'You' : (isMerchant ? widget.room.name : 'Member'),
      isMerchant: isMerchant,
      isCurrentUser: isMe,
    );
  }

  void _startReply({
    required String messageId,
    required _ChatParticipant participant,
    required String message,
    required bool isPrivate,
  }) {
    setState(() {
      _replyContext = _ReplyContext(
        messageId: messageId,
        previewText: message,
        targetDisplayName: participant.displayName,
        targetUserId: isPrivate ? participant.id : null,
        isPrivate: isPrivate,
      );
    });
  }

  int _countLikes(Map<String, dynamic> reactions) {
    var total = 0;
    for (final value in reactions.values) {
      if (value == 'like') {
        total++;
      }
    }
    return total;
  }

  bool _hasLiked(Map<String, dynamic> reactions) {
    return reactions[widget.merchantId] == 'like';
  }

  Future<void> _toggleReaction(
    DocumentReference<Map<String, dynamic>> messageRef,
    bool isLiked,
  ) async {
    try {
      final snap = await messageRef.get();
      final data = snap.data();
      if (data == null) return;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      if (isLiked) {
        reactions.remove(widget.merchantId);
      } else {
        reactions[widget.merchantId] = 'like';
      }
      // Prepare update payload with all required fields, using null if missing.
      final updatePayload = <String, dynamic>{
        'reactions': reactions,
        'senderId': data['senderId'],
        'body': data['body'],
        'createdAt': data['createdAt'],
        'parentMessageId': data.containsKey('parentMessageId')
            ? data['parentMessageId']
            : null,
        'privateRecipients': data.containsKey('privateRecipients')
            ? data['privateRecipients']
            : null,
      };
      await messageRef.update(updatePayload);
    } catch (error, stackTrace) {
      debugPrint('Failed to toggle reaction: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _ChatParticipant {
  const _ChatParticipant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isMerchant = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isMerchant;
  final bool isCurrentUser;

  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  _ChatParticipant copyWith({String? displayName, String? avatarUrl}) {
    return _ChatParticipant(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isMerchant: isMerchant,
      isCurrentUser: isCurrentUser,
    );
  }
}

class _ReplyContext {
  const _ReplyContext({
    required this.messageId,
    required this.previewText,
    required this.targetDisplayName,
    this.targetUserId,
    required this.isPrivate,
  });

  final String messageId;
  final String previewText;
  final String targetDisplayName;
  final String? targetUserId;
  final bool isPrivate;
}

class _ReplyComposerBanner extends StatelessWidget {
  const _ReplyComposerBanner({
    required this.contextInfo,
    required this.onCancel,
  });

  final _ReplyContext contextInfo;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            contextInfo.isPrivate ? Icons.lock_outline : Icons.reply,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contextInfo.targetDisplayName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contextInfo.previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    this.messageId,
    required this.participant,
    required this.message,
    required this.isCurrentUser,
    this.likeCount = 0,
    this.isLiked = false,
    this.onToggleReaction,
    this.onReply,
    this.onPrivateReply,
    this.parentSenderName,
    this.parentBody,
    this.isPrivate = false,
  });

  final String? messageId;
  final _ChatParticipant participant;
  final String message;
  final bool isCurrentUser;
  final int likeCount;
  final bool isLiked;
  final VoidCallback? onToggleReaction;
  final VoidCallback? onReply;
  final VoidCallback? onPrivateReply;
  final String? parentSenderName;
  final String? parentBody;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = participant.displayName.isNotEmpty
        ? participant.displayName
        : (participant.isCurrentUser
              ? 'You'
              : (participant.isMerchant ? 'Merchant' : 'Member'));
    final bubbleColor = isCurrentUser
        ? colorScheme.primary
        : colorScheme.surfaceVariant;
    final textColor = isCurrentUser ? Colors.white : colorScheme.onSurface;
    final alignment = isCurrentUser
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
    final crossAxisAlignment = isCurrentUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: alignment,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser) ...[
              _ChatAvatar(participant: participant, isCurrentUser: false),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (parentSenderName != null || parentBody != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (parentSenderName != null)
                                  Text(
                                    parentSenderName!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: colorScheme.outline),
                                  ),
                                if (parentBody != null)
                                  Text(
                                    parentBody!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: textColor),
                                  ),
                              ],
                            ),
                          ),
                        Text(message, style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                  if (onToggleReaction != null ||
                      onReply != null ||
                      onPrivateReply != null ||
                      isPrivate)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: isCurrentUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (onToggleReaction != null)
                            _ReactionButton(
                              onTap: onToggleReaction!,
                              isLiked: isLiked,
                              likeCount: likeCount,
                            ),
                          if (isPrivate)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('community_private_tab'.tr()),
                                avatar: const Icon(Icons.lock, size: 16),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          if (onReply != null)
                            IconButton(
                              icon: const Icon(Icons.reply),
                              visualDensity: VisualDensity.compact,
                              iconSize: 20,
                              tooltip: 'Reply',
                              onPressed: onReply,
                            ),
                          if (onPrivateReply != null)
                            IconButton(
                              icon: const Icon(Icons.lock_outline),
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              tooltip: 'Private reply',
                              onPressed: onPrivateReply,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              _ChatAvatar(participant: participant, isCurrentUser: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.participant, required this.isCurrentUser});

  final _ChatParticipant participant;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = participant.avatarUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final backgroundColor = hasImage
        ? null
        : (participant.isMerchant
              ? Colors.deepPurple.shade100
              : (isCurrentUser
                    ? colorScheme.primary.withOpacity(0.2)
                    : colorScheme.surfaceVariant));
    final foregroundColor = participant.isMerchant
        ? Colors.deepPurple
        : colorScheme.onSurfaceVariant;

    return CircleAvatar(
      radius: 18,
      backgroundColor: backgroundColor,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              participant.initials,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.onTap,
    required this.isLiked,
    required this.likeCount,
  });

  final VoidCallback onTap;
  final bool isLiked;
  final int likeCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isLiked ? colorScheme.primary : colorScheme.outline,
            ),
            if (likeCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isLiked
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
