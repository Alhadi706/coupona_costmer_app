import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import '../services/app_session.dart';
import '../services/company_server_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _requestOwnerCode() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Owner verification'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Email code'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Verify'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<Map<String, dynamic>> _authenticate(String email, String password) async {
    try {
      return await CompanyServerService.signIn(email: email, password: password);
    } catch (error) {
      if (!error.toString().contains('owner_mfa_required')) rethrow;
      final challenge = await CompanyServerService.ownerLogin(email: email, password: password);
      final challengeId = (challenge['challengeId'] ?? '').toString();
      if (challengeId.isEmpty) throw StateError('owner_mfa_challenge_missing');
      if (challenge['devBypass'] == true) {
        return CompanyServerService.ownerVerify(challengeId: challengeId, code: '000000');
      }
      final code = await _requestOwnerCode();
      if (code == null || code.length != 6) throw StateError('owner_verification_required');
      return CompanyServerService.ownerVerify(challengeId: challengeId, code: code);
    }
  }

  Future<void> _signIn() async {
    final phoneOrEmail = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = await _authenticate(phoneOrEmail, password);

      await AppSession.save(
        token: (auth['token'] ?? '').toString(),
        userId: (auth['userId'] ?? '').toString(),
        email: phoneOrEmail,
        role: (auth['role'] ?? 'customer').toString(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            phone: phoneOrEmail,
            age: '',
            gender: '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('login_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'email'.tr(),
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'enter_email'.tr();
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                  if (!ok) return 'invalid_email_format'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'password'.tr(),
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'enter_password'.tr();
                  if (text.length < 8) return 'password_min_length'.tr();
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('login_button'.tr()),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  );
                },
                child: Text('new_user_create_account'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}