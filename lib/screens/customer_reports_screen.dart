import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'report_screen.dart';

typedef CustomerReportsLoader = Future<List<Map<String, dynamic>>> Function();
typedef CustomerReportResponder = Future<Map<String, dynamic>> Function(String reportId, String message);

class CustomerReportsScreen extends StatefulWidget {
  final CustomerReportsLoader? reportsLoader;
  final WidgetBuilder? reportFormBuilder;
  final CustomerReportResponder? reportResponder;

  const CustomerReportsScreen({
    super.key,
    this.reportsLoader,
    this.reportFormBuilder,
    this.reportResponder,
  });

  @override
  State<CustomerReportsScreen> createState() => _CustomerReportsScreenState();
}

class _CustomerReportsScreenState extends State<CustomerReportsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = const <Map<String, dynamic>>[];

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await (widget.reportsLoader ?? CompanyServerService.getMyReports)();
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReportForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: widget.reportFormBuilder ?? (_) => const ReportScreen(),
      ),
    );
    if (mounted) await _load();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return _tx('report_status_new', 'New');
      case 'under_review':
        return _tx('report_status_under_review', 'Under review');
      case 'information_requested':
        return _tx('report_status_information_requested', 'Information requested');
      case 'accepted':
        return _tx('report_status_accepted', 'Accepted');
      case 'reward_granted':
        return _tx('report_status_reward_granted', 'Reward granted');
      case 'rejected':
        return _tx('report_status_rejected', 'Rejected');
      case 'closed':
        return _tx('report_status_closed', 'Closed');
      default:
        return status;
    }
  }

  Future<void> _respondToReport(Map<String, dynamic> report) async {
    var responseText = '';
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tx('report_add_information', 'Add requested information')),
        content: TextField(
          key: const Key('customer-report-response'),
          maxLines: 4,
          onChanged: (value) => responseText = value,
          decoration: InputDecoration(labelText: _tx('report_response_message', 'Your response')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_tx('cancel', 'Cancel'))),
          FilledButton(
            key: const Key('customer-report-response-submit'),
            onPressed: () {
              final value = responseText.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(_tx('send', 'Send')),
          ),
        ],
      ),
    );
    if (message == null) return;
    await (widget.reportResponder ?? CompanyServerService.respondToReport)((report['id'] ?? '').toString(), message);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('customer_reports_title', 'My reports'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('customer-report-create'),
        onPressed: _openReportForm,
        icon: const Icon(Icons.add),
        label: Text(_tx('customer_report_new', 'New report')),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        key: const Key('customer-reports-load-error'),
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_tx('retry', 'Retry')),
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        key: const Key('customer-reports-empty'),
        child: Text(_tx('customer_reports_empty', 'You have not submitted any reports.')),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final report = _reports[index];
          final rewardPoints = int.tryParse('${report['rewardPoints'] ?? 0}') ?? 0;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined, color: kTeal),
              title: Text((report['targetStoreName'] ?? report['targetBrandName'] ?? report['reportType'] ?? '-').toString()),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((report['description'] ?? '').toString()),
                  if ((report['resolutionNote'] ?? '').toString().isNotEmpty)
                    Text('${_tx('report_resolution_note', 'Resolution')}: ${report['resolutionNote']}'),
                  if (rewardPoints > 0)
                    Text('+ $rewardPoints ${_tx('points', 'points')}', style: const TextStyle(color: kTeal, fontWeight: FontWeight.w700)),
                  if (report['updates'] is List && (report['updates'] as List).isNotEmpty) ...[
                    const Divider(),
                    Text(_tx('report_updates_title', 'Conversation'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ...(report['updates'] as List).whereType<Map>().map((update) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chat_bubble_outline, size: 18),
                      title: Text((update['message'] ?? '').toString()),
                      subtitle: Text((update['authorRole'] ?? '').toString()),
                    )),
                  ],
                  if (report['status'] == 'information_requested')
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: Key('customer-report-respond-${report['id']}'),
                        onPressed: () => _respondToReport(report),
                        icon: const Icon(Icons.reply_outlined),
                        label: Text(_tx('report_add_information', 'Add requested information')),
                      ),
                    ),
                ],
              ),
              trailing: Chip(label: Text(_statusLabel((report['status'] ?? '').toString()))),
            ),
          );
        },
      ),
    );
  }
}
