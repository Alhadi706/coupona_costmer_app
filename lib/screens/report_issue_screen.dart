// filepath: lib/screens/report_issue_screen.dart
import 'package:flutter/material.dart';

class ReportIssueScreen extends StatelessWidget { // تأكد من اسم الكلاس
  const ReportIssueScreen({super.key}); // تأكد من الكونستركتور

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تبليغ عن مشكلة'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: const Center(
        child: Text('شاشة التبليغ (قيد الإنشاء)', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}