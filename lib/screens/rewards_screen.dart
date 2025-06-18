import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // جلب الجوائز من Supabase
    final response = await Supabase.instance.client
        .from('rewards')
        .select();
    setState(() {
      rewards = response;
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
    return ListView.builder(
      itemCount: rewards.length,
      itemBuilder: (context, index) {
        final reward = rewards[index];
        return ListTile(
          title: Text(reward['reward_name']),
          subtitle: Text(reward['description'] ?? ''),
          trailing: Text('${reward['value']}'),
        );
      },
    );
  }
}