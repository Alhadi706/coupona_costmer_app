import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef SubscriptionsLoader =
    Future<List<Map<String, dynamic>>> Function(
      String? roleType,
      String? status,
    );
typedef SubscriptionAction = Future<Map<String, dynamic>> Function(String id);

class AdminSubscriptionsScreen extends StatefulWidget {
  final SubscriptionsLoader? loader;
  final SubscriptionAction? activate;
  final SubscriptionAction? expireTrial;
  final SubscriptionAction? endGrace;

  const AdminSubscriptionsScreen({
    super.key,
    this.loader,
    this.activate,
    this.expireTrial,
    this.endGrace,
  });

  @override
  State<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  bool _loading = true;
  String? _error;
  String _role = 'all';
  String _status = 'all';
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows =
          await (widget.loader ??
              (role, status) => CompanyServerService.getAdminSubscriptions(
                roleType: role,
                status: status,
              ))(
            _role == 'all' ? null : _role,
            _status == 'all' ? null : _status,
          );
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    final status = '${row['status']}';
    if (status == 'trial') {
      await (widget.expireTrial ??
          CompanyServerService.expireAdminSubscriptionTrial)(id);
    } else if (status == 'grace_period') {
      await (widget.endGrace ?? CompanyServerService.endAdminSubscriptionGrace)(
        id,
      );
    } else {
      await (widget.activate ?? CompanyServerService.activateAdminSubscription)(
        id,
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              _filter(
                ['all', 'merchant', 'brand'],
                _role,
                (value) => _role = value,
              ),
              _filter(
                ['all', 'trial', 'active', 'grace_period', 'suspended'],
                _status,
                (value) => _status = value,
              ),
            ],
          ),
        ),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _filter(
    List<String> values,
    String selected,
    ValueChanged<String> update,
  ) {
    return DropdownButton<String>(
      value: selected,
      items: values
          .map(
            (value) =>
                DropdownMenuItem(value: value, child: Text(_enumLabel(value))),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        update(value);
        _load();
      },
    );
  }

  String _enumLabel(String value) {
    const keys = <String, String>{
      'all': 'subscription_filter_all',
      'trial': 'subscription_status_trial',
      'active': 'subscription_status_active',
      'grace_period': 'subscription_status_grace_period',
      'suspended': 'subscription_status_suspended',
      'merchant': 'subscription_role_merchant',
      'brand': 'subscription_role_brand',
      'basic': 'subscription_plan_basic',
      'pro': 'subscription_plan_pro',
      'standard': 'subscription_plan_standard',
    };
    return (keys[value] ?? value).tr();
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (_, index) {
        final row = _rows[index];
        final status = '${row['status']}';
        final label = status == 'trial'
            ? 'subscription_end_trial'
            : status == 'grace_period'
            ? 'subscription_end_grace'
            : 'subscription_activate';
        return Card(
          child: ListTile(
            key: Key('subscription-${row['id']}'),
            title: Text('${row['ownerLabel'] ?? '-'}'),
            subtitle: Text(
              '${_enumLabel('${row['roleType']}')} • ${_enumLabel(status)} • ${_enumLabel('${row['planType'] ?? '-'}')}\n${row['nextBillingDate'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: status == 'active'
                ? const Icon(Icons.check_circle_outline)
                : FilledButton(
                    onPressed: () => _act(row),
                    child: Text(label.tr()),
                  ),
          ),
        );
      },
    );
  }
}
