import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class ClearinghouseErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ClearinghouseErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
      key: const Key('clearinghouse-load-error'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: kMerchantMuted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text('retry'.tr())),
        ]),
      );
}

class ClearinghouseContent extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> ledger;
  final List<Map<String, dynamic>> disputes;
  final bool settling;
  final bool Function(Map<String, dynamic>) canSettle;
  final VoidCallback onSettleAll;
  final ValueChanged<Map<String, dynamic>> onSettleRow;
  final void Function(Map<String, dynamic>, String) onRespondToDispute;
  final ValueChanged<Map<String, dynamic>> onDownloadReceipt;

  const ClearinghouseContent({super.key, required this.summary, required this.members, required this.ledger, required this.disputes, required this.settling, required this.canSettle, required this.onSettleAll, required this.onSettleRow, required this.onRespondToDispute, required this.onDownloadReceipt});

  double _number(dynamic value) => double.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final issued = _number(summary['issuedPoints']);
    final redeemed = _number(summary['redeemedPoints']);
    final net = _number(summary['netBalance']) * _number(summary['pointValue'] ?? 1);
    final pendingCount = members.where(canSettle).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _KpiGrid(issued: issued, redeemed: redeemed, net: net),
      const SizedBox(height: 16),
      _Section(
        title: 'clearinghouse_member_matrix'.tr(),
        trailing: FilledButton.icon(
          key: const Key('clearinghouse-settle-all'),
          onPressed: pendingCount == 0 || settling ? null : onSettleAll,
          icon: settling ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.account_balance_outlined),
          label: Text('clearinghouse_settle_net'.tr()),
        ),
        child: members.isEmpty
            ? _EmptyState(icon: Icons.handshake_outlined, label: 'clearinghouse_no_members'.tr())
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('clearinghouse_partner'.tr())),
                    DataColumn(label: Text('clearinghouse_exchanged'.tr())),
                    DataColumn(label: Text('clearinghouse_net_amount'.tr())),
                    DataColumn(label: Text('clearinghouse_status'.tr())),
                    DataColumn(label: Text('clearinghouse_action'.tr())),
                  ],
                  rows: members.map((row) {
                    final amount = _number(row['net_amount']);
                    return DataRow(cells: [
                      DataCell(Text((row['partner_merchant'] ?? '-').toString())),
                      DataCell(Text('${row['exchanged_points'] ?? row['total_points'] ?? 0}')),
                      DataCell(Text('${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(2)} ${'currency_lyd'.tr()}', style: TextStyle(color: amount >= 0 ? kTeal : Colors.deepOrange.shade700, fontWeight: FontWeight.w700))),
                      DataCell(_StatusBadge(status: (row['status'] ?? 'pending').toString())),
                      DataCell(IconButton(tooltip: 'clearinghouse_settle'.tr(), onPressed: canSettle(row) && !settling ? () => onSettleRow(row) : null, icon: const Icon(Icons.check_circle_outline))),
                    ]);
                  }).toList(growable: false),
                ),
              ),
      ),
      const SizedBox(height: 16),
      _HistoryAndDisputes(ledger: ledger, disputes: disputes, onRespondToDispute: onRespondToDispute, onDownloadReceipt: onDownloadReceipt),
    ]);
  }
}

class _KpiGrid extends StatelessWidget {
  final double issued;
  final double redeemed;
  final double net;
  const _KpiGrid({required this.issued, required this.redeemed, required this.net});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _MetricCard(width: width, icon: Icons.add_chart, label: 'clearinghouse_summary_points_issued'.tr(), value: issued.toStringAsFixed(0), color: kIndigo),
          _MetricCard(width: width, icon: Icons.redeem_outlined, label: 'clearinghouse_summary_cross_redemptions'.tr(), value: redeemed.toStringAsFixed(0), color: kGold),
          _MetricCard(width: width, icon: Icons.account_balance_wallet_outlined, label: 'clearinghouse_summary_net_balance'.tr(), value: '${net >= 0 ? '+' : ''}${net.toStringAsFixed(2)} ${'currency_lyd'.tr()}', color: net >= 0 ? kTeal : Colors.deepOrange.shade700, badge: net >= 0 ? 'clearinghouse_owed_to_you'.tr() : 'clearinghouse_you_owe'.tr()),
        ]);
      });
}

class _MetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? badge;
  const _MetricCard({required this.width, required this.icon, required this.label, required this.value, required this.color, this.badge});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 132,
        child: Card(
          margin: EdgeInsets.zero,
          color: kMerchantCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kMerchantBorder)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: kMerchantMuted, fontWeight: FontWeight.w600)))]),
              const Spacer(),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: kPointsNumberStyle(size: 23, color: color))),
                if (badge != null) _Badge(label: badge!, color: color),
              ]),
            ]),
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        color: kMerchantCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kMerchantBorder)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

class _HistoryAndDisputes extends StatelessWidget {
  final List<Map<String, dynamic>> ledger;
  final List<Map<String, dynamic>> disputes;
  final void Function(Map<String, dynamic>, String) onRespondToDispute;
  final ValueChanged<Map<String, dynamic>> onDownloadReceipt;
  const _HistoryAndDisputes({required this.ledger, required this.disputes, required this.onRespondToDispute, required this.onDownloadReceipt});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: _Section(
          title: 'clearinghouse_audit'.tr(),
          child: Column(children: [
            TabBar(tabs: [Tab(text: 'clearinghouse_history'.tr()), Tab(text: '${'brand_clearinghouse_disputes'.tr()} (${disputes.where((item) => item['status'] == 'open').length})')]),
            SizedBox(height: 260, child: TabBarView(children: [
              ledger.isEmpty
                  ? _EmptyState(icon: Icons.receipt_long_outlined, label: 'clearinghouse_no_history'.tr())
                  : ListView.separated(
                      itemCount: ledger.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final row = ledger[index];
                        return ListTile(
                          leading: const Icon(Icons.verified_outlined, color: kTeal),
                          title: Text((row['coalition_name'] ?? row['to_merchant'] ?? '-').toString()),
                          subtitle: Text('${row['created_at'] ?? row['settled_at'] ?? '-'}  •  #${row['id'] ?? '-'}'),
                          trailing: IconButton(tooltip: 'clearinghouse_download_receipt'.tr(), onPressed: () => onDownloadReceipt(row), icon: const Icon(Icons.picture_as_pdf_outlined)),
                        );
                      },
                    ),
              disputes.isEmpty
                  ? _EmptyState(icon: Icons.fact_check_outlined, label: 'brand_clearinghouse_disputes_empty'.tr())
                  : ListView.builder(
                      itemCount: disputes.length,
                      itemBuilder: (_, index) {
                        final dispute = disputes[index];
                        return ExpansionTile(
                          title: Text((dispute['brandName'] ?? '-').toString()),
                          subtitle: _StatusBadge(status: (dispute['status'] ?? 'open').toString()),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          children: [
                            Align(alignment: AlignmentDirectional.centerStart, child: Text((dispute['reason'] ?? '').toString())),
                            if (dispute['status'] == 'open') OverflowBar(children: [
                              TextButton(onPressed: () => onRespondToDispute(dispute, 'rejected'), child: Text('settlement_dispute_reject'.tr())),
                              FilledButton(onPressed: () => onRespondToDispute(dispute, 'resolved'), child: Text('settlement_dispute_resolve'.tr())),
                            ]),
                          ],
                        );
                      },
                    ),
            ])),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 44, color: kMerchantMuted), const SizedBox(height: 10), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: kMerchantMuted))]),
      ));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = status == 'completed' || status == 'resolved' ? kTeal : status == 'rejected' ? Colors.red.shade700 : kGold;
    return _Badge(label: 'clearinghouse_status_$status'.tr(), color: color);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}