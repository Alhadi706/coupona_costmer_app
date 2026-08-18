// filepath: lib/screens/report_issue_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/design_tokens.dart';

class ReportIssueScreen extends StatelessWidget { // تأكد من اسم الكلاس
  const ReportIssueScreen({super.key}); // تأكد من الكونستركتور

  void _showToast(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kTealDark,
        content: Text(
          '${'report_sent'.tr()}: $type',
          style: const TextStyle(color: kWhite),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> reportTypes = <String>[
      'expired'.tr(),
      'bad_service'.tr(),
      'misleading_advertisement'.tr(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('report_issue_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'report_issue_placeholder'.tr(),
              style: kDisplayTextStyle(size: 20, weight: FontWeight.w700, color: kInk),
            ),
            const SizedBox(height: 12),
            ...reportTypes.map((type) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
                    foregroundColor: kWhite,
                  ),
                  onPressed: () => _showToast(context, type),
                  child: Text(type),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}