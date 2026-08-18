import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

class RoleRequestsStatusScreen extends StatelessWidget {
  const RoleRequestsStatusScreen({super.key});

  String _localizeStatus(String status) {
    switch (status.toLowerCase()) {
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
      default:
        return 'status_unknown'.tr();
    }
  }

  String _localizeRole(String roleType) {
    switch (roleType.toLowerCase()) {
      case 'merchant':
        return 'role_merchant'.tr();
      case 'brand':
        return 'role_brand'.tr();
      case 'cashier':
        return 'role_cashier'.tr();
      default:
        return 'role_customer'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('role_request_status_title'.tr())),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: CompanyServerService.getMyRoleRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Center(child: Text('role_request_no_items'.tr()));
          }

          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final status = (row['status'] ?? '').toString();
              final roleType = (row['roleType'] ?? '').toString();
              final reason = (row['rejectionReason'] ?? '').toString();
              final localizedStatus = _localizeStatus(status);
              final localizedRole = _localizeRole(roleType);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('role_request_item_title'.tr(namedArgs: {'role': localizedRole})),
                  subtitle: Text(
                    reason.isEmpty
                        ? 'role_request_item_status'.tr(namedArgs: {'status': localizedStatus})
                        : 'role_request_item_status_reason'.tr(namedArgs: {
                            'status': localizedStatus,
                            'reason': reason,
                          }),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}