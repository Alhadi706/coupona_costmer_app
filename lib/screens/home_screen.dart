import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'admin_dashboard_screen.dart';
import 'brand_dashboard_screen.dart';
import 'cashier_dashboard_screen.dart';
import 'community_screen.dart';
import 'home_content_screen.dart';
import 'merchant_dashboard_screen.dart';
import 'my_rewards_screen.dart';
import 'my_roles_screen.dart';
import 'report_issue_screen.dart';
import 'scan_invoice_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String phone;
  final String age;
  final String gender;
  final String? initialRoleOverride;
  final int categoryBarType;

  const HomeScreen({
    super.key,
    required this.phone,
    required this.age,
    required this.gender,
    this.initialRoleOverride,
    this.categoryBarType = 2,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _activeRole = 'customer';
  List<Map<String, dynamic>> _notifications = const <Map<String, dynamic>>[];
  int _unreadNotifications = 0;
  int _groupMessageUnread = 0;

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _activeRole = widget.initialRoleOverride ?? 'customer';
    _loadNotifications();
    if (widget.initialRoleOverride == null) {
      _loadActiveRole();
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final rows = await CompanyServerService.getMyNotifications();
      if (!mounted) return;
      final unread = rows.where((n) => n['isRead'] != true).length;
      final groupUnread = rows.where((n) {
        if (n['isRead'] == true) return false;
        final type = (n['type'] ?? '').toString();
        return type == 'group_message' || type == 'group_message_new';
      }).length;
      setState(() {
        _notifications = rows;
        _unreadNotifications = unread;
        _groupMessageUnread = groupUnread;
      });
    } catch (_) {
      // Keep shell usable even if notifications endpoint is temporarily unavailable.
    }
  }

  Future<void> _openNotificationsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: _notifications.isEmpty
                ? Center(child: Text('notifications_empty'.tr()))
                : ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['isRead'] == true;
                      final title = (n['title'] ?? 'notifications_default_title'.tr()).toString();
                      final body = (n['body'] ?? '').toString();
                      return ListTile(
                        leading: Icon(
                          isRead ? Icons.notifications_none : Icons.notifications_active,
                          color: isRead ? kInk.withValues(alpha: 0.6) : Colors.red,
                        ),
                        title: Text(title),
                        subtitle: Text(body),
                        trailing: isRead ? null : const Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                        onTap: () async {
                          final id = (n['id'] ?? '').toString();
                          if (id.isNotEmpty && !isRead) {
                            await CompanyServerService.markNotificationRead(id);
                            await _loadNotifications();
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
    await _loadNotifications();
  }

  Future<void> _loadActiveRole() async {
    final role = await AppSession.role();
    if (!mounted) return;
    setState(() {
      _activeRole = role;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _loadNotifications();
  }

  Color _roleColor() {
    switch (_activeRole) {
      case 'admin':
        return kInk;
      default:
        return kTealDark;
    }
  }

  Future<void> _openRolesScreen() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MyRolesScreen(currentRole: _activeRole),
      ),
    );

    if (selected == null || selected.isEmpty || selected == _activeRole) {
      return;
    }

    await AppSession.setRole(selected);
    if (!mounted) return;
    setState(() {
      _activeRole = selected;
      _selectedIndex = 0;
    });
  }

  Widget _buildRoleSurface() {
    switch (_activeRole) {
      case 'merchant':
        return const KeyedSubtree(
          key: ValueKey<String>('merchant_mode_surface'),
          child: MerchantDashboardScreen.embedded(),
        );
      case 'brand':
        return const KeyedSubtree(
          key: ValueKey<String>('brand_mode_surface'),
          child: BrandDashboardScreen.embedded(),
        );
      case 'cashier':
        return const KeyedSubtree(
          key: ValueKey<String>('cashier_mode_surface'),
          child: CashierDashboardScreen.embedded(),
        );
      case 'admin':
        return const KeyedSubtree(
          key: ValueKey<String>('admin_mode_surface'),
          child: AdminDashboardScreen.embedded(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> customerTabs = <Widget>[
      HomeContentScreen(
        onOpenOffersTab: () => _onItemTapped(1),
        onOpenPeerAdsTab: () => _onItemTapped(2),
      ),
      MyRewardsScreen(),
      const CommunityScreen.embedded(),
      const ReportIssueScreen(),
      const SettingsScreen.embedded(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr(), style: const TextStyle(color: kWhite)),
        backgroundColor: _roleColor(),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openNotificationsSheet,
            tooltip: 'notifications_title'.tr(),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openRolesScreen,
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'my_roles_title'.tr(),
          ),
        ],
      ),
      drawer: AppDrawer(
        onSelectHomeTab: _onItemTapped,
        currentRole: _activeRole,
      ),
      body: _activeRole == 'customer'
          ? KeyedSubtree(
              key: const ValueKey<String>('customer_mode_surface'),
              child: customerTabs[_selectedIndex],
            )
          : _buildRoleSurface(),
      floatingActionButton: _activeRole == 'customer'
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanInvoiceScreen()),
                );
              },
              backgroundColor: kTeal,
              child: const Icon(Icons.camera_alt, color: kWhite),
            )
          : null,
      bottomNavigationBar: _activeRole != 'customer'
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: kTeal,
              unselectedItemColor: kInk.withValues(alpha: 0.6),
              backgroundColor: kWhite,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: _tx('home_bottom_home', 'Home'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: const Icon(Icons.account_balance_wallet),
                  label: _tx('home_bottom_wallet', 'Wallet'),
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.groups_outlined),
                      if (_groupMessageUnread > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _groupMessageUnread > 99 ? '99+' : '$_groupMessageUnread',
                              style: const TextStyle(color: kWhite, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.groups),
                  label: _tx('home_bottom_communities', 'Communities'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.flag_outlined),
                  activeIcon: const Icon(Icons.flag),
                  label: _tx('home_bottom_reports', 'Reports'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: _tx('home_bottom_account', 'My Account'),
                ),
              ],
            ),
    );
  }
}
