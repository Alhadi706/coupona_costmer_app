import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class RewardQrCodeScreen extends StatefulWidget {
	const RewardQrCodeScreen({super.key});

	@override
	State<RewardQrCodeScreen> createState() => _RewardQrCodeScreenState();
}

class _RewardQrCodeScreenState extends State<RewardQrCodeScreen> {
	final TextEditingController _pointsCostController = TextEditingController();
	final TextEditingController _sourceIdController = TextEditingController();

	String _sourceType = 'merchant';
	String _rewardKind = 'physical';
	bool _submitting = false;
	String? _pickupQrCode;
	String? _status;
	String? _error;
	String? _claimRequestId;

	@override
	void dispose() {
		_pointsCostController.dispose();
		_sourceIdController.dispose();
		super.dispose();
	}

	Future<void> _createClaim() async {
		final pointsCost = int.tryParse(_pointsCostController.text.trim());
		if (pointsCost == null || pointsCost <= 0) {
			setState(() {
				_error = 'Please enter a valid integer cost.';
			});
			return;
		}

		setState(() {
			_submitting = true;
			_error = null;
			_pickupQrCode = null;
			_status = null;
		});

		try {
			_claimRequestId ??= const Uuid().v4();
			final data = await CompanyServerService.createRewardClaim(
				pointsCost: pointsCost,
				sourceType: _sourceType,
				sourceId: _sourceIdController.text.trim(),
				rewardKind: _rewardKind,
				idempotencyKey: _claimRequestId,
			);
			_claimRequestId = null;
			setState(() {
				_pickupQrCode = (data['pickupQrCode'] ?? '').toString();
				_status = (data['status'] ?? '').toString();
			});
		} catch (e) {
			setState(() {
				_error = e.toString();
			});
		} finally {
			setState(() {
				_submitting = false;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: kIndigo,
			appBar: AppBar(title: const Text('Reward QR Code')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					TextField(
						controller: _pointsCostController,
						keyboardType: TextInputType.number,
						decoration: const InputDecoration(labelText: 'Points Cost'),
					),
					const SizedBox(height: 8),
					DropdownButtonFormField<String>(
						initialValue: _sourceType,
						decoration: const InputDecoration(labelText: 'Source Type'),
						items: const [
							DropdownMenuItem(value: 'merchant', child: Text('merchant')),
							DropdownMenuItem(value: 'brand', child: Text('brand')),
						],
						onChanged: (value) {
							if (value != null) setState(() => _sourceType = value);
						},
					),
					TextField(
						controller: _sourceIdController,
						decoration: const InputDecoration(labelText: 'Source ID'),
					),
					const SizedBox(height: 8),
					DropdownButtonFormField<String>(
						initialValue: _rewardKind,
						decoration: const InputDecoration(labelText: 'Reward Kind'),
						items: const [
							DropdownMenuItem(value: 'physical', child: Text('physical')),
							DropdownMenuItem(value: 'digital', child: Text('digital')),
						],
						onChanged: (value) {
							if (value != null) setState(() => _rewardKind = value);
						},
					),
					const SizedBox(height: 12),
					ElevatedButton(
						onPressed: _submitting ? null : _createClaim,
						child: Text(_submitting ? 'Creating...' : 'Create claim and QR'),
					),
					if (_error != null) ...[
						const SizedBox(height: 10),
						Text(
							_error!,
							style: kBodyTextStyle(
								size: 13,
								weight: FontWeight.w600,
								color: kGold,
							),
						),
					],
					if (_status != null) ...[
						const SizedBox(height: 10),
						Text('Claim status: $_status'),
					],
					if (_pickupQrCode != null && _pickupQrCode!.isNotEmpty) ...[
						const SizedBox(height: 16),
						const Text('Pickup QR code (show this to cashier):'),
						const SizedBox(height: 8),
						Center(
							child: QrImageView(
								data: _pickupQrCode!,
								size: 220,
							),
						),
						const SizedBox(height: 8),
						SelectableText(_pickupQrCode!),
					],
				],
			),
		);
	}
}

