import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/company_server_service.dart';
import '../../services/export_download.dart';
import '../../theme/design_tokens.dart';
import 'coalition_clearinghouse_widgets.dart';

typedef ClearinghouseLoader = Future<Map<String, dynamic>> Function();
typedef ClearinghouseSettler = Future<Map<String, dynamic>> Function({
  required String coalitionId,
  required String toMerchantId,
  required String period,
});

class CoalitionClearinghouseScreen extends StatefulWidget {
  final ClearinghouseLoader? clearinghouseLoader;
  final ClearinghouseLoader? ledgerLoader;
  final ClearinghouseSettler? settler;
  final Duration requestTimeout;

  const CoalitionClearinghouseScreen({
    super.key,
    this.clearinghouseLoader,
    this.ledgerLoader,
    this.settler,
    this.requestTimeout = const Duration(seconds: 15),
  });

  @override
  State<CoalitionClearinghouseScreen> createState() =>
      _CoalitionClearinghouseScreenState();
}

class _CoalitionClearinghouseScreenState
    extends State<CoalitionClearinghouseScreen> {
  bool _loading = true;
  bool _settling = false;
  String? _error;
  Map<String, dynamic> _summary = const <String, dynamic>{};
  List<Map<String, dynamic>> _members = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _disputes = const <Map<String, dynamic>>[];

  ClearinghouseLoader get _clearinghouseLoader =>
      widget.clearinghouseLoader ??
      CompanyServerService.getMerchantCoalitionClearinghouse;

  ClearinghouseLoader get _ledgerLoader =>
      widget.ledgerLoader ?? CompanyServerService.getMerchantCoalitionLedger;

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
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        _clearinghouseLoader().timeout(widget.requestTimeout),
        _ledgerLoader().timeout(widget.requestTimeout),
      ]);
      if (!mounted) return;
      final clearinghouse = results[0];
      setState(() {
        _summary = _map(clearinghouse['summary']);
        _members = _maps(
          clearinghouse['memberSettlements'] ?? clearinghouse['statements'],
        );
        _disputes = _maps(clearinghouse['disputes']);
        _ledger = _maps(
          clearinghouse['settlementHistory'] ?? results[1]['ledger'],
        );
      });
    } on TimeoutException {
      if (mounted) setState(() => _error = 'clearinghouse_timeout'.tr());
    } catch (_) {
      if (mounted) setState(() => _error = 'clearinghouse_load_error'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];

  Future<void> _confirmSettlement([Map<String, dynamic>? selected]) async {
    final pending = selected == null
        ? _members.where(_canSettle).toList(growable: false)
        : <Map<String, dynamic>>[selected];
    if (pending.isEmpty || _settling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.account_balance_outlined),
        title: Text('clearinghouse_confirm_title'.tr()),
        content: Text(
          'clearinghouse_confirm_body'.tr(
            namedArgs: {'count': pending.length.toString()},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _settling = true);
    try {
      final settle = widget.settler ??
          CompanyServerService.settleMerchantCoalitionClearinghouse;
      for (final row in pending) {
        await settle(
          coalitionId: (row['coalition_id'] ?? row['coalitionId'] ?? '')
              .toString(),
          toMerchantId:
              (row['to_merchant_id'] ?? row['toMerchantId'] ?? '').toString(),
          period: (row['period'] ?? '').toString(),
        ).timeout(widget.requestTimeout);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('clearinghouse_settlement_confirmed'.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('clearinghouse_settlement_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _settling = false);
    }
  }

  bool _canSettle(Map<String, dynamic> row) {
    final status = (row['status'] ?? '').toString();
    final net = double.tryParse((row['net_amount'] ?? 0).toString()) ?? 0;
    return status != 'completed' && row['settled'] != true && net < 0;
  }

  Future<void> _respondToDispute(
    Map<String, dynamic> dispute,
    String status,
  ) async {
    var note = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settlement_dispute_response'.tr()),
        content: TextField(onChanged: (value) => note = value, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || note.trim().isEmpty) return;
    await CompanyServerService.respondToBrandSettlementDispute(
      disputeId: dispute['id'].toString(),
      status: status,
      note: note.trim(),
    );
    await _load();
  }

  Future<void> _downloadReceipt(Map<String, dynamic> row) async {
    final pdf = pw.Document();
    final reference = (row['id'] ?? row['reward_claim_id'] ?? '-').toString();
    pdf.addPage(pw.Page(build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 0, child: pw.Text('Kupuna Settlement Receipt')),
        pw.Text('Reference: $reference'),
        pw.Text('Coalition: ${row['coalition_name'] ?? '-'}'),
        pw.Text('From: ${row['from_merchant'] ?? '-'}'),
        pw.Text('To: ${row['to_merchant'] ?? '-'}'),
        pw.Text('Net points: ${row['net_points'] ?? row['total_points'] ?? 0}'),
        pw.Text('Date: ${row['settled_at'] ?? row['created_at'] ?? '-'}'),
      ],
    )));
    final ok = await downloadBytes(
      bytes: await pdf.save(),
      fileName: 'settlement-$reference.pdf',
      mimeType: 'application/pdf',
    );
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clearinghouse_pdf_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(
        title: Text('merchant_nav_clearinghouse'.tr()),
        actions: [
          IconButton(
            tooltip: 'clearinghouse_refresh'.tr(),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ClearinghouseErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ClearinghouseContent(
                    summary: _summary,
                    members: _members,
                    ledger: _ledger,
                    disputes: _disputes,
                    settling: _settling,
                    canSettle: _canSettle,
                    onSettleAll: _confirmSettlement,
                    onSettleRow: (row) => _confirmSettlement(row),
                    onRespondToDispute: _respondToDispute,
                    onDownloadReceipt: _downloadReceipt,
                  ),
                ),
    );
  }
}