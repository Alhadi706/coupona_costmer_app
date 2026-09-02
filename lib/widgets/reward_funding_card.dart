import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef RewardFundingLoader = Future<Map<String, dynamic>> Function(String sourceType);
typedef RewardFunder = Future<Map<String, dynamic>> Function(String sourceType, int amount);

class RewardFundingCard extends StatefulWidget {
  final String sourceType;
  final RewardFundingLoader? loader;
  final RewardFunder? funder;

  const RewardFundingCard({super.key, required this.sourceType, this.loader, this.funder});

  @override
  State<RewardFundingCard> createState() => _RewardFundingCardState();
}

class _RewardFundingCardState extends State<RewardFundingCard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final summary = await (widget.loader ?? CompanyServerService.getRewardFundingSummary)(widget.sourceType);
      if (mounted) setState(() => _summary = summary);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fund() async {
    var amountText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('reward_funding_action', 'Fund reward escrow')),
        content: TextField(
          key: const Key('reward-funding-amount'),
          keyboardType: TextInputType.number,
          onChanged: (value) => amountText = value,
          decoration: InputDecoration(labelText: _tx('reward_funding_amount', 'Points to reserve')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_tx('cancel', 'Cancel'))),
          FilledButton(
            key: const Key('reward-funding-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tx('confirm', 'Confirm')),
          ),
        ],
      ),
    );
    final amount = int.tryParse(amountText.trim());
    if (confirmed != true || amount == null || amount <= 0) return;
    try {
      final result = await (widget.funder ??
          (sourceType, value) => CompanyServerService.fundRewardEscrow(sourceType, amount: value))(widget.sourceType, amount);
      if (mounted) setState(() => _summary = result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tx('reward_funding_failed', 'Unable to fund reward escrow.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('reward-funding-${widget.sourceType}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const LinearProgressIndicator()
            : _error != null
                ? ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(_tx('reward_funding_load_failed', 'Unable to load reward funding.')),
                    trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_tx('reward_funding_title', 'Reward funding'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text('${_tx('reward_funding_wallet', 'Wallet')}: ${_summary['walletBalance'] ?? 0}'),
                          Text('${_tx('reward_funding_escrow', 'Escrow')}: ${_summary['escrowBalance'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: Key('reward-funding-open-${widget.sourceType}'),
                        onPressed: _fund,
                        icon: const Icon(Icons.savings_outlined),
                        label: Text(_tx('reward_funding_action', 'Fund reward escrow')),
                      ),
                    ],
                  ),
      ),
    );
  }
}