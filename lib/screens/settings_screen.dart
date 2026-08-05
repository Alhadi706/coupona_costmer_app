import 'package:flutter/material.dart';
import 'package:coupona_app/screens/offers_list_screen.dart';
import 'package:coupona_app/screens/wallet_engine_screen.dart';
import 'package:coupona_app/screens/my_rewards_screen.dart';
import 'users_screen.dart';
import 'package:coupona_app/screens/login_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/app_session.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;

  const SettingsScreen({super.key}) : embedded = false;

  const SettingsScreen.embedded({super.key}) : embedded = true;

  Widget _buildSettingsBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _AccountSection(),
        const Divider(height: 32),
        _LanguageSection(),
        const Divider(height: 32),
        const _NotificationsSection(),
        const Divider(height: 32),
        const _LocationPrivacySection(),
        const Divider(height: 32),
        const _DownloadDataSection(),
        const Divider(height: 32),
        // زر لعرض قائمة العروض
        ListTile(
          leading: const Icon(Icons.local_offer, color: Colors.deepPurple),
          title: Text('offers_list'.tr()),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OffersListScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
          title: Text('wallet_ledger'.tr()),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletEngineScreen()),
            );
          },
        ),
        const Divider(height: 32),
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
        automaticallyImplyLeading: false,
        title: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'menu_tooltip'.tr(),
                ),
              ),
            ),
            Center(
              child: Text(
                'settings_title'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 2,
      ),
      drawer: AppDrawer(),
      body: _buildSettingsBody(context),
    );
  }
}

void _showPlannedFeatureMessage(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('planned_feature_coming_soon'.tr(namedArgs: {'feature': featureName}))),
  );
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'account_section'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person),
          title: Text('profile'.tr()),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UsersScreen()),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock),
          title: Text('change_password'.tr()),
          onTap: () {
            _showPlannedFeatureMessage(context, 'change_password'.tr());
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text('logout'.tr()),
          onTap: () async {
            await AppSession.clear();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  final List<Map<String, String>> languages = const [
    {'code': 'ar', 'name': 'العربية'},
    {'code': 'en', 'name': 'English'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'tr', 'name': 'Türkçe'},
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'zh', 'name': '中文'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'id', 'name': 'Bahasa Indonesia'},
    {'code': 'ja', 'name': '日本語'},
    {'code': 'ko', 'name': '한국어'},
    {'code': 'bn', 'name': 'বাংলা'},
    {'code': 'ur', 'name': 'اردو'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'language_section'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.language),
          title: Text('change_language'.tr()),
          onTap: () async {
            String? selected = await showDialog<String>(
              context: context,
              builder: (context) => SimpleDialog(
                title: Text('choose_language'.tr()),
                children: languages.map((lang) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, lang['code']),
                  child: Text(lang['name']!),
                )).toList(),
              ),
            );
            if (selected != null) {
              context.setLocale(Locale(selected));
            }
          },
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'notifications_section'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications),
          title: Text('notification_settings'.tr()),
          onTap: () {
            _showPlannedFeatureMessage(context, 'notification_settings'.tr());
          },
        ),
      ],
    );
  }
}

class _LocationPrivacySection extends StatelessWidget {
  const _LocationPrivacySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'location_privacy_section'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on),
          title: Text('location_settings'.tr()),
          onTap: () {
            _showPlannedFeatureMessage(context, 'location_settings'.tr());
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip),
          title: Text('privacy_settings'.tr()),
          onTap: () {
            _showPlannedFeatureMessage(context, 'privacy_settings'.tr());
          },
        ),
      ],
    );
  }
}

class _DownloadDataSection extends StatelessWidget {
  const _DownloadDataSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'download_data_section'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download),
          title: Text('download_account_data'.tr()),
          onTap: () {
            _showPlannedFeatureMessage(context, 'download_account_data'.tr());
          },
        ),
      ],
    );
  }
}

class AppDrawer extends StatelessWidget {
  final ValueChanged<int>? onSelectHomeTab;

  const AppDrawer({super.key, this.onSelectHomeTab});

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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.person, size: 44, color: Colors.deepPurple),
                ),
                SizedBox(height: 8),
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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text('drawer_home'.tr()),
            onTap: () {
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 0,
                fallback: () => Navigator.of(context).popUntil((route) => route.isFirst),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: Text('drawer_categories'.tr()),
            onTap: () {
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 1,
                fallback: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OffersListScreen()),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text('drawer_favorites'.tr()),
            onTap: () {
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 4,
                fallback: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyRewardsScreen()),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('drawer_settings'.tr()),
            onTap: () {
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 3,
                fallback: () {},
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('drawer_about'.tr()),
            onTap: () {
              _showPlannedFeatureMessage(context, 'drawer_about'.tr());
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: Text('drawer_contact'.tr()),
            onTap: () {
              _showPlannedFeatureMessage(context, 'drawer_contact'.tr());
            },
          ),
        ],
      ),
    );
  }
}
