import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        title: const Text('مجتمع كوبونا'),
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
                tabs: const [
                  Tab(text: 'القروبات', icon: Icon(Icons.groups)),
                  Tab(text: 'الرسائل الخاصة', icon: Icon(Icons.chat)),
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
          return const Center(child: Text('لا توجد قروبات متاحة'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('قروبات المجتمع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        title: const Text('طلب إنشاء قروب جديد'),
                        content: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'اسم القروب',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => groupName = val,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (groupName != null && groupName!.trim().isNotEmpty) {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('تم الإرسال'),
                                    content: const Text('تم إرسال طلب إنشاء القروب وبانتظار الموافقة من الإدارة.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('حسنًا'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            child: const Text('إنشاء'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'طلب إنشاء قروب جديد',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
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
                  return const Center(child: Text('لا توجد رسائل بعد'));
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
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // منطق إرسال الرسالة (تجريبي)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال الرسالة (تجريبي)')),
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
            title: const Text('محادثة مع التاجر أحمد'),
            subtitle: const Text('مرحباً، كيف أستفيد من العرض؟'),
            onTap: () {},
          ),
        ),
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: const Text('محادثة مع الزبون محمد'),
            subtitle: const Text('تم استلام الكوبون بنجاح!'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

