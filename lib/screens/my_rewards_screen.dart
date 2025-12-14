import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/customer_profile.dart';
import '../models/reward.dart';
import '../models/reward_redemption.dart';
import '../services/firestore/customer_repository.dart';
import '../services/firestore/reward_repository.dart';
import '../services/firestore/reward_redemption_repository.dart';

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen> {
  late final RewardRepository _rewardRepository;
  late final CustomerRepository _customerRepository;
  late final RewardRedemptionRepository _rewardRedemptionRepository;
  Stream<List<Reward>>? _rewardsStream;
  Stream<CustomerProfile?>? _profileStream;
  String? _userId;
  bool _isRedeemingReward = false;

  @override
  void initState() {
    super.initState();
    _rewardRepository = RewardRepository();
    _customerRepository = CustomerRepository();
    _rewardRedemptionRepository = RewardRedemptionRepository();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    final uid = _userId;
    if (uid != null) {
      _rewardsStream = _rewardRepository.watchActiveRewards();
      _profileStream = _customerRepository.watchCustomer(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text(
        'my_rewards_title'.tr(),
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.deepPurple.shade700,
    );

    if (_profileStream == null || _rewardsStream == null || _userId == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(child: Text('my_rewards_login_prompt'.tr())),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<CustomerProfile?>(
              stream: _profileStream!,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = snapshot.data;
                final double totalPoints = profile?.totalPoints ?? 0;
                return StreamBuilder<List<Reward>>(
                  stream: _rewardsStream!,
                  builder: (context, rewardsSnapshot) {
                    if (rewardsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rewards = rewardsSnapshot.data ?? const <Reward>[];
                    final target = _computeNextRewardTarget(profile, rewards);
                    final hasRewards = rewards.isNotEmpty;
                    final double progress;
                    if (target == null) {
                      progress = hasRewards && profile != null ? 1.0 : 0.0;
                    } else {
                      final requiredPoints = target.reward.requiredPoints
                          .toDouble()
                          .clamp(1.0, double.infinity);
                      progress = (target.pointsAvailable / requiredPoints)
                          .clamp(0.0, 1.0);
                    }
                    final statusText = target == null
                        ? (hasRewards
                              ? 'my_rewards_all_claimed'.tr()
                              : 'my_rewards_no_rewards'.tr())
                        : 'my_rewards_points_needed'.tr(
                            namedArgs: {
                              'points': target.pointsNeeded.ceil().toString(),
                            },
                          );

                    return Center(
                      child: Column(
                        children: [
                          Text(
                            'my_rewards_points_balance'.tr(),
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            totalPoints.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.deepPurple.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusText,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          _buildPointsBreakdown(profile),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            // زر زيد أرباحي (مكان بارز أعلى الجوائز)
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'my_rewards_how_to_increase'.tr(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text('my_rewards_tip1'.tr()),
                          SizedBox(height: 8),
                          Text('my_rewards_tip2'.tr()),
                          SizedBox(height: 8),
                          Text('my_rewards_tip3'.tr()),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_up, color: Colors.white),
                label: Text(
                  'my_rewards_increase_btn'.tr(),
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // الجوائز القريبة والممكنة
            Text(
              'my_rewards_available_prizes'.tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 220,
              child: StreamBuilder<List<Reward>>(
                stream: _rewardsStream!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rewards = snapshot.data ?? const <Reward>[];
                  if (rewards.isEmpty) {
                    return Center(child: Text('my_rewards_no_rewards'.tr()));
                  }
                  return StreamBuilder<CustomerProfile?>(
                    stream: _profileStream!,
                    builder: (context, profileSnap) {
                      final profile = profileSnap.data;
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: rewards.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final reward = rewards[index];
                          final availablePoints = _availablePointsForReward(
                            profile,
                            reward,
                          );
                          final canRedeem =
                              availablePoints >= reward.requiredPoints &&
                              reward.isActive;
                          return _RewardCard(
                            reward: reward,
                            canRedeem: canRedeem,
                            availablePoints: availablePoints,
                            onRedeem: profile == null
                                ? null
                                : () => _handleRedeemRequest(reward, profile),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _PointsHistory(profileStream: _profileStream!, userId: _userId!),
            const SizedBox(height: 24),
            StreamBuilder<CustomerProfile?>(
              stream: _profileStream!,
              builder: (context, snapshot) {
                final totalPoints = snapshot.data?.totalPoints ?? 0;
                if (totalPoints <= 0) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(child: Text('my_rewards_expiry_alert'.tr())),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
            // خريطة مصغرة (مكان المحلات)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text('my_rewards_shops_map'.tr())),
            ),
            const SizedBox(height: 24),
            // رسم بياني مبسط (تجريبي)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text('my_rewards_points_chart'.tr())),
            ),
          ],
        ),
      ),
    );
  }

  _NextRewardTarget? _computeNextRewardTarget(
    CustomerProfile? profile,
    List<Reward> rewards,
  ) {
    if (profile == null || rewards.isEmpty) return null;
    _NextRewardTarget? target;
    for (final reward in rewards) {
      if (!reward.isActive) continue;
      if (reward.endDate.toDate().isBefore(DateTime.now())) continue;
      final available = _availablePointsForReward(profile, reward);
      final needed = reward.requiredPoints.toDouble() - available;
      if (needed <= 0) {
        // User already qualifies for this reward, no need to treat it as "next"
        continue;
      }
      if (target == null || needed < target.pointsNeeded) {
        target = _NextRewardTarget(
          reward: reward,
          pointsAvailable: available,
          pointsNeeded: needed,
        );
      }
    }
    return target;
  }

  double _availablePointsForReward(CustomerProfile? profile, Reward reward) {
    if (profile == null) return 0;
    switch (reward.ownerType) {
      case 'brand':
        if ((reward.brandId ?? '').isNotEmpty) {
          return (profile.brandPoints[reward.brandId] ?? 0).toDouble();
        }
        break;
      case 'global':
        return profile.totalPoints;
      default:
        final storePoints = profile.merchantPoints[reward.merchantId];
        if (storePoints != null) {
          return storePoints.toDouble();
        }
        break;
    }
    return profile.totalPoints;
  }

  Widget _buildPointsBreakdown(CustomerProfile? profile) {
    if (profile == null) {
      return Text('my_rewards_login_prompt'.tr());
    }
    final merchantEntries = profile.merchantPoints.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final brandEntries = profile.brandPoints.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        if (merchantEntries.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'my_rewards_store_breakdown'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: merchantEntries
                    .take(3)
                    .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                    .toList(),
              ),
            ],
          ),
        if (brandEntries.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'my_rewards_brand_breakdown'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: brandEntries
                    .take(3)
                    .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                    .toList(),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _handleRedeemRequest(
    Reward reward,
    CustomerProfile profile,
  ) async {
    if (_isRedeemingReward) return;
    final userId = _userId;
    if (userId == null) return;
    setState(() => _isRedeemingReward = true);
    try {
      final redemption = await _rewardRedemptionRepository
          .createOrReuseRedemption(
            reward: reward,
            merchantName: _resolveMerchantLabel(reward),
            customerId: profile.id,
            customerName: profile.name.isNotEmpty ? profile.name : 'Guest',
          );
      if (!mounted) return;
      await _showRedemptionSheet(redemption, profile);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('reward_redemption_failed'.tr())));
    } finally {
      if (mounted) setState(() => _isRedeemingReward = false);
    }
  }

  String _resolveMerchantLabel(Reward reward) {
    if (reward.ownerName.isNotEmpty) return reward.ownerName;
    switch (reward.ownerType) {
      case 'brand':
        return 'my_rewards_brand_program'.tr();
      case 'global':
        return 'my_rewards_global_program'.tr();
      default:
        return 'my_rewards_store_program'.tr();
    }
  }

  Future<void> _showRedemptionSheet(
    RewardRedemption redemption,
    CustomerProfile profile,
  ) async {
    if (!mounted) return;
    final qrData = _rewardRedemptionRepository.buildQrPayload(redemption);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _RewardRedemptionSheet(
          redemption: redemption,
          qrData: qrData,
          onCancel: () async {
            await _rewardRedemptionRepository.cancelRedemption(
              redemptionId: redemption.id,
              customerId: profile.id,
            );
          },
        ),
      ),
    );
  }
}

class _NextRewardTarget {
  final Reward reward;
  final double pointsAvailable;
  final double pointsNeeded;
  const _NextRewardTarget({
    required this.reward,
    required this.pointsAvailable,
    required this.pointsNeeded,
  });
}

class _RewardCard extends StatelessWidget {
  final Reward reward;
  final bool canRedeem;
  final double availablePoints;
  final VoidCallback? onRedeem;
  const _RewardCard({
    required this.reward,
    required this.canRedeem,
    required this.availablePoints,
    this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = reward.endDate.toDate().isBefore(DateTime.now());
    final active = canRedeem && !isExpired;
    final pendingEligible = !active && availablePoints >= reward.requiredPoints;
    return Card(
      color: active ? Colors.green.shade100 : Colors.white,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(_ownerLabel(context)),
                backgroundColor: Colors.deepPurple.shade50,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reward.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              reward.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              'my_rewards_points'.tr(
                namedArgs: {'points': reward.requiredPoints.toString()},
              ),
              style: const TextStyle(color: Colors.deepPurple),
            ),
            const SizedBox(height: 4),
            Text(
              'merchant_rewards_date_fmt'.tr(
                args: [
                  DateFormat.yMd().format(reward.startDate.toDate()),
                  DateFormat.yMd().format(reward.endDate.toDate()),
                ],
              ),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'my_rewards_available_points'.tr(
                namedArgs: {'points': availablePoints.toStringAsFixed(0)},
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (active)
              FilledButton(
                onPressed: onRedeem ?? () => _showRedeemDialog(context),
                child: Text('my_rewards_receive_btn'.tr()),
              )
            else
              OutlinedButton(
                onPressed: () => _showDetailsDialog(context),
                child: Text(
                  pendingEligible
                      ? 'my_rewards_wait_btn'.tr()
                      : 'my_rewards_details_btn'.tr(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRedeemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('my_rewards_receive_prize'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('my_rewards_show_qr'.tr()),
            const SizedBox(height: 16),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              alignment: Alignment.center,
              child: Text(
                '${reward.id}\n${reward.title}',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text('my_rewards_after_scan'.tr()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('my_rewards_close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('my_rewards_prize_details'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('my_rewards_prize_name'.tr(namedArgs: {'name': reward.title})),
            Text(
              'my_rewards_prize_required_points'.tr(
                namedArgs: {'points': reward.requiredPoints.toString()},
              ),
            ),
            if (reward.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reward.description),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('my_rewards_close'.tr()),
          ),
        ],
      ),
    );
  }

  String _ownerLabel(BuildContext context) {
    if (reward.ownerName.isNotEmpty) return reward.ownerName;
    switch (reward.ownerType) {
      case 'brand':
        return 'my_rewards_brand_program'.tr();
      case 'global':
        return 'my_rewards_global_program'.tr();
      default:
        return 'my_rewards_store_program'.tr();
    }
  }
}

class _RewardRedemptionSheet extends StatelessWidget {
  final RewardRedemption redemption;
  final String qrData;
  final Future<void> Function()? onCancel;
  const _RewardRedemptionSheet({
    required this.redemption,
    required this.qrData,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final expiresAt = redemption.expiresAt?.toDate();
    final expiresLabel = expiresAt == null
        ? null
        : DateFormat.yMd(context.locale.toString()).add_Hm().format(expiresAt);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'reward_redemption_title'.tr(
                namedArgs: {'reward': redemption.rewardTitle},
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: QrEyeStyle(color: Colors.deepPurple.shade700),
                  dataModuleStyle: QrDataModuleStyle(
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'reward_redemption_instruction'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'reward_redemption_waiting'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (expiresLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                'reward_redemption_expires_at'.tr(
                  namedArgs: {'time': expiresLabel},
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text('reward_redemption_show_code'.tr()),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onCancel == null
                  ? null
                  : () async {
                      await onCancel!.call();
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.close),
              label: Text('reward_redemption_cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsHistory extends StatelessWidget {
  final Stream<CustomerProfile?> profileStream;
  final String userId;
  const _PointsHistory({required this.profileStream, required this.userId});

  @override
  Widget build(BuildContext context) {
    final historyStream = FirebaseFirestore.instance
        .collection('customers')
        .doc(userId)
        .collection('pointsHistory')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'my_rewards_points_history'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'my_rewards_points_history'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('my_rewards_history_empty'.tr()),
            ],
          );
        }

        final rows = docs.map(_PointHistoryEntry.fromDoc).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'my_rewards_points_history'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DataTable(
              columns: [
                DataColumn(label: Text('my_rewards_date'.tr())),
                DataColumn(label: Text('my_rewards_amount'.tr())),
                DataColumn(label: Text('my_rewards_source'.tr())),
                DataColumn(label: Text('my_rewards_balance'.tr())),
              ],
              rows: rows
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text(entry.dateLabel(context))),
                        DataCell(
                          Text(
                            entry.formattedAmount,
                            style: TextStyle(
                              color: entry.amount >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                        DataCell(Text(entry.sourceLabel(context))),
                        DataCell(Text(entry.balanceLabel)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _PointHistoryEntry {
  _PointHistoryEntry({
    required this.amount,
    required this.balance,
    required this.source,
    required this.createdAt,
    required this.metadata,
  });

  final double amount;
  final double balance;
  final String source;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  factory _PointHistoryEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAtRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    }
    final metadataRaw = data['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(metadataRaw)
        : const <String, dynamic>{};
    return _PointHistoryEntry(
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      source: data['source']?.toString() ?? 'transaction',
      createdAt: createdAt,
      metadata: metadata,
    );
  }

  String dateLabel(BuildContext context) {
    if (createdAt == null) {
      return 'my_rewards_history_pending'.tr();
    }
    final locale = context.locale.toString();
    return DateFormat.yMd(locale).add_Hm().format(createdAt!);
  }

  String get formattedAmount {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${amount.toStringAsFixed(0)}';
  }

  String get balanceLabel => balance.toStringAsFixed(0);

  String sourceLabel(BuildContext context) {
    late final String sourceKey;
    switch (source) {
      case 'invoice':
        sourceKey = 'my_rewards_history_source_invoice';
        break;
      case 'report_compensation':
        sourceKey = 'my_rewards_history_source_report';
        break;
      default:
        sourceKey = 'my_rewards_history_source_manual';
        break;
    }
    final baseLabel = sourceKey.tr();
    final details = _contextDetails();
    return details.isEmpty ? baseLabel : '$baseLabel · $details';
  }

  String _contextDetails() {
    if (metadata.isEmpty) return '';
    if (metadata['invoiceNumber'] != null &&
        metadata['invoiceNumber'].toString().isNotEmpty) {
      return metadata['invoiceNumber'].toString();
    }
    if (metadata['merchantName'] != null &&
        metadata['merchantName'].toString().isNotEmpty) {
      return metadata['merchantName'].toString();
    }
    if (metadata['reportId'] != null &&
        metadata['reportId'].toString().isNotEmpty) {
      return '#${metadata['reportId']}';
    }
    return '';
  }
}
