import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/company_server_service.dart';
import '../../theme/design_tokens.dart';

class CoalitionClearinghouseScreen extends StatefulWidget {
  const CoalitionClearinghouseScreen({super.key});

  @override
  State<CoalitionClearinghouseScreen> createState() => _CoalitionClearinghouseScreenState();
}

class _CoalitionClearinghouseScreenState extends State<CoalitionClearinghouseScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _summary = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];

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
      final results = await Future.wait(<Future<dynamic>>[
        CompanyServerService.getMerchantCoalitionClearinghouse(),
        CompanyServerService.getMerchantCoalitionLedger(),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = List<Map<String, dynamic>>.from((results[0] as Map<String, dynamic>)['statements'] ?? const <dynamic>[]);
        _ledger = List<Map<String, dynamic>>.from((results[1] as Map<String, dynamic>)['ledger'] ?? const <dynamic>[]);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _settleMonth(Map<String, dynamic> row) async {
    try {
      await CompanyServerService.settleMerchantCoalitionClearinghouse(
        coalitionId: (row['coalition_id'] ?? row['coalitionId'] ?? '').toString(),
        toMerchantId: (row['to_merchant_id'] ?? row['toMerchantId'] ?? '').toString(),
        period: (row['period'] ?? '').toString(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clearinghouse_settlement_confirmed'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: kGold)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildUsageGuide(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'clearinghouse_detailed_ledger'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh),
                label: Text('clearinghouse_refresh'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ledger.isEmpty)
            Card(child: ListTile(title: Text('clearinghouse_no_ledger'.tr())))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('coalition_label'.tr())),
                  DataColumn(label: Text('clearinghouse_from'.tr())),
                  DataColumn(label: Text('clearinghouse_to'.tr())),
                  DataColumn(label: Text('clearinghouse_net'.tr())),
                  DataColumn(label: Text('clearinghouse_date'.tr())),
                  DataColumn(label: Text('clearinghouse_action'.tr())),
                ],
                rows: _ledger.map((row) {
                  final net = double.tryParse((row['net_points'] ?? row['netPoints'] ?? 0).toString()) ?? 0;
                  final settlementRow = _summary.firstWhere(
                    (entry) => (entry['coalition_id'] ?? entry['coalitionId'] ?? '').toString() == (row['coalition_id'] ?? '').toString(),
                    orElse: () => <String, dynamic>{},
                  );
                  return DataRow(
                    cells: [
                      DataCell(Text((row['coalition_name'] ?? row['coalitionName'] ?? '').toString())),
                      DataCell(Text((row['from_merchant'] ?? row['fromMerchant'] ?? '').toString())),
                      DataCell(Text((row['to_merchant'] ?? row['toMerchant'] ?? '').toString())),
                      DataCell(Text(net > 0 ? '+$net' : '$net')),
                      DataCell(Text((row['created_at'] ?? row['createdAt'] ?? '').toString())),
                      DataCell(
                        settlementRow.isEmpty
                            ? const Text('-')
                            : TextButton(
                                onPressed: () => _settleMonth(settlementRow),
                                child: Text('clearinghouse_settle'.tr()),
                              ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final cards = <Map<String, dynamic>>[
      {'label': 'clearinghouse_summary_points_issued'.tr(), 'value': _netValue(_summary, 'points_issued')},
      {'label': 'clearinghouse_summary_cross_redemptions'.tr(), 'value': _netValue(_summary, 'cross_redemptions')},
      {'label': 'clearinghouse_summary_net_balance'.tr(), 'value': _netValue(_summary, 'net_balance')},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, index) {
        final item = cards[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(item['value'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _netValue(List<Map<String, dynamic>> rows, String field) {
    double total = 0;
    for (final row in rows) {
      final value = double.tryParse((row[field] ?? row[field.replaceAll('_', '')] ?? 0).toString()) ?? 0;
      total += value;
    }
    return total.toStringAsFixed(0);
  }

  Widget _buildUsageGuide() {
    final steps = <String>[
      'clearinghouse_how_step_1'.tr(),
      'clearinghouse_how_step_2'.tr(),
      'clearinghouse_how_step_3'.tr(),
      'clearinghouse_how_step_4'.tr(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'clearinghouse_how_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'clearinghouse_internal_only_disclosure'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700, color: kInk),
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $step'),
              )),
        ],
      ),
    );
  }
}
