import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/company_server_service.dart';

/// Customer coalition gift redemption dialog with Co-Branded Gratitude
/// Implements Pro-Rata Multi-Sponsor Coalition Engine v3
class CustomerRedeemCoalitionGiftDialog extends StatefulWidget {
  final String coalitionId;
  final String coalitionName;

  const CustomerRedeemCoalitionGiftDialog({
    super.key,
    required this.coalitionId,
    required this.coalitionName,
  });

  @override
  State<CustomerRedeemCoalitionGiftDialog> createState() => _CustomerRedeemCoalitionGiftDialogState();
}

class _CustomerRedeemCoalitionGiftDialogState extends State<CustomerRedeemCoalitionGiftDialog> {
  bool _loadingBalances = true;
  bool _loadingGifts = true;
  bool _redeeming = false;

  Map<String, dynamic>? _balances;
  List<dynamic> _gifts = [];
  String? _selectedGiftId;
  dynamic _selectedGift;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadBalances(),
      _loadGifts(),
    ]);
  }

  Future<void> _loadBalances() async {
    try {
      final balances = await CompanyServerService.getCustomerCoalitionBalances(widget.coalitionId);
      setState(() {
        _balances = balances;
        _loadingBalances = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBalances = false;
      });
    }
  }

  Future<void> _loadGifts() async {
    try {
      final catalog = await CompanyServerService.getCoalitionGiftCatalog(widget.coalitionId);
      setState(() {
        _gifts = catalog['gifts'] ?? [];
        _loadingGifts = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingGifts = false;
      });
    }
  }

  Future<void> _redeemGift() async {
    if (_selectedGiftId == null || _selectedGift == null) return;

    // Find fulfiller merchant (the one who created the gift)
    final fulfillerMerchantId = _selectedGift['created_by_merchant_id'];
    if (fulfillerMerchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid gift configuration')),
      );
      return;
    }

    setState(() => _redeeming = true);

    try {
      final result = await CompanyServerService.redeemCoalitionGift(
        giftId: _selectedGiftId!,
        fulfillerMerchantId: fulfillerMerchantId,
      );

      if (!mounted) return;

      // Show success dialog with co-branded message
      _showSuccessDialog(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('customer_redeem_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    final giftTitle = result['gift_title'] ?? '';
    final sponsors = result['sponsors'] as List<dynamic>? ?? [];
    final coBrandedMessage = result['co_branded_message'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text('customer_redeem_success_title'.tr())),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'customer_redeem_success_message'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      giftTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (sponsors.isNotEmpty) ...[
                Text(
                  'customer_redeem_sponsors_title'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...sponsors.map((sponsor) => _buildSponsorLine(sponsor)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    coBrandedMessage,
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true); // Return success to caller
            },
            child: Text('customer_redeem_close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorLine(dynamic sponsor) {
    final merchantName = sponsor['merchantName'] ?? 'Unknown';
    final pointsUsed = sponsor['pointsUsed'] ?? 0;
    final percentage = sponsor['percentage'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.store, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'customer_redeem_sponsor_line'.tr(namedArgs: {
                'name': merchantName,
                'points': pointsUsed.toString(),
                'percentage': percentage.toStringAsFixed(1),
              }),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _loadingBalances || _loadingGifts;
    final totalPoints = _balances?['total_points'] ?? 0;

    return AlertDialog(
      title: Text('customer_redeem_gift_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      'customer_redeem_error'.tr(namedArgs: {'error': _error!}),
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Points balance
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'customer_redeem_your_points'.tr(),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    'customer_redeem_total_points'.tr(namedArgs: {'points': totalPoints.toString()}),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gift selection
                      Text(
                        'customer_redeem_select_gift'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_gifts.isEmpty)
                        const Center(child: Text('No gifts available'))
                      else
                        ...(_gifts.map((gift) => _buildGiftOption(gift, totalPoints)).toList()),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _redeeming ? null : () => Navigator.of(context).pop(),
          child: Text('coalition_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: (_selectedGiftId == null || _redeeming) ? null : _redeemGift,
          child: Text(_redeeming ? 'customer_redeem_redeeming'.tr() : 'customer_redeem_confirm'.tr()),
        ),
      ],
    );
  }

  Widget _buildGiftOption(dynamic gift, int totalPoints) {
    final id = gift['id'];
    final title = gift['title'] ?? '';
    final description = gift['description'] ?? '';
    final requiredPoints = gift['required_points'] ?? 0;
    final isSelected = _selectedGiftId == id;
    final canAfford = totalPoints >= requiredPoints;

    return GestureDetector(
      onTap: canAfford
          ? () {
              setState(() {
                _selectedGiftId = id;
                _selectedGift = gift;
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.blue, size: 20)
                else
                  Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: canAfford ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: canAfford ? Colors.black87 : Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'customer_redeem_required_points'.tr(namedArgs: {'points': requiredPoints.toString()}),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: canAfford ? Colors.blue : Colors.red,
                  ),
                ),
                if (!canAfford)
                  Text(
                    'customer_redeem_insufficient'.tr(),
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
