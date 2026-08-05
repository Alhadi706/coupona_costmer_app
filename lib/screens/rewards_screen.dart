import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<Map<String, dynamic>> rewards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRewards();
  }

  Future<void> fetchRewards() async {
    try {
      final response = await CompanyServerService.getRewards();
      if (!mounted) return;
      setState(() {
        rewards = response;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        rewards = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rewards.isEmpty) {
      return Center(child: Text('no_offers_available_now'.tr()));
    }
    return ListView.builder(
      itemCount: rewards.length,
      itemBuilder: (context, index) {
        final reward = rewards[index];
        return ListTile(
          title: Text((reward['reward_name'] ?? 'reward_generic'.tr()).toString()),
          subtitle: Text(reward['description'] ?? ''),
          trailing: Text('${reward['value']}'),
        );
      },
    );
  }
}