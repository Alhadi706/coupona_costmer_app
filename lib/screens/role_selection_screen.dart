import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'merchant_login_screen.dart';
import 'login_screen.dart';
import 'brand_login_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (role == 'merchant') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MerchantLoginScreen()),
      );
    } else if (role == 'customer') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LoginPage()),
      );
    } else if (role == 'brand') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BrandLoginScreen()),
      );
    } else if (role == 'admin') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      Navigator.of(context).pop(role);
    }
  }

  Widget _buildTile(BuildContext context, IconData icon, String labelKey, String roleKey, {List<Color>? gradientColors, String? subtitleKey}) {
    final label = labelKey.tr();
    final subtitle = subtitleKey?.tr() ?? '';
    final brightness = Theme.of(context).brightness;
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.deepPurple.shade800;
    final cardColor = Theme.of(context).cardColor;

    final gradient = gradientColors ?? [Colors.deepPurple.shade400, Colors.deepPurple.shade700];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: cardColor,
        elevation: 4,
        child: InkWell(
          onTap: () => _selectRole(context, roleKey),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 170),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // circular icon background for modern look
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: 0.18), blurRadius: 8, offset: Offset(0,6))],
                  ),
                  child: Icon(icon, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  label.isEmpty || label == labelKey ? labelKey : label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر نوع المستخدم'),
        backgroundColor: Colors.deepPurple.shade700,
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            tooltip: 'choose_language'.tr(),
            onSelected: (locale) async {
              await context.setLocale(locale);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const Locale('ar'),
                child: Text('language_ar'.tr()),
              ),
              PopupMenuItem(
                value: const Locale('en'),
                child: Text('language_en'.tr()),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text('choose_user_type'.tr(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('choose_account_hint'.tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                    _buildTile(
                      context,
                      Icons.person,
                      'role_customer',
                      'customer',
                      gradientColors: [Colors.teal.shade400, Colors.teal.shade700],
                      subtitleKey: 'role_customer_sub',
                    ),
                    _buildTile(
                      context,
                      Icons.store,
                      'role_merchant',
                      'merchant',
                      gradientColors: [Colors.orange.shade400, Colors.orange.shade700],
                      subtitleKey: 'role_merchant_sub',
                    ),
                    _buildTile(
                      context,
                      Icons.branding_watermark,
                      'role_brand',
                      'brand',
                      gradientColors: [Colors.indigo.shade400, Colors.indigo.shade700],
                      subtitleKey: 'role_brand_sub',
                    ),
                    _buildTile(
                      context,
                      Icons.admin_panel_settings,
                      'role_admin',
                      'admin',
                      gradientColors: [Colors.deepPurple.shade300, Colors.deepPurple.shade700],
                      subtitleKey: 'role_admin_sub',
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: Text('back'.tr()),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
