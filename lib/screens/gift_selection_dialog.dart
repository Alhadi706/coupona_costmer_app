import 'package:flutter/material.dart';

class GiftSelectionDialog extends StatelessWidget {
  final String merchantName;
  final int thresholdPoints;
  final List<Map<String, dynamic>> vouchers;

  const GiftSelectionDialog({
    super.key,
    required this.merchantName,
    required this.thresholdPoints,
    required this.vouchers,
  });

  static Future<void> show(
    BuildContext context, {
    required String merchantName,
    required int thresholdPoints,
    List<Map<String, dynamic>>? vouchers,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => GiftSelectionDialog(
        merchantName: merchantName,
        thresholdPoints: thresholdPoints,
        vouchers: vouchers ?? const <Map<String, dynamic>>[
          {'title': 'Free Meal at Al-Naseem', 'subtitle': 'Dinner voucher'},
          {'title': 'Car Wash at Al-Rabee', 'subtitle': 'Express wash'},
          {'title': 'Coffee Break at Zintuti', 'subtitle': 'Two free coffees'},
          {'title': 'Express Repair at Ashraf', 'subtitle': 'Service credit'},
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose your gift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Special gift from $merchantName for reaching $thresholdPoints points! Pick your reward:',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...vouchers.map((voucher) {
            final title = (voucher['title'] ?? 'Reward').toString();
            final subtitle = (voucher['subtitle'] ?? '').toString();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, textAlign: TextAlign.left),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }
}
