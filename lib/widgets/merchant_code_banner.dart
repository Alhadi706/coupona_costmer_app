import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/merchant_code_service.dart';

class MerchantCodeBanner extends StatelessWidget {
  MerchantCodeBanner({super.key, required this.merchantCode})
      : _codeService = MerchantCodeService();

  final String merchantCode;
  final MerchantCodeService _codeService;

  String get _prettyCode => _codeService.prettyPrint(merchantCode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'merchant_code_section_title'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'merchant_code_description'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(color: accent.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2, color: Colors.deepPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('merchant_id_label'.tr(), style: TextStyle(fontWeight: FontWeight.w600, color: accent)),
                        const SizedBox(height: 4),
                        SelectableText(
                          _prettyCode,
                          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 2, color: accent),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'merchant_code_copy'.tr(),
                    onPressed: () => _copyCode(context),
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showQrSheet(context),
                    icon: const Icon(Icons.qr_code),
                    label: Text('merchant_code_show_qr'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareCode(context),
                    icon: const Icon(Icons.share_outlined),
                    label: Text('merchant_code_share'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _prettyCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('merchant_code_copied'.tr())),
    );
  }

  void _showQrSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _MerchantQrSheet(code: _prettyCode),
    );
  }

  Future<void> _shareCode(BuildContext context) async {
    final text = '${'merchant_code_share_message'.tr()}: $_prettyCode';
    await Share.share(text);
  }
}

class _MerchantQrSheet extends StatelessWidget {
  const _MerchantQrSheet({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final qrColor = Colors.deepPurple.shade700;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'merchant_code_show_qr'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: code,
              size: 220,
              eyeStyle: QrEyeStyle(color: qrColor),
              dataModuleStyle: QrDataModuleStyle(color: qrColor),
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              code,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
            ),
            const SizedBox(height: 8),
            Text('merchant_code_print_hint'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('close'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
