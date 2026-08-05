// filepath: lib/screens/report_issue_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ReportIssueScreen extends StatelessWidget { // تأكد من اسم الكلاس
  const ReportIssueScreen({super.key}); // تأكد من الكونستركتور

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('report_issue_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Center(
        child: Text('report_issue_placeholder'.tr(), style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}