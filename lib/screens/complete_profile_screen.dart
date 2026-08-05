import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String userId;
  const CompleteProfileScreen({super.key, required this.userId});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _gender;
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  bool _loading = false;

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await CompanyServerService.updateUserProfile(userId: widget.userId, payload: {
        'fullName': _nameController.text.trim(),
        'gender': _gender,
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'profileCompleted': true,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_saved_success'.tr())),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_save_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('complete_profile_title'.tr())), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'full_name'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              items: [
                DropdownMenuItem(value: 'male', child: Text('male'.tr())),
                DropdownMenuItem(value: 'female', child: Text('female'.tr())),
              ],
              onChanged: (val) => setState(() => _gender = val),
              decoration: InputDecoration(
                labelText: 'gender'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'city'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryController,
              decoration: InputDecoration(
                labelText: 'country'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('save_data'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
