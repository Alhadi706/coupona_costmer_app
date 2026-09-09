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
    var note = '';
    var grantPoints = false;
    var points = 0;
    var sendGift = false;
    String? selectedGiftTitle;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('merchant_report_resolve_title', 'Respond to report')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tx('merchant_report_manual_response_hint', 'All responses are manual. Compensation is optional.'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _tx('merchant_report_thank_you_note', 'Thank you / clarification note *'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(() => note = value),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: grantPoints,
                  title: Text(_tx('merchant_report_grant_reward', 'Grant compensation points')),
                  onChanged: (value) => setDialogState(() => grantPoints = value),
                ),
                if (grantPoints)
                  TextFormField(
                    initialValue: '10',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _tx('merchant_report_reward_points', 'Points')),
                    onChanged: (value) => setDialogState(() => points = int.tryParse(value) ?? 0),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendGift,
                  title: Text(_tx('merchant_report_send_gift', 'Send gift or voucher')),
                  onChanged: (value) => setDialogState(() => sendGift = value),
                ),
                if (sendGift)
                  DropdownButtonFormField<String>(
                    value: selectedGiftTitle,
                    decoration: InputDecoration(labelText: _tx('merchant_report_select_gift', 'Select gift')),
                    items: [
                      _tx('merchant_report_gift_discount', 'Discount voucher'),
                      _tx('merchant_report_gift_free_item', 'Free item'),
                      _tx('merchant_report_gift_service_credit', 'Service credit'),
                    ].map((title) => DropdownMenuItem(value: title, child: Text(title))).toList(growable: false),
                    onChanged: (value) => setDialogState(() => selectedGiftTitle = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_tx('cancel', 'Cancel'))),
            FilledButton(
              key: const Key('merchant-report-confirm-action'),
              onPressed: note.trim().isEmpty || (grantPoints && points <= 0) || (sendGift && selectedGiftTitle == null)
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
      final action = (grantPoints && points > 0) || sendGift ? 'reward' : 'accept';
      await (widget.reportResolver ?? CompanyServerService.acceptMerchantReport)(
        (report['id'] ?? '').toString(),
        action: action,
        grantReward: grantPoints && points > 0,
        rewardPoints: points,
        resolutionNote: note.trim(),
      );
      if (sendGift && mounted) {
        final customerId = (report['ownerId'] ?? report['customerUserId'] ?? '').toString();
        final merchantName = (report['storeName'] ?? report['targetStoreNameSnapshot'] ?? 'Merchant').toString();
        if (customerId.isNotEmpty) {
          await CompanyServerService.dispatchDirectGift(
            customerUserId: customerId,
            merchantName: merchantName,
            thresholdPoints: grantPoints && points > 0 ? points : 0,
            voucherOptions: selectedGiftTitle == null
                ? null
                : [<String, dynamic>{'title': selectedGiftTitle, 'subtitle': _tx('merchant_report_gift_from_report', 'Compensation for your report')}],
          );
        }
      }
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
                      _buildStatusBadge(status),
                    ],
                  ),
                  Text('${_tx('merchant_report_customer', 'Customer')}: ${report['ownerName'] ?? report['ownerEmail'] ?? '-'}'),
                  Text((report['description'] ?? '').toString()),
                  if ((report['assignedToUserId'] ?? '').toString().isNotEmpty)
                    Text('${_tx('report_assigned_to', 'Assigned to')}: ${report['assignedToUserId']}'),
                  if ((report['productName'] ?? '').toString().isNotEmpty)
                    Text('${_tx('merchant_report_product', 'Product')}: ${report['productName']}'),
                  ..._buildUpdates(report['updates']),
                  if (status == 'new' || status == 'information_requested' || status == 'under_review') ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: Key('merchant-report-$reportId-resolve'),
                      onPressed: () => _resolve(report),
                      icon: const Icon(Icons.task_alt),
                      label: Text(_tx('merchant_report_resolve', 'Respond')),
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

  Widget _buildStatusBadge(String status) {
    final label = _statusLabel(status);
    final color = _statusColor(status);
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
      case 'under_review':
        return _tx('report_status_under_review', 'Under review');
      case 'information_requested':
        return _tx('report_status_information_requested', 'Information requested');
      case 'accepted':
        return _tx('report_status_responded', 'Responded');
      case 'reward_granted':
        return _tx('report_status_compensated', 'Compensated');
      case 'rejected':
        return _tx('report_status_rejected', 'Rejected');
      case 'closed':
        return _tx('report_status_closed', 'Closed');
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
      case 'under_review':
      case 'information_requested':
        return const Color(0xFFE67E22);
      case 'accepted':
        return const Color(0xFF1B7A66);
      case 'reward_granted':
        return const Color(0xFF2E80ED);
      case 'rejected':
        return const Color(0xFFE53935);
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String>(
          value: _statusFilter,
          items: ['all', 'new', 'information_requested', 'accepted', 'reward_granted', 'rejected']
              .map((value) => DropdownMenuItem(value: value, child: Text(value == 'all' ? _tx('all', 'All') : _statusLabel(value))))
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
