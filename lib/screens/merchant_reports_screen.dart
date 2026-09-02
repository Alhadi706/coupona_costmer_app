import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef MerchantReportsLoader = Future<List<Map<String, dynamic>>> Function();
typedef MerchantReportResolver = Future<Map<String, dynamic>> Function(
  String reportId, {
  String action,
  bool grantReward,
  int rewardPoints,
  String? resolutionNote,
});

class MerchantReportsScreen extends StatefulWidget {
  final MerchantReportsLoader? reportsLoader;
  final MerchantReportResolver? reportResolver;

  const MerchantReportsScreen({
    super.key,
    this.reportsLoader,
    this.reportResolver,
  });

  @override
  State<MerchantReportsScreen> createState() => _MerchantReportsScreenState();
}

class _MerchantReportsScreenState extends State<MerchantReportsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = const <Map<String, dynamic>>[];
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

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
      final reports = await (widget.reportsLoader ?? CompanyServerService.getMerchantReportsInbox)();
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(Map<String, dynamic> report) async {
    var action = 'accept';
    var grantReward = false;
    var rewardPoints = 10;
    var note = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('merchant_report_resolve_title', 'Resolve report')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('merchant-report-action'),
                initialValue: action,
                items: [
                  DropdownMenuItem(value: 'accept', child: Text(_tx('report_action_accept', 'Accept'))),
                  DropdownMenuItem(value: 'reward', child: Text(_tx('report_action_reward', 'Accept and compensate'))),
                  DropdownMenuItem(value: 'request_information', child: Text(_tx('report_action_request_information', 'Request information'))),
                  DropdownMenuItem(value: 'reject', child: Text(_tx('report_action_reject', 'Reject'))),
                ],
                onChanged: (value) => setDialogState(() {
                  action = value ?? 'accept';
                  grantReward = action == 'reward';
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: grantReward,
                title: Text(_tx('merchant_report_grant_reward', 'Grant compensation points')),
                onChanged: action == 'reward' ? (value) => setDialogState(() => grantReward = value) : null,
              ),
              if (grantReward)
                TextFormField(
                  initialValue: '$rewardPoints',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _tx('merchant_report_reward_points', 'Reward points')),
                  onChanged: (value) => rewardPoints = int.tryParse(value) ?? 0,
                ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 2,
                decoration: InputDecoration(labelText: _tx('report_resolution_note', 'Resolution note')),
                onChanged: (value) => setDialogState(() => note = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_tx('cancel', 'Cancel'))),
            FilledButton(
              key: const Key('merchant-report-confirm-action'),
              onPressed: (grantReward && rewardPoints <= 0) ||
                      (['reject', 'request_information'].contains(action) && note.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(_tx('confirm', 'Confirm')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await (widget.reportResolver ?? CompanyServerService.acceptMerchantReport)(
        (report['id'] ?? '').toString(),
        action: action,
        grantReward: grantReward,
        rewardPoints: rewardPoints,
        resolutionNote: note,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tx('merchant_report_resolve_failed', 'Unable to resolve report')}: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('merchant_reports_title', 'Store reports'))),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        key: const Key('merchant-reports-load-error'),
        child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(_tx('retry', 'Retry'))),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        key: const Key('merchant-reports-empty'),
        child: Text(_tx('merchant_reports_empty', 'No customer reports.')),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredReports.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) return _buildFilters();
          final report = _filteredReports[index - 1];
          final reportId = (report['id'] ?? '').toString();
          final status = (report['status'] ?? '').toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text((report['reportType'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
                      Chip(label: Text((report['priority'] ?? 'normal').toString())),
                      const SizedBox(width: 6),
                      Chip(label: Text(status)),
                    ],
                  ),
                  Text('${_tx('merchant_report_customer', 'Customer')}: ${report['ownerName'] ?? report['ownerEmail'] ?? '-'}'),
                  Text((report['description'] ?? '').toString()),
                  if ((report['assignedToUserId'] ?? '').toString().isNotEmpty)
                    Text('${_tx('report_assigned_to', 'Assigned to')}: ${report['assignedToUserId']}'),
                  if ((report['productName'] ?? '').toString().isNotEmpty)
                    Text('${_tx('merchant_report_product', 'Product')}: ${report['productName']}'),
                  ..._buildUpdates(report['updates']),
                  if (status == 'new') ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: Key('merchant-report-$reportId-resolve'),
                      onPressed: () => _resolve(report),
                      icon: const Icon(Icons.task_alt),
                      label: Text(_tx('merchant_report_resolve', 'Resolve')),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredReports => _reports.where((report) {
    final statusMatches = _statusFilter == 'all' || report['status'] == _statusFilter;
    final priorityMatches = _priorityFilter == 'all' || (report['priority'] ?? 'normal') == _priorityFilter;
    return statusMatches && priorityMatches;
  }).toList(growable: false);

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String>(
          value: _statusFilter,
          items: ['all', 'new', 'information_requested', 'accepted', 'reward_granted', 'rejected']
              .map((value) => DropdownMenuItem(value: value, child: Text(value == 'all' ? _tx('all', 'All') : value)))
              .toList(),
          onChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
        ),
        DropdownButton<String>(
          value: _priorityFilter,
          items: ['all', 'low', 'normal', 'high', 'urgent']
              .map((value) => DropdownMenuItem(value: value, child: Text(value == 'all' ? _tx('all', 'All') : value)))
              .toList(),
          onChanged: (value) => setState(() => _priorityFilter = value ?? 'all'),
        ),
      ],
    );
  }

  List<Widget> _buildUpdates(dynamic rawUpdates) {
    if (rawUpdates is! List || rawUpdates.isEmpty) return const [];
    return [
      const Divider(),
      Text(_tx('report_updates_title', 'Conversation'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ...rawUpdates.whereType<Map>().map((update) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.chat_bubble_outline, size: 18),
        title: Text((update['message'] ?? '').toString()),
        subtitle: Text((update['authorRole'] ?? '').toString()),
      )),
    ];
  }
}
