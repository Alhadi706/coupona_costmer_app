import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  Future<Map<String, dynamic>?> fetchProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('لا توجد بيانات للملف الشخصي'));
          }
          final user = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('البريد الإلكتروني: ${user['email'] ?? ''}', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('الاسم: ${user['fullName'] ?? ''}'),
                Text('الجنس: ${user['gender'] ?? ''}'),
                Text('المدينة: ${user['city'] ?? ''}'),
                Text('الدولة: ${user['country'] ?? ''}'),
              ],
            ),
          );
        },
      ),
    );
  }
}

