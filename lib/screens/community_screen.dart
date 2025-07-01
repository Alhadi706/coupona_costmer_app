import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('community_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _GroupsTab(),
              _PrivateChatsTab(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.black87,
                indicatorColor: Colors.amber,
                indicatorWeight: 3,
                indicator: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                tabs: [
                  Tab(text: 'community_groups_tab'.tr(), icon: Icon(Icons.groups)),
                  Tab(text: 'community_private_tab'.tr(), icon: Icon(Icons.chat)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('community_no_groups'.tr()));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('community_groups_title'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ...snapshot.data!.docs.map((groupDoc) {
              final group = groupDoc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.groups, color: Colors.deepPurple, size: 32),
                  title: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(group['desc'] ?? ''),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18, color: Colors.grey),
                      Text('${group['members'] ?? 0}'),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _GroupChatScreen(groupId: groupDoc.id, groupName: group['name'] ?? ''),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  String? groupName;
                  await showDialog(
                    context: context,
                    builder: (_) => StatefulBuilder(
                      builder: (context, setState) => AlertDialog(
                        title: Text('community_create_group_title'.tr()),
                        content: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'community_group_name'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => groupName = val,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('cancel'.tr()),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (groupName != null && groupName!.trim().isNotEmpty) {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('community_sent'.tr()),
                                    content: Text('community_sent_waiting'.tr()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('ok'.tr()),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            child: Text('community_create'.tr()),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text('community_create_group_btn'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupChatScreen extends StatelessWidget {
  final String groupId;
  final String groupName;
  const _GroupChatScreen({required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('community_no_messages'.tr()));
                }
                final messages = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg['sender'] == 'أنت'; // عدل حسب نظام المستخدم
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurple : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
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
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'community_write_message'.tr(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // منطق إرسال الرسالة (تجريبي)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('community_message_sent'.tr())),
                    );
                  },
                  child: const Icon(Icons.send),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateChatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // مثال توضيحي للرسائل الخاصة
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.blue),
            title: Text('community_chat_with_ahmed'.tr()),
            subtitle: Text('community_chat_ahmed_msg'.tr()),
            onTap: () {},
          ),
        ),
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: Text('community_chat_with_mohamed'.tr()),
            subtitle: Text('community_chat_mohamed_msg'.tr()),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

