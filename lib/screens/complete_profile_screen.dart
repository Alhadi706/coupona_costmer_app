import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'fullName': _nameController.text.trim(),
        'gender': _gender,
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'profileCompleted': true,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ البيانات بنجاح!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ البيانات: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استكمال البيانات')), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
              ],
              onChanged: (val) => setState(() => _gender = val),
              decoration: const InputDecoration(
                labelText: 'الجنس',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'المدينة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'الدولة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('حفظ البيانات'),
            ),
          ],
        ),
      ),
    );
  }
}
