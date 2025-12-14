import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _loading = false;

  Future<void> _signIn() async {
    final phoneOrEmail = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    setState(() => _loading = true);
    try {
      UserCredential userCredential;
      if (phoneOrEmail.contains('@')) {
        // تسجيل الدخول بالإيميل
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: phoneOrEmail,
          password: password,
        );
      } else {
        // تسجيل الدخول برقم الهاتف (يجب أن يكون المستخدم فعّل مسبقًا)
        // هنا نستخدم الإيميل كبديل أو نوجه المستخدم للتسجيل برقم الهاتف
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى استخدام البريد الإلكتروني لتسجيل الدخول.')),
        );
        setState(() => _loading = false);
        return;
      }
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final role = userDoc.data()?['role']?.toString();
        if (role != 'customer') {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(code: 'role-mismatch', message: 'not-customer');
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              phone: phoneOrEmail,
              age: _selectedBirthDate?.toIso8601String() ?? '',
              gender: _selectedGender ?? '',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بيانات الدخول غير صحيحة!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'خطأ في تسجيل الدخول';
      if (e.code == 'user-not-found') msg = 'المستخدم غير موجود';
      if (e.code == 'wrong-password') msg = 'كلمة المرور غير صحيحة';
      if (e.code == 'role-mismatch') msg = 'هذا الحساب مخصص للتجار. يرجى استخدام تسجيل الدخول المناسب.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تسجيل الدخول: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _signIn,
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('دخول'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                );
              },
              child: const Text('مستخدم جديد؟ أنشئ حساب'),
            ),
          ],
        ),
      ),
    );
  }
}