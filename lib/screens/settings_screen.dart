import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:coupona_app/screens/community_screen.dart';
import 'package:coupona_app/screens/customer_coalitions_screen.dart';
import 'package:coupona_app/screens/customer_gifts_screen.dart';
import 'package:coupona_app/screens/customer_reports_screen.dart';
import 'package:coupona_app/screens/my_rewards_screen.dart';
import 'package:coupona_app/screens/offers_list_screen.dart';

import 'settings_screen_sections.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;

  const SettingsScreen({super.key}) : embedded = false;

  const SettingsScreen.embedded({super.key}) : embedded = true;

  Widget _buildSettingsBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SettingsAccountSection(),
        Divider(height: 32),
        SettingsLanguageSection(),
        Divider(height: 32),
        SettingsNotificationsSection(),
        Divider(height: 32),
        SettingsLocationPrivacySection(),
        Divider(height: 32),
        SettingsDownloadDataSection(),
        Divider(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return _buildSettingsBody(context);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          'settings_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'menu_tooltip'.tr(),
            ),
          ),
        ],
        toolbarHeight: 60,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 2,
      ),
      drawer: const AppDrawer(),
      body: _buildSettingsBody(context),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final ValueChanged<int>? onSelectHomeTab;
  final String? currentRole;

  const AppDrawer({super.key, this.onSelectHomeTab, this.currentRole});

  void _selectHomeTabOrNavigate(
    BuildContext context, {
    required int tabIndex,
    required VoidCallback fallback,
  }) {
    Navigator.of(context).pop();
    if (onSelectHomeTab != null) {
      onSelectHomeTab!(tabIndex);
      return;
    }
    fallback();
  }

  bool get _isCustomer => true;

  void _pushScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _roleHomeScreen() {
    return const OffersListScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 44, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'drawer_username'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'drawer_email'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text('drawer_home'.tr()),
            onTap: () => _pushScreen(context, _roleHomeScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.local_offer),
            title: Text('offers'.tr()),
            onTap: () => _pushScreen(context, const OffersListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: Text('my_gifts_title'.tr()),
            onTap: () => _pushScreen(context, const CustomerGiftsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('شبكة التحالفات'),
            onTap: () => _pushScreen(context, const CustomerCoalitionsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text('home_bottom_wallet'.tr()),
            onTap: () => _selectHomeTabOrNavigate(
              context,
              tabIndex: 3,
              fallback: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyRewardsScreen()),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups),
            title: Text('home_bottom_communities'.tr()),
            onTap: () {
              if (!_isCustomer) {
                _pushScreen(context, const CommunityScreen());
                return;
              }
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 2,
                fallback: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyRewardsScreen()),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: Text('home_bottom_reports'.tr()),
            onTap: () {
              _pushScreen(context, const CustomerReportsScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('settings_title'.tr()),
            onTap: () {
              if (!_isCustomer) {
                _pushScreen(context, const SettingsScreen.embedded());
                return;
              }
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 4,
                fallback: () => _pushScreen(context, const SettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('drawer_about'.tr()),
            onTap: () {
              showPlannedFeatureMessage(context, 'drawer_about'.tr());
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: Text('drawer_contact'.tr()),
            onTap: () {
              showPlannedFeatureMessage(context, 'drawer_contact'.tr());
            },
          ),
        ],
      ),
    );
  }
}
