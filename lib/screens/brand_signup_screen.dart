import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/brand.dart';
import '../services/firestore/brand_repository.dart';
import '../services/firestore/firebase_auth_service.dart';
import 'brand_dashboard_screen.dart';

class BrandSignupScreen extends StatefulWidget {
  const BrandSignupScreen({super.key});

  @override
  State<BrandSignupScreen> createState() => _BrandSignupScreenState();
}

class _BrandSignupScreenState extends State<BrandSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _logoController = TextEditingController();
  final _websiteController = TextEditingController();
  bool _isSubmitting = false;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _logoController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final credential = await _authService.registerBrand(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
      );
      final brandId = credential.user?.uid;
      if (brandId == null) {
        throw Exception('missing_brand_id');
      }
      final now = Timestamp.now();
      final brand = Brand(
        id: brandId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        contactNumber: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
        logoUrl: _logoController.text.trim().isEmpty ? null : _logoController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        totalProducts: 0,
        activeRewards: 0,
        runningCampaigns: 0,
        communityMembers: 0,
        createdAt: now,
        updatedAt: now,
      );
      await _brandRepository.upsertBrand(brand);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BrandDashboardScreen(brandId: brandId)),
      );
    } catch (error) {
      debugPrint('Brand signup error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تسجيل العلامة')), // simple localized text
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل علامة تجارية')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('أنشئ لوحة علامتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'اسم العلامة', prefixIcon: Icon(Icons.branding_watermark)),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الحقل مطلوب';
                        }
                        if (value.length < 6) {
                          return 'كلمة السر قصيرة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'نبذة عن العلامة', prefixIcon: Icon(Icons.short_text)),
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(labelText: 'رقم التواصل', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _logoController,
                      decoration: const InputDecoration(labelText: 'رابط الشعار (اختياري)', prefixIcon: Icon(Icons.image_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(labelText: 'الموقع أو رابط المتجر', prefixIcon: Icon(Icons.link)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_isSubmitting ? 'جارٍ الحفظ...' : 'إنشاء العلامة الآن'),
                      ),
                    ),
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
