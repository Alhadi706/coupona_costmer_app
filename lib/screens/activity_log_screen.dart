import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('activity_logs')
          .where('customerEmail', isEqualTo: widget.customerEmail)
          .orderBy('transaction_date', descending: true)
          .get();
      setState(() {
        activities = querySnapshot.docs.map((doc) => doc.data()).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب سجل النشاطات: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (activities.isEmpty) {
      return const Center(child: Text('لا يوجد سجل نشاطات.'));
    }
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          title: Text('مبلغ العملية: ${activity['amount']}'),
          subtitle: Text('تاريخ العملية: ${activity['transaction_date']}'),
        );
      },
    );
  }
}

