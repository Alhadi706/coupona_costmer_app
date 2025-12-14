import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<dynamic> rewards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRewards();
  }

  Future<void> fetchRewards() async {
    // Fetch rewards from Firestore
    final snapshot = await FirebaseService.firestore.collection('rewards').get();
    setState(() {
      rewards = snapshot.docs.map((d) => d.data()).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rewards.isEmpty) {
      return const Center(child: Text('لا توجد عروض متاحة حالياً'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'كيف تجمع النقاط؟',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'يمكنك جمع النقاط عند رفع فاتورتك من المتجر. بعض المتاجر تمنح نقاطاً حسب قيمة الفاتورة، أو عدد المنتجات، أو عند شراء أصناف مميزة.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'مثال: كل 10 دينار = 1 نقطة، أو كل 5 منتجات = 1 نقطة، أو صنف العصير = 3 نقاط إضافية.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        ...rewards.map((reward) => ListTile(
              title: Text(reward['reward_name']),
              subtitle: Text(reward['description'] ?? ''),
              trailing: Text('${reward['value']}'),
            )),
      ],
    );
  }
}