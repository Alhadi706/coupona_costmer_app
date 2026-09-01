import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/company_server_service.dart';

class MerchantGiftTrigger extends StatefulWidget {
  const MerchantGiftTrigger({super.key});

  @override
  State<MerchantGiftTrigger> createState() => _MerchantGiftTriggerState();
}

class _MerchantGiftTriggerState extends State<MerchantGiftTrigger> {
  final TextEditingController _thresholdController = TextEditingController(text: '250');
  bool _loading = false;

  Future<void> _saveTrigger() async {
    final threshold = int.tryParse(_thresholdController.text.trim());
    if (threshold == null || threshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_gifting_invalid_threshold'.tr())),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await CompanyServerService.createMerchantGiftTrigger(
        thresholdPoints: threshold,
        merchantName: 'Hussam Tires',
        messageTemplate: 'Special gift from {merchant} for reaching {points} points! Pick your reward:',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_gifting_saved'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_gifting_screen_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'merchant_gifting_auto_trigger_title'.tr(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _thresholdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'merchant_gifting_required_points'.tr(),
                hintText: 'merchant_gifting_required_points_hint'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'merchant_gifting_auto_trigger_description'.tr(),
            ),
            const SizedBox(height: 12),
            _buildFlowClarification(),
            const SizedBox(height: 16),
            _buildUsageGuide(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _saveTrigger,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'merchant_gifting_saving'.tr() : 'merchant_gifting_save_trigger'.tr()),
              ),
            ),
            const SizedBox(height: 20),
            Text('merchant_gifting_example_message_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('merchant_gifting_example_message'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageGuide() {
    final steps = <String>[
      'merchant_gifting_how_step_1'.tr(),
      'merchant_gifting_how_step_2'.tr(),
      'merchant_gifting_how_step_3'.tr(),
      'merchant_gifting_how_step_4'.tr(),
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
            'merchant_gifting_how_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildFlowClarification() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'merchant_gifting_flow_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('merchant_gifting_flow_line_1'.tr()),
          const SizedBox(height: 4),
          Text('merchant_gifting_flow_line_2'.tr()),
          const SizedBox(height: 4),
          Text('merchant_gifting_flow_line_3'.tr()),
          const SizedBox(height: 4),
          Text('merchant_gifting_flow_line_4'.tr()),
        ],
      ),
    );
  }
}
