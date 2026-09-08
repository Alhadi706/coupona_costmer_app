import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'users_screen.dart';
import '../services/app_session.dart';
import '../services/company_server_service.dart';

void showPlannedFeatureMessage(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('planned_feature_coming_soon'.tr(namedArgs: {'feature': featureName}))),
  );
}

class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'account_section'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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
              builder: (_) => const SettingsAccountSettingsDialog(),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text('logout'.tr()),
          onTap: () async {
            final currentContext = context;
            await AppSession.clear();
            if (!currentContext.mounted) return;
            Navigator.of(currentContext).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}

class SettingsAccountSettingsDialog extends StatefulWidget {
  const SettingsAccountSettingsDialog({super.key});

  @override
  State<SettingsAccountSettingsDialog> createState() => _SettingsAccountSettingsDialogState();
}

class _SettingsAccountSettingsDialogState extends State<SettingsAccountSettingsDialog> {
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
      if (!context.mounted) return;
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
    if (!context.mounted) return;
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
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('save'.tr()),
        ),
      ],
    );
  }
}

class SettingsLanguageSection extends StatelessWidget {
  const SettingsLanguageSection({super.key});

  static const List<Map<String, String>> languages = [
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language),
          title: Text('change_language'.tr()),
          onTap: () {
            final currentContext = context;
            showDialog<String>(
              context: currentContext,
              builder: (dialogContext) => SimpleDialog(
                title: Text('choose_language'.tr()),
                children: languages
                    .map(
                      (lang) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(dialogContext, lang['code']),
                        child: Text(lang['name']!),
                      ),
                    )
                    .toList(),
              ),
            ).then((selected) {
              if (selected == null) return;
              if (!currentContext.mounted) return;
              currentContext.setLocale(Locale(selected));
            });
          },
        ),
      ],
    );
  }
}

class SettingsNotificationsSection extends StatelessWidget {
  const SettingsNotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'notifications_section'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications),
          title: Text('notification_settings'.tr()),
          onTap: () {
            showPlannedFeatureMessage(context, 'notification_settings'.tr());
          },
        ),
      ],
    );
  }
}

class SettingsLocationPrivacySection extends StatelessWidget {
  const SettingsLocationPrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'location_privacy_section'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on),
          title: Text('location_privacy'.tr()),
          onTap: () {
            showPlannedFeatureMessage(context, 'location_privacy'.tr());
          },
        ),
      ],
    );
  }
}

class SettingsDownloadDataSection extends StatelessWidget {
  const SettingsDownloadDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'download_data_section'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download),
          title: Text('download_account_data'.tr()),
          onTap: () {
            showPlannedFeatureMessage(context, 'download_account_data'.tr());
          },
        ),
      ],
    );
  }
}
