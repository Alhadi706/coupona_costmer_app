import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';

class ActivityLogScreen extends StatefulWidget {
  final String customerEmail; // البريد الإلكتروني للعميل

  const ActivityLogScreen({super.key, required this.customerEmail});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<dynamic> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActivityLog();
  }

  Future<void> fetchActivityLog() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await CompanyServerService.getActivityLogs(
        customerEmail: widget.customerEmail,
      );
      setState(() {
        activities = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('activity_log_fetch_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (activities.isEmpty) {
      return Center(child: Text('activity_log_empty'.tr()));
    }
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          title: Text('transaction_amount_value'.tr(namedArgs: {'amount': '${activity['amount']}'})),
          subtitle: Text('transaction_date_value'.tr(namedArgs: {'date': '${activity['transaction_date']}'})),
        );
      },
    );
  }
}

