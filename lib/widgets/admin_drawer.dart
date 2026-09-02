import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/design_tokens.dart';
import '../screens/settings_screen.dart';

class AdminDrawer extends StatelessWidget {
  final String currentRole;
  final VoidCallback onSwitchRole;

  const AdminDrawer({
    super.key,
    required this.currentRole,
    required this.onSwitchRole,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: kInk),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: kWhite,
                  child: Icon(Icons.admin_panel_settings, color: kInk),
                ),
                const SizedBox(height: 12),
                Text(
                  'admin_portal'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'System Owner',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                )
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text('admin_tab_analytics'.tr()),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('admin_users'.tr()),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to AdminUsersScreen
            },
          ),
          ListTile(
            leading: const Icon(Icons.report_problem),
            title: Text('admin_reports'.tr()),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to AdminReportsScreen
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('settings_title'.tr()),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified),
            title: Text('admin_pending_approvals'.tr()),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to AdminApprovalsScreen
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text('my_roles_title'.tr()),
            onTap: () {
              Navigator.pop(context);
              onSwitchRole();
            },
          ),
        ],
      ),
    );
  }
}
