import 'package:flutter/material.dart';
import 'package:coupona_app/screens/offers_list_screen.dart';
import 'package:coupona_app/screens/community_screen.dart';
import 'package:coupona_app/screens/report_issue_screen.dart';
import 'package:coupona_app/screens/wallet_engine_screen.dart';
import 'package:coupona_app/screens/my_rewards_screen.dart';
import 'users_screen.dart';
import 'package:coupona_app/screens/login_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/app_session.dart';
import '../services/company_server_service.dart';
import 'package:coupona_app/theme/design_tokens.dart';
import 'admin_dashboard_screen.dart';
import 'brand_dashboard_screen.dart';
import 'cashier_dashboard_screen.dart';
import 'merchant_dashboard_screen.dart';

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
          leading: const Icon(Icons.local_offer, color: kTeal),
          title: Text('offers_list'.tr()),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OffersListScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet, color: kTeal),
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
          leading: const Icon(Icons.manage_accounts),
          title: Text('account_settings'.tr()),
          onTap: () async {
            await showDialog(
              context: context,
              builder: (_) => const _AccountSettingsDialog(),
            );
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

class _AccountSettingsDialog extends StatefulWidget {
  const _AccountSettingsDialog();

  @override
  State<_AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<_AccountSettingsDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('valid_email'.tr());
      return;
    }

    setState(() => _saving = true);
    try {
      final currentEmail = await AppSession.email() ?? '';
      if (email != currentEmail && currentEmail.isNotEmpty) {
        await CompanyServerService.updateProfile(email: email);
        await AppSession.setEmail(email);
      }
      if (currentPassword.isNotEmpty || newPassword.isNotEmpty) {
        if (currentPassword.isEmpty || newPassword.isEmpty) {
          throw StateError('passwords_required'.tr());
        }
        await CompanyServerService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('account_settings_updated'.tr())),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('account_settings'.tr()),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email_address'.tr()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'current_password'.tr()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'new_password'.tr()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('save'.tr()),
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
  final String currentRole;

  const AppDrawer({super.key, this.onSelectHomeTab, this.currentRole = 'customer'});

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

  bool get _isCustomer => currentRole == 'customer';

  void _pushScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _roleHomeScreen() {
    switch (currentRole) {
      case 'merchant':
        return const MerchantDashboardScreen();
      case 'brand':
        return const BrandDashboardScreen();
      case 'cashier':
        return const CashierDashboardScreen();
      case 'admin':
        return const AdminDashboardScreen();
      default:
        return const OffersListScreen();
    }
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
                  child: const Icon(Icons.person, size: 44, color: kInk),
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
              if (!_isCustomer) {
                _pushScreen(context, _roleHomeScreen());
                return;
              }
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 0,
                fallback: () => Navigator.of(context).popUntil((route) => route.isFirst),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: Text('home_bottom_wallet'.tr()),
            onTap: () {
              if (!_isCustomer) {
                _pushScreen(context, const WalletEngineScreen());
                return;
              }
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 1,
                fallback: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletEngineScreen()),
                ),
              );
            },
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
              if (!_isCustomer) {
                _pushScreen(context, const ReportIssueScreen());
                return;
              }
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 3,
                fallback: () {},
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text('home_bottom_account'.tr()),
            onTap: () {
              if (!_isCustomer) {
                _pushScreen(context, const SettingsScreen.embedded());
                return;
              }
              _selectHomeTabOrNavigate(
                context,
                tabIndex: 4,
                fallback: () {},
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('settings_title'.tr()),
            onTap: () {
              _pushScreen(context, const SettingsScreen.embedded());
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
