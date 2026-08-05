import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  Future<Map<String, dynamic>?> fetchProfile() async {
    return CompanyServerService.getUserById(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('profile'.tr())),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('profile_no_data'.tr()));
          }
          final user = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('profile_email_value'.tr(namedArgs: {'email': '${user['email'] ?? ''}'}), style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('profile_name_value'.tr(namedArgs: {'name': '${user['fullName'] ?? ''}'})),
                Text('profile_gender_value'.tr(namedArgs: {'gender': '${user['gender'] ?? ''}'})),
                Text('profile_city_value'.tr(namedArgs: {'city': '${user['city'] ?? ''}'})),
                Text('profile_country_value'.tr(namedArgs: {'country': '${user['country'] ?? ''}'})),
              ],
            ),
          );
        },
      ),
    );
  }
}

