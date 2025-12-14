import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../models/reward.dart';
import '../../services/firebase_service.dart';
import '../../services/firestore/customer_repository.dart';
import '../../services/firestore/notification_repository.dart';
import '../../services/firestore/reward_repository.dart';

class MerchantNotificationsScreen extends StatefulWidget {
  final String merchantId;
  const MerchantNotificationsScreen({super.key, required this.merchantId});

  @override
  State<MerchantNotificationsScreen> createState() =>
      _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState
    extends State<MerchantNotificationsScreen> {
  late final NotificationRepository _notificationRepository;
  late final CustomerRepository _customerRepository;
  late final RewardRepository _rewardRepository;

  @override
  void initState() {
    super.initState();
    _notificationRepository = NotificationRepository();
    _customerRepository = CustomerRepository();
    _rewardRepository = RewardRepository();
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    await _notificationRepository.markAsRead(notification.id);
  }

  void _handleNotificationTap(AppNotification notification) {
    if (notification.type == 'report' && notification.metadata.isNotEmpty) {
      _showReportActions(notification);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_notifications_title'.tr())),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationRepository.watchNotifications(widget.merchantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_notifications_error'.tr()));
          }
          final notifications = snapshot.data ?? const [];
          if (notifications.isEmpty) {
            return Center(child: Text('merchant_notifications_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: notifications.length,
            itemBuilder: (_, index) {
              final notification = notifications[index];
              return Dismissible(
                key: ValueKey(notification.id),
                background: Container(
                  color: Colors.green,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await _markAsRead(notification);
                    return false;
                  }
                  return false;
                },
                child: Card(
                  color: notification.isRead
                      ? Colors.white
                      : Colors.deepPurple.shade50,
                  child: ListTile(
                    title: Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(notification.body),
                    onTap: () => _handleNotificationTap(notification),
                    trailing: notification.isRead
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(
                            onPressed: () => _markAsRead(notification),
                            child: Text(
                              'merchant_notifications_mark_read'.tr(),
                            ),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showReportActions(AppNotification notification) {
    final metadata = notification.metadata;
    if (metadata.isEmpty) return;
    _markAsRead(notification);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'merchant_report_details_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _ReportDetailRow(
                  label: 'merchant_report_customer_label'.tr(),
                  value: metadata['customerName'] ?? '—',
                ),
                _ReportDetailRow(
                  label: 'merchant_report_issue_label'.tr(),
                  value: metadata['issueType'] ?? '—',
                ),
                _ReportDetailRow(
                  label: 'merchant_report_product_label'.tr(),
                  value: metadata['productName'] ?? '—',
                ),
                if ((metadata['description'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(metadata['description'].toString()),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.message_outlined),
                      onPressed: () => _promptSendMessage(metadata),
                      label: Text('merchant_report_message_button'.tr()),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.stars_outlined),
                      onPressed: () => _promptSendReward(metadata),
                      label: Text('merchant_report_reward_button'.tr()),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_card),
                      onPressed: () => _promptSendPoints(metadata),
                      label: Text('merchant_report_points_button'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptSendMessage(Map<String, dynamic> metadata) async {
    final customerId = metadata['customerId']?.toString();
    if (customerId == null || customerId.isEmpty) return;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('merchant_report_message_dialog_title'.tr()),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'merchant_report_message_hint'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('merchant_report_send'.tr()),
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty) return;
    await _notificationRepository.createNotification(
      userId: customerId,
      title: 'report_response_message_title'.tr(
        namedArgs: {'merchant': metadata['merchantName'] ?? ''},
      ),
      body: result,
      type: 'report_response',
      metadata: {
        'reportId': metadata['reportId'],
        'merchantId': widget.merchantId,
      },
    );
    await _updateReport(metadata['reportId'], {
      'status': 'responded',
      'lastResponseType': 'message',
      'lastResponseAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_report_message_sent'.tr())),
      );
    }
  }

  Future<void> _promptSendPoints(Map<String, dynamic> metadata) async {
    final customerId = metadata['customerId']?.toString();
    if (customerId == null || customerId.isEmpty) return;
    final controller = TextEditingController(text: '25');
    final amount = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('merchant_report_points_dialog_title'.tr()),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'merchant_report_points_placeholder'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                Navigator.pop(context, parsed);
              },
              child: Text('merchant_report_send'.tr()),
            ),
          ],
        );
      },
    );
    if (amount == null || amount <= 0) return;

    await _customerRepository.incrementPoints(
      customerId: customerId,
      merchantId: widget.merchantId,
      points: amount,
      source: 'report_compensation',
      metadata: {
        'reportId': metadata['reportId']?.toString(),
        'merchantName': metadata['merchantName'] ?? '',
      },
    );

    await _notificationRepository.createNotification(
      userId: customerId,
      title: 'report_points_awarded_title'.tr(
        namedArgs: {'merchant': metadata['merchantName'] ?? ''},
      ),
      body: 'report_points_awarded_body'.tr(
        namedArgs: {'points': amount.toStringAsFixed(0)},
      ),
      type: 'points_bonus',
      metadata: {
        'reportId': metadata['reportId'],
        'merchantId': widget.merchantId,
        'points': amount,
      },
    );

    await _updateReport(metadata['reportId'], {
      'status': 'rewarded_points',
      'bonusPoints': FieldValue.increment(amount),
      'lastResponseType': 'points',
      'lastResponseAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_report_points_sent'.tr())),
      );
    }
  }

  Future<void> _promptSendReward(Map<String, dynamic> metadata) async {
    final customerId = metadata['customerId']?.toString();
    if (customerId == null || customerId.isEmpty) return;
    final rewards = await _rewardRepository
        .watchRewards(widget.merchantId, onlyActive: true)
        .first;
    if (!mounted) return;
    if (rewards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_report_no_rewards'.tr())),
      );
      return;
    }
    final reward = await showModalBottomSheet<Reward>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return ListTile(
                title: Text(reward.title),
                subtitle: Text(
                  reward.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  'my_rewards_points'.tr(
                    namedArgs: {'points': reward.requiredPoints.toString()},
                  ),
                ),
                onTap: () => Navigator.pop(context, reward),
              );
            },
          ),
        );
      },
    );
    if (reward == null) return;

    await _notificationRepository.createNotification(
      userId: customerId,
      title: 'report_reward_gift_title'.tr(
        namedArgs: {'merchant': metadata['merchantName'] ?? ''},
      ),
      body: 'report_reward_gift_body'.tr(namedArgs: {'reward': reward.title}),
      type: 'reward_gift',
      metadata: {
        'reportId': metadata['reportId'],
        'merchantId': widget.merchantId,
        'rewardId': reward.id,
        'rewardTitle': reward.title,
      },
    );

    await _updateReport(metadata['reportId'], {
      'status': 'rewarded_prize',
      'rewardId': reward.id,
      'rewardTitle': reward.title,
      'lastResponseType': 'reward',
      'lastResponseAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_report_reward_sent'.tr())),
      );
    }
  }

  Future<void> _updateReport(dynamic reportId, Map<String, dynamic> data) {
    if (reportId == null) return Future.value();
    return FirebaseService.firestore
        .collection('reports')
        .doc(reportId.toString())
        .set(data, SetOptions(merge: true));
  }
}

class _ReportDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReportDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}
