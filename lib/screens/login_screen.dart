import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
        // جلب بيانات المستخدم من Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        final userData = userDoc.data();
        final age = userData?['age']?.toString();
        final gender = userData?['gender'] as String?;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              phone: phoneOrEmail,
              age: age,
              gender: gender,
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