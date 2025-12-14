import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MerchantPrivateMessagesScreen extends StatelessWidget {
  final String merchantId;
  const MerchantPrivateMessagesScreen({super.key, required this.merchantId});

  @override
  Widget build(BuildContext context) {
    final roomsStream = FirebaseFirestore.instance
        .collection('merchantCustomerRooms')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('merchant_messages_title'.tr()),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: roomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_messages_error'.tr()));
          }
          final rooms = snapshot.data?.docs ?? const [];
          if (rooms.isEmpty) {
            return Center(child: Text('merchant_messages_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final room = rooms[index];
              final data = room.data();
              final customerName = (data['customerName']?.toString()).nullIfEmpty ?? 'merchant_messages_unknown_customer'.tr();
              final lastMessage = (data['lastMessage']?.toString()).nullIfEmpty ?? 'community_no_messages'.tr();
              final updated = data['updatedAt'] as Timestamp?;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(customerName),
                subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: updated == null
                    ? null
                    : Text(DateFormat.Hm().format(updated.toDate())),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _MerchantPrivateChatScreen(
                        roomId: room.id,
                        merchantId: merchantId,
                        customerName: customerName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MerchantPrivateChatScreen extends StatefulWidget {
  final String roomId;
  final String merchantId;
  final String customerName;
  const _MerchantPrivateChatScreen({required this.roomId, required this.merchantId, required this.customerName});

  @override
  State<_MerchantPrivateChatScreen> createState() => _MerchantPrivateChatScreenState();
}

class _MerchantPrivateChatScreenState extends State<_MerchantPrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final roomRef = FirebaseFirestore.instance.collection('merchantCustomerRooms').doc(widget.roomId);
    try {
      await roomRef.collection('messages').add({
        'senderId': widget.merchantId,
        'body': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await roomRef.update({
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('merchant_messages_send_error'.tr())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = FirebaseFirestore.instance
        .collection('merchantCustomerRooms')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? const [];
                if (messages.isEmpty) {
                  return Center(child: Text('community_no_messages'.tr()));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final isMerchant = data['senderId'] == widget.merchantId;
                    final message = data['body']?.toString() ?? '';
                    return Align(
                      alignment: isMerchant ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMerchant ? Colors.deepPurple : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(color: isMerchant ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'merchant_messages_hint'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    child: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.send, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String? {
  String? get nullIfEmpty {
    if (this == null || this!.trim().isEmpty) return null;
    return this;
  }
}
