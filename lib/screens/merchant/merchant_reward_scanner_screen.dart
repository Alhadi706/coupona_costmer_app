import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/reward_redemption.dart';
import '../../services/firestore/reward_redemption_repository.dart';

class MerchantRewardScannerScreen extends StatefulWidget {
  final String merchantId;
  const MerchantRewardScannerScreen({super.key, required this.merchantId});

  @override
  State<MerchantRewardScannerScreen> createState() =>
      _MerchantRewardScannerScreenState();
}

class _MerchantRewardScannerScreenState
    extends State<MerchantRewardScannerScreen> {
  late final RewardRedemptionRepository _redemptionRepository;
  final MobileScannerController _scannerController = MobileScannerController();
  RewardRedemption? _currentRedemption;
  String? _errorMessage;
  bool _isProcessingScan = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _redemptionRepository = RewardRedemptionRepository();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeCapture capture) {
    if (_isProcessingScan) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    setState(() {
      _isProcessingScan = true;
      _errorMessage = null;
    });
    _scannerController.stop();
    _lookupRedemption(value);
  }

  Future<void> _lookupRedemption(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] != 'reward_redeem') {
        throw const FormatException('invalid');
      }
      final redemptionId = data['id']?.toString();
      final code = data['code']?.toString();
      if (redemptionId == null || code == null) {
        throw const FormatException('invalid');
      }
      final redemption = await _redemptionRepository.fetchRedemption(
        redemptionId,
      );
      if (redemption == null || redemption.redeemCode != code) {
        throw const FormatException('invalid');
      }
      if (redemption.merchantId != widget.merchantId) {
        throw StateError('unauthorized');
      }
      if (redemption.isCompleted) {
        throw StateError('already_used');
      }
      if (redemption.isCancelled) {
        throw StateError('cancelled');
      }
      setState(() {
        _currentRedemption = redemption;
      });
    } catch (error) {
      setState(() {
        _currentRedemption = null;
        _errorMessage = _resolveError(error);
      });
      await _scannerController.start();
    } finally {
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    }
  }

  Future<void> _completeRedemption() async {
    final redemption = _currentRedemption;
    if (redemption == null) return;
    setState(() {
      _isCompleting = true;
      _errorMessage = null;
    });
    try {
      final cashierId =
          FirebaseAuth.instance.currentUser?.uid ?? widget.merchantId;
      await _redemptionRepository.completeRedemption(
        redemption: redemption,
        merchantId: widget.merchantId,
        cashierId: cashierId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_reward_scanner_success'.tr())),
      );
      setState(() => _currentRedemption = null);
      await _scannerController.start();
    } catch (error) {
      setState(() => _errorMessage = _resolveError(error));
      await _scannerController.start();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  String _resolveError(Object error) {
    if (error is StateError) {
      switch (error.message) {
        case 'unauthorized':
          return 'merchant_reward_scanner_invalid'.tr();
        case 'already_used':
          return 'merchant_reward_scanner_already_used'.tr();
        case 'cancelled':
          return 'merchant_reward_scanner_cancelled'.tr();
        case 'insufficient_points':
          return 'merchant_reward_scanner_insufficient'.tr();
        case 'redemption_expired':
          return 'merchant_reward_scanner_expired'.tr();
        case 'redemption_not_pending':
          return 'merchant_reward_scanner_already_used'.tr();
        default:
          return 'merchant_reward_scanner_error'.tr();
      }
    }
    return 'merchant_reward_scanner_invalid'.tr();
  }

  void _resetScanner() {
    setState(() {
      _currentRedemption = null;
      _errorMessage = null;
    });
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('merchant_reward_scanner_title'.tr()),
        actions: [
          IconButton(
            onPressed: _resetScanner,
            icon: const Icon(Icons.refresh),
            tooltip: 'merchant_reward_scanner_rescan'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleScan,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'merchant_reward_scanner_hint'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (_currentRedemption != null)
                  _RedemptionDetails(
                    redemption: _currentRedemption!,
                    onConfirm: _isCompleting ? null : _completeRedemption,
                    isLoading: _isCompleting,
                  )
                else if (_isProcessingScan)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RedemptionDetails extends StatelessWidget {
  final RewardRedemption redemption;
  final VoidCallback? onConfirm;
  final bool isLoading;
  const _RedemptionDetails({
    required this.redemption,
    required this.onConfirm,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              redemption.rewardTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'merchant_reward_scanner_customer'.tr(),
              value: redemption.customerName,
            ),
            _InfoRow(
              icon: Icons.workspace_premium_outlined,
              label: 'merchant_reward_scanner_points'.tr(),
              value: '${redemption.requiredPoints}',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onConfirm,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified),
              label: Text('merchant_reward_scanner_confirm'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value')),
        ],
      ),
    );
  }
}
