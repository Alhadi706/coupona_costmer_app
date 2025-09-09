import 'package:flutter/material.dart';
import 'package:coupona_app/screens/add_coupon_screen.dart';
import 'package:coupona_app/screens/scan_invoice_screen.dart';
import 'package:coupona_app/screens/report_screen.dart';
import 'package:coupona_app/screens/offers_list_screen.dart';
import 'users_screen.dart';
import 'package:coupona_app/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:coupona_app/services/demo_seed_service.dart';
import 'merchant_map_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _AccountSection(),
          Divider(height: 32),
          _LanguageSection(),
          Divider(height: 32),
          _NotificationsSection(),
          Divider(height: 32),
          _LocationPrivacySection(),
          Divider(height: 32),
          _DownloadDataSection(),
          Divider(height: 32),
          // زر زرع بيانات تجريبية للتاجر
          ListTile(
            leading: Icon(Icons.science, color: Colors.orange),
            title: Text('زرع بيانات تجريبية (تاجر/عروض/فواتير/مجتمع)'),
            subtitle: Text('للاختبار السريع عبر رمز التاجر: يربط الشاشات المختلفة'),
            onTap: () async {
              final code = await _askMerchantCode(context, defaultCode: 'TRPCF2');
              if (code == null || code.trim().isEmpty) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ زرع البيانات ...')),
              );
              try {
                await DemoSeedService.seedMerchantDemo(code.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم زرع البيانات لرمز: ${code.trim()}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل الزرع: $e')),
                );
              }
            },
          ),
          Divider(height: 16),
          // خريطة المتاجر حسب رمز التاجر
          ListTile(
            leading: Icon(Icons.map, color: Colors.redAccent),
            title: Text('عرض خريطة المتاجر (حسب رمز التاجر)'),
            onTap: () async {
              final code = await _askMerchantCode(context, defaultCode: 'TRPCF2');
              if (code == null || code.trim().isEmpty) return;
              // تجنب circular deps باستيراد متأخر
              // ignore: use_build_context_synchronously
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MerchantMapScreen(initialMerchantCode: code.trim())),
              );
            },
          ),
          Divider(height: 16),
          // زر عرض إحصائيات سريعة للتاجر
          ListTile(
            leading: Icon(Icons.insights, color: Colors.teal),
            title: Text('عرض إحصائيات التاجر (سريعة)'),
            subtitle: Text('Offers/Stores/Groups/Reports + Invoices Total'),
            onTap: () async {
              final code = await _askMerchantCode(context, defaultCode: 'TRPCF2');
              if (code == null || code.trim().isEmpty) return;
              try {
                final stats = await DemoSeedService.getMerchantStats(code.trim());
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('ملخص $code'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('العروض: ${stats['offers']}'),
                        Text('المتاجر: ${stats['stores']}'),
                        Text('المجموعات: ${stats['groups']}'),
                        Text('البلاغات: ${stats['reports']}'),
                        const Divider(),
                        Text('الفواتير: ${stats['invoices']}'),
                        Text('إجمالي الفواتير: ${stats['invoices_total']}'),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('اغلاق')),
                    ],
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل جلب الإحصائيات: $e')),
                );
              }
            },
          ),
          Divider(height: 32),
          // زر لعرض قائمة العروض
          ListTile(
            leading: Icon(Icons.local_offer, color: Colors.deepPurple),
            title: Text('offers_list'.tr()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OffersListScreen()),
              );
            },
          ),
          Divider(height: 32),
          // ...existing code for other sections...
        ],
      ),
    );
  }
}

Future<String?> _askMerchantCode(BuildContext context, {String? defaultCode}) async {
  String code = defaultCode ?? '';
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('أدخل رمز التاجر'),
      content: TextField(
        autofocus: true,
        decoration: const InputDecoration(hintText: 'مثال: TRPCF2'),
        onChanged: (v) => code = v,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => Navigator.pop(context, code), child: const Text('تأكيد')),
      ],
    ),
  );
}

class _AccountSection extends StatelessWidget {
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
          leading: Icon(Icons.person),
          title: Text('profile'.tr()),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => UsersScreen()),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock),
          title: Text('change_password'.tr()),
          onTap: () {
            // Navigate to change password screen
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.logout),
          title: Text('logout'.tr()),
          onTap: () async {
            // تسجيل الخروج من Firebase
            await FirebaseAuth.instance.signOut();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => LoginPage()),
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
          leading: Icon(Icons.notifications),
          title: Text('notification_settings'.tr()),
          onTap: () {
            // Navigate to notification settings screen
          },
        ),
      ],
    );
  }
}

class _LocationPrivacySection extends StatelessWidget {
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
          leading: Icon(Icons.location_on),
          title: Text('location_settings'.tr()),
          onTap: () {
            // Navigate to location settings screen
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.privacy_tip),
          title: Text('privacy_settings'.tr()),
          onTap: () {
            // Navigate to privacy settings screen
          },
        ),
      ],
    );
  }
}

class _DownloadDataSection extends StatelessWidget {
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
          leading: Icon(Icons.download),
          title: Text('download_account_data'.tr()),
          onTap: () {
            // Handle data download
          },
        ),
      ],
    );
  }
}

class AppDrawer extends StatelessWidget {
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
                  backgroundImage: AssetImage('assets/images/profile.jpg'),
                ),
                SizedBox(height: 8),
                Text(
                  'drawer_username'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'drawer_email'.tr(),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('drawer_home'.tr()),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
          ListTile(
            leading: Icon(Icons.category),
            title: Text('drawer_categories'.tr()),
            onTap: () {
              Navigator.of(context).pushNamed('/categories');
            },
          ),
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text('drawer_favorites'.tr()),
            onTap: () {
              Navigator.of(context).pushNamed('/favorites');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('drawer_settings'.tr()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('drawer_about'.tr()),
            onTap: () {
              // Navigate to about screen
            },
          ),
          ListTile(
            leading: Icon(Icons.contact_mail),
            title: Text('drawer_contact'.tr()),
            onTap: () {
              // Navigate to contact screen
            },
          ),
        ],
      ),
    );
  }
}
