import 'package:flutter/material.dart';

import '../services/firestore/brand_repository.dart';
import '../services/firestore/firebase_auth_service.dart';
import 'brand_dashboard_screen.dart';
import 'brand_signup_screen.dart';

class BrandLoginScreen extends StatefulWidget {
  const BrandLoginScreen({super.key});

  @override
  State<BrandLoginScreen> createState() => _BrandLoginScreenState();
}

class _BrandLoginScreenState extends State<BrandLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late final FirebaseAuthService _authService;
  late final BrandRepository _brandRepository;

  @override
  void initState() {
    super.initState();
    _authService = FirebaseAuthService();
    _brandRepository = BrandRepository();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final brandId = credential.user?.uid;
      if (brandId == null) {
        throw Exception('missing_brand_id');
      }
      final brand = await _brandRepository.fetchBrand(brandId);
      if (brand == null) {
        throw Exception('brand_profile_missing');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BrandDashboardScreen(brandId: brandId)),
      );
    } catch (error) {
      debugPrint('Brand login error: $error');
      if (!mounted) return;
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول، تأكد من البيانات')));
      setState(() => _isLoading = false);
    }
  }

  void _openSignup() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrandSignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول للعلامات'),
        actions: [
          IconButton(onPressed: _openSignup, icon: const Icon(Icons.app_registration_outlined)),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('مرحبا بعودتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('سجل للوصول إلى لوحة تحكم العلامة', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text('تسجيل الدخول'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _openSignup, child: const Text('ليس لديك حساب؟ أنشئ علامة جديدة')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
