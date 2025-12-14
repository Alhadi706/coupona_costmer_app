import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coupona_app/services/supabase_user_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:coupona_app/screens/home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String? _selectedGender;
  Position? _userPosition;
  String? _locationError;
  DateTime? _selectedBirthDate;
  int? _calculatedAge;
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'خدمة الموقع غير مفعلة.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'تم رفض إذن الموقع.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'إذن الموقع مرفوض نهائيًا.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = position;
        _locationError = null;
      });
    } catch (e) {
      setState(() => _locationError = 'تعذر جلب الموقع: $e');
    }
  }

  void _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'اختر تاريخ الميلاد',
      locale: const Locale('ar'),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _calculatedAge = now.year - picked.year - ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);
      });
    }
  }

  Future<void> _signUp() async {
    final displayName = _nameController.text.trim();
    final email = _emailController.text.trim();
        if (displayName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال اسم يظهر في الفواتير.')),
          );
          return;
        }
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final gender = _selectedGender;
    final age = _calculatedAge;
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور غير متطابقتين!')),
      );
      return;
    }
    if (_selectedBirthDate == null || age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تاريخ الميلاد.')),
      );
      return;
    }
    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الجنس.')),
      );
      return;
    }
    if (_userPosition == null) {
      await _getLocation();
      if (_userPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_locationError ?? 'تعذر جلب الموقع.')),
        );
        return;
      }
    }
    setState(() => _loading = true);
    try {
      // إنشاء مستخدم في Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      // حفظ بيانات المستخدم في Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'displayName': displayName,
        'email': email,
        'role': 'customer',
        'createdAt': DateTime.now().toIso8601String(),
        'age': age,
        'gender': gender,
        'latitude': _userPosition!.latitude,
        'longitude': _userPosition!.longitude,
        'birthDate': _selectedBirthDate!.toIso8601String(),
      });
      await FirebaseFirestore.instance.collection('customers').doc(user.uid).set({
        'name': displayName,
        'phone': '',
        'age': age,
        'gender': gender,
        'totalPoints': 0,
        'merchantPoints': <String, num>{},
      });
      // إضافة المستخدم في Supabase (اختياري)
      await SupabaseUserService.addUser(
        email: email,
        role: 'customer',
        age: age,
        gender: gender,
        latitude: _userPosition!.latitude,
        longitude: _userPosition!.longitude,
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              phone: user.email ?? '',
              age: age.toString(),
              gender: gender,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل حساب جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الذي سيظهر للتجار',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickBirthDate,
              child: AbsorbPointer(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'تاريخ الميلاد',
                    prefixIcon: const Icon(Icons.cake),
                    border: const OutlineInputBorder(),
                    hintText: _selectedBirthDate != null
                        ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                        : 'اختر تاريخ الميلاد',
                  ),
                  controller: TextEditingController(
                    text: _selectedBirthDate != null
                        ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                        : '',
                  ),
                  readOnly: true,
                ),
              ),
            ),
            if (_calculatedAge != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('العمر: $_calculatedAge سنة', style: const TextStyle(color: Colors.deepPurple)),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              items: const [
                DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
              ],
              onChanged: (val) => setState(() => _selectedGender = val),
              decoration: const InputDecoration(
                labelText: 'الجنس',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_locationError!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _signUp,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تسجيل حساب جديد'),
            ),
          ],
        ),
      ),
    );
  }
}
