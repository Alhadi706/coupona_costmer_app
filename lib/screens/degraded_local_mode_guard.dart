import 'package:flutter/material.dart';

class DegradedLocalModeGuard extends StatelessWidget {
  final String merchantName;
  final bool isLocalOnly;

  const DegradedLocalModeGuard({
    super.key,
    required this.merchantName,
    this.isLocalOnly = true,
  });

  static Future<void> show(BuildContext context, {required String merchantName}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => DegradedLocalModeGuard(merchantName: merchantName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Merchant Token Exhausted'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 42),
          const SizedBox(height: 12),
          Text(
            'Merchant point balance exhausted. Points recorded locally for this store only.',
            style: const TextStyle(fontSize: 15),
          ),
          if (merchantName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Store: $merchantName',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            isLocalOnly
                ? 'Local points are redeemable only in-store until the merchant recharges their token balance.'
                : 'Coalition status restored.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Understood'),
        ),
      ],
    );
  }
}
