import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'role_activation_request_screen.dart';
import 'role_requests_status_screen.dart';
import 'team_invitations_screen.dart';

class MyRolesScreen extends StatefulWidget {
  final String currentRole;
  final Future<Map<String, dynamic>> Function()? rolesLoader;

  const MyRolesScreen({
    super.key,
    required this.currentRole,
    this.rolesLoader,
  });

  @override
  State<MyRolesScreen> createState() => _MyRolesScreenState();
}

class _MyRolesScreenState extends State<MyRolesScreen> {
  late Future<Map<String, dynamic>> _rolesFuture;

  Future<Map<String, dynamic>> _loadRoles() {
    return (widget.rolesLoader ?? CompanyServerService.getMyRoles)().timeout(
      const Duration(seconds: 10),
    );
  }

  void _retryLoadRoles() {
    setState(() {
      _rolesFuture = _loadRoles();
    });
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _rolesFuture = _loadRoles();
  }

  String _statusText(bool active) {
    return active
        ? _tx('role_status_active', 'role_status_active')
        : _tx('role_status_inactive', 'role_status_inactive');
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'merchant':
        return _tx('role_merchant', 'merchant');
      case 'brand':
        return _tx('role_brand', 'brand');
      case 'cashier':
        return _tx('role_cashier', 'cashier');
      default:
        return _tx('role_customer', 'customer');
    }
  }

  String _localizeLifecycleStatus(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'pending_admin_review':
        return 'status_pending_admin_review'.tr();
      case 'pending_review':
        return 'status_pending_review'.tr();
      case 'approved':
        return 'status_approved'.tr();
      case 'active':
        return 'status_active'.tr();
      case 'trial':
        return 'status_trial'.tr();
      case 'grace_period':
        return 'status_grace_period'.tr();
      case 'suspended':
        return 'status_suspended'.tr();
      case 'rejected':
        return 'status_rejected'.tr();
      case 'under_review':
        return 'status_under_review'.tr();
      case 'pending':
        return 'status_pending'.tr();
      case 'none':
      case '':
        return 'status_none'.tr();
      default:
        return 'status_unknown'.tr();
    }
  }

  Widget _roleTile({
    required String roleKey,
    required bool active,
    required bool selected,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
      ),
      child: ListTile(
          leading: Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? kTeal : kInk.withValues(alpha: 0.55),
          ),
          title: Text(_tx(roleKey, roleKey)),
          subtitle: Text(_statusText(active)),
          trailing: TextButton(
            onPressed: active ? onTap : null,
            child: Text(_tx('role_switch', 'Switch')),
          ),
      ),
    );
  }

  String _subscriptionStatusFor(List<dynamic> subscriptions, String roleType) {
    for (final row in subscriptions) {
      if (row is Map && row['roleType'] == roleType) {
        return (row['status'] ?? '').toString();
      }
    }
    return 'none';
  }

  Widget _buildCashierAssociationCard(List<dynamic> cashierRows, bool cashierActive) {
    final rows = cashierRows.whereType<Map>().toList(growable: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kTeal, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('role_cashier_association_title', 'Cashier association'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (rows.isEmpty)
              Text(_tx('role_cashier_not_assigned', 'Not assigned as cashier yet.'))
            else
              ...rows.map((row) {
                final merchantId = (row['merchantId'] ?? '-').toString();
                final branchId = (row['branchId'] ?? '-').toString();
                final isActive = row['isActive'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'role_cashier_assigned_line'.tr(
                      namedArgs: {
                        'merchantId': merchantId,
                        'branchId': branchId,
                        'status': _statusText(isActive),
                      },
                    ),
                  ),
                );
              }),
            if (cashierActive) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop('cashier'),
                child: Text(_tx('role_cashier_switch_enabled', 'Switch to cashier mode')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tx('my_roles_title', 'My Roles')),
        backgroundColor: kTealDark,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _rolesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _tx('my_roles_load_failed', 'Unable to load roles. Please sign in again or retry.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retryLoadRoles,
                      icon: const Icon(Icons.refresh),
                      label: Text(_tx('retry', 'Retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final customerActive = data['customer'] == true;
          final merchantActive = data['merchant'] == true;
          final brandActive = data['brand'] == true;
          final cashierRows = (data['cashier'] as List?) ?? const <dynamic>[];
          final cashierActive = cashierRows.any(
            (row) => row is Map && row['isActive'] == true,
          );
          final subscriptions = (data['subscriptions'] as List?) ?? const <dynamic>[];
          final merchantSubscription = _subscriptionStatusFor(subscriptions, 'merchant');
          final brandSubscription = _subscriptionStatusFor(subscriptions, 'brand');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'my_roles_active_role'.tr(namedArgs: {'role': _roleLabel(widget.currentRole)}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                _tx('my_roles_section_owned', 'My roles'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _roleTile(
                roleKey: 'role_customer',
                active: customerActive,
                selected: widget.currentRole == 'customer',
                borderColor: kTeal,
                onTap: () => Navigator.of(context).pop('customer'),
              ),
              _roleTile(
                roleKey: 'role_merchant',
                active: merchantActive,
                selected: widget.currentRole == 'merchant',
                borderColor: kGold,
                onTap: () => Navigator.of(context).pop('merchant'),
              ),
              Text(
                'role_subscription_status'.tr(
                  namedArgs: {'status': _localizeLifecycleStatus(merchantSubscription)},
                ),
              ),
              const SizedBox(height: 8),
              _roleTile(
                roleKey: 'role_brand',
                active: brandActive,
                selected: widget.currentRole == 'brand',
                borderColor: kGold,
                onTap: () => Navigator.of(context).pop('brand'),
              ),
              Text(
                'role_subscription_status'.tr(
                  namedArgs: {'status': _localizeLifecycleStatus(brandSubscription)},
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tx('my_roles_section_granted_permissions', 'Granted permissions'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _buildCashierAssociationCard(cashierRows, cashierActive),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TeamInvitationsScreen()),
                ),
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: Text(_tx('team_invitations_title', 'Team invitations')),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const RoleActivationRequestScreen(roleType: 'merchant'),
                    ),
                  );
                  if (changed == true && mounted) {
                    _retryLoadRoles();
                  }
                },
                child: Text(_tx('activate_merchant_role', 'Activate merchant role')),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const RoleActivationRequestScreen(roleType: 'brand'),
                    ),
                  );
                  if (changed == true && mounted) {
                    _retryLoadRoles();
                  }
                },
                child: Text(_tx('activate_brand_role', 'Activate brand role')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoleRequestsStatusScreen()),
                  );
                },
                child: Text(_tx('role_request_status_title', 'Role Request Status')),
              ),
            ],
          );
        },
      ),
    );
  }
}
