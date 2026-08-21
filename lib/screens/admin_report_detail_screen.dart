import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';
import '../theme/app_themes.dart';
import '../theme/design_tokens.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final Function(String, String, {bool rewardGranted}) onTransition;

  const AdminReportDetailScreen({
    super.key,
    required this.report,
    required this.onTransition,
  });

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.report['status'] ?? 'new';
  }

  Future<void> _updateStatus(String newStatus, {bool rewardGranted = false}) async {
    try {
      await widget.onTransition(widget.report['id'], newStatus, rewardGranted: rewardGranted);
      if (!mounted) return;
      setState(() {
        _status = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final reporterLabel = report['reporterLabel'] ?? 'Unknown';
    final targetName = report['targetName'] ?? 'Unknown target';
    final description = report['description'] ?? 'No description';
    final reportType = report['reportType'] ?? 'other';
    final createdAt = report['createdAt'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Details'),
        backgroundColor: kInk,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _status == 'closed' ? Colors.grey : Colors.red)),
                    const Divider(),
                    Text('Target: $targetName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Reporter: $reporterLabel', style: TextStyle(color: Colors.grey.shade700)),
                    Text('Type: $reportType'),
                    Text('Date: $createdAt'),
                    const SizedBox(height: 16),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(description),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_status == 'new')
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('under_review'),
                    icon: const Icon(Icons.search),
                    label: const Text('Start Investigation'),
                  ),
                if (_status == 'under_review') ...[
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('accepted'),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept Claim (Valid)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _updateStatus('rejected'),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject (Invalid)'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
                if (_status == 'accepted') ...[
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('reward_granted', rewardGranted: true),
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Grant Compensation (Points)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _updateStatus('closed'),
                    icon: const Icon(Icons.archive),
                    label: const Text('Close without compensation'),
                  ),
                ],
                if (_status == 'reward_granted' || _status == 'rejected')
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('closed'),
                    icon: const Icon(Icons.archive),
                    label: const Text('Archive Ticket'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
