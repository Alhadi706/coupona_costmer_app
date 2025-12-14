import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/reward.dart';
import '../../services/firestore/reward_repository.dart';

class MerchantRewardsScreen extends StatefulWidget {
  final String merchantId;
  const MerchantRewardsScreen({super.key, required this.merchantId});

  @override
  State<MerchantRewardsScreen> createState() => _MerchantRewardsScreenState();
}

class _MerchantRewardsScreenState extends State<MerchantRewardsScreen> {
  late final RewardRepository _rewardRepository;

  @override
  void initState() {
    super.initState();
    _rewardRepository = RewardRepository();
  }

  void _openRewardForm({Reward? reward}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _MerchantRewardForm(
            merchantId: widget.merchantId,
            rewardRepository: _rewardRepository,
            reward: reward,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_rewards_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRewardForm(),
        icon: const Icon(Icons.add_card_outlined),
        label: Text('merchant_rewards_add'.tr()),
      ),
      body: StreamBuilder<List<Reward>>(
        stream: _rewardRepository.watchRewards(widget.merchantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_rewards_error'.tr()));
          }
          final rewards = snapshot.data ?? const [];
          if (rewards.isEmpty) {
            return Center(child: Text('merchant_rewards_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: rewards.length,
            itemBuilder: (_, index) {
              final reward = rewards[index];
              final now = DateTime.now();
              final isExpired = reward.endDate.toDate().isBefore(now);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Icon(Icons.card_giftcard, color: Colors.deepPurple.shade700),
                  ),
                  title: Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('merchant_rewards_points_fmt'.tr(args: [reward.requiredPoints.toString()])),
                      Text('merchant_rewards_date_fmt'.tr(args: [
                        DateFormat.yMd().format(reward.startDate.toDate()),
                        DateFormat.yMd().format(reward.endDate.toDate()),
                      ])),
                      if (isExpired)
                        Text('merchant_rewards_expired'.tr(), style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('merchant_rewards_claimed_fmt'.tr(args: [reward.claimedCount.toString()])),
                      Switch(
                        value: reward.isActive,
                        onChanged: (value) {
                          final updated = Reward(
                            id: reward.id,
                            merchantId: reward.merchantId,
                            title: reward.title,
                            description: reward.description,
                            type: reward.type,
                            requiredPoints: reward.requiredPoints,
                            startDate: reward.startDate,
                            endDate: reward.endDate,
                            isActive: value,
                            claimedCount: reward.claimedCount,
                            ownerType: reward.ownerType,
                            ownerName: reward.ownerName,
                            brandId: reward.brandId,
                            imageUrl: reward.imageUrl,
                          );
                          _rewardRepository.saveReward(updated);
                        },
                      ),
                    ],
                  ),
                  onTap: () => _openRewardForm(reward: reward),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MerchantRewardForm extends StatefulWidget {
  final String merchantId;
  final RewardRepository rewardRepository;
  final Reward? reward;
  const _MerchantRewardForm({
    required this.merchantId,
    required this.rewardRepository,
    this.reward,
  });

  @override
  State<_MerchantRewardForm> createState() => _MerchantRewardFormState();
}

class _MerchantRewardFormState extends State<_MerchantRewardForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pointsController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final reward = widget.reward;
    _titleController = TextEditingController(text: reward?.title ?? '');
    _descriptionController = TextEditingController(text: reward?.description ?? '');
    _pointsController = TextEditingController(
      text: reward != null ? reward.requiredPoints.toString() : '',
    );
    _startDate = reward?.startDate.toDate();
    _endDate = reward?.endDate.toDate();
    _isActive = reward?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_rewards_dates_required'.tr())),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_rewards_dates_invalid'.tr())),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final reward = Reward(
        id: widget.reward?.id ?? '',
        merchantId: widget.merchantId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: 'manual',
        requiredPoints: int.tryParse(_pointsController.text.trim()) ?? 0,
        startDate: Timestamp.fromDate(_startDate!),
        endDate: Timestamp.fromDate(_endDate!),
        isActive: _isActive,
        claimedCount: widget.reward?.claimedCount ?? 0,
        ownerType: widget.reward?.ownerType ?? 'merchant',
        ownerName: widget.reward?.ownerName ?? '',
        brandId: widget.reward?.brandId,
        imageUrl: widget.reward?.imageUrl,
      );
      if (widget.reward == null) {
        await widget.rewardRepository.createReward(reward.toMap());
      } else {
        await widget.rewardRepository.saveReward(reward);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_rewards_save_error'.tr())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reward != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'merchant_rewards_edit_title'.tr() : 'merchant_rewards_add_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'merchant_rewards_field_title'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'merchant_rewards_field_description'.tr()),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'merchant_rewards_field_points'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_startDate == null
                        ? 'merchant_rewards_field_start'.tr()
                        : DateFormat.yMd().format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_endDate == null
                        ? 'merchant_rewards_field_end'.tr()
                        : DateFormat.yMd().format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('merchant_rewards_field_active'.tr()),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    child: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('save'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
