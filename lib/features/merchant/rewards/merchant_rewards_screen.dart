import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../services/company_server_service.dart';
import '../../../theme/design_tokens.dart';
import 'merchant_reward_kpis.dart';
import 'reward_funding_card.dart';
import 'reward_item_card.dart';
import 'reward_claims_list.dart';
import 'create_reward_wizard_dialog.dart';

class MerchantRewardsScreen extends StatefulWidget {
  final String sourceType;
  final RewardFundingLoader? rewardFundingLoader;
  final RewardFunder? rewardFunder;

  const MerchantRewardsScreen({
    super.key,
    required this.sourceType,
    this.rewardFundingLoader,
    this.rewardFunder,
  });

  @override
  State<MerchantRewardsScreen> createState() => _MerchantRewardsScreenState();
}

class _MerchantRewardsScreenState extends State<MerchantRewardsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _claims = [];
  String _rewardFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rewards = await CompanyServerService.getMerchantRewards(widget.sourceType);
      final claims = await CompanyServerService.getMerchantRewardClaims(widget.sourceType);
      if (mounted) {
        setState(() {
          _rewards = rewards;
          _claims = claims;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleRewardActive(String rewardId, bool isActive) async {
    try {
      await CompanyServerService.updateMerchantReward(rewardId, isActive: !isActive);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تحديث حالة الجائزة: $error')),
        );
      }
    }
  }

  Future<void> _createReward() async {
    await showDialog(
      context: context,
      builder: (context) => CreateRewardWizardDialog(
        onSave: (data) async {
          await CompanyServerService.createMerchantReward(
            widget.sourceType,
            rewardName: data.rewardName,
            points: data.points,
            description: data.description,
            imageUrl: data.imageUrl,
            kind: data.kind,
            expiresAt: data.expiresAt,
            quantityLimit: data.quantityLimit,
            pickupInstructions: data.pickupInstructions,
            drawEnabled: data.drawEnabled,
          );
          await _load();
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredRewards {
    return _rewards.where((reward) {
      final active = reward['isActive'] == true;
      return _rewardFilter == 'all' ||
             (_rewardFilter == 'active' && active) ||
             (_rewardFilter == 'inactive' && !active);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('فشل في تحميل بيانات الجوائز'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MerchantRewardKPIs(sourceType: widget.sourceType),
            const SizedBox(height: 16),
            RewardFundingCard(
              sourceType: widget.sourceType,
              loader: widget.rewardFundingLoader,
              funder: widget.rewardFunder,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: _rewardFilter == 'all',
                  onSelected: (_) => setState(() => _rewardFilter = 'all'),
                ),
                ChoiceChip(
                  label: const Text('النشطة'),
                  selected: _rewardFilter == 'active',
                  onSelected: (_) => setState(() => _rewardFilter = 'active'),
                ),
                ChoiceChip(
                  label: const Text('الموقوفة'),
                  selected: _rewardFilter == 'inactive',
                  onSelected: (_) => setState(() => _rewardFilter = 'inactive'),
                ),
                FilledButton.icon(
                  onPressed: _createReward,
                  icon: const Icon(Icons.add),
                  label: const Text('إنشاء جائزة'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_filteredRewards.isEmpty)
              Card(
                child: ListTile(
                  title: const Text('لا توجد جوائز مضافة لهذا المتجر.'),
                ),
              )
            else
              ..._filteredRewards.map((reward) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RewardItemCard(
                    reward: reward,
                    onToggleActive: () => _toggleRewardActive(reward['id'].toString(), reward['isActive'] == true),
                    onTap: () {
                      // Handle reward tap for editing
                    },
                  ),
                );
              }),
            const SizedBox(height: 16),
            RewardClaimsList(claims: _claims),
          ],
        ),
      ),
    );
  }
}