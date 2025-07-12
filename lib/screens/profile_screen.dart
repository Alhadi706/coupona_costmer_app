import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    _user = _auth.currentUser;
    if (_user != null) {
      try {
        final doc = await _firestore.collection('users').doc(_user!.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _userData = doc.data();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ في جلب البيانات: $e')),
          );
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('لا توجد بيانات للملف الشخصي'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('البريد الإلكتروني: ${_userData!['email'] ?? ''}', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text('الاسم: ${_userData!['fullName'] ?? ''}'),
                      Text('الجنس: ${_userData!['gender'] ?? ''}'),
                      Text('المدينة: ${_userData!['city'] ?? ''}'),
                      Text('الدولة: ${_userData!['country'] ?? ''}'),
                    ],
                  ),
                ),
    );
  }
}

