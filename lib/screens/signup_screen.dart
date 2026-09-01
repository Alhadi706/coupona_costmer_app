import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../services/company_server_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  String? _selectedGender;
  Position? _userPosition;
  String? _locationError;
  DateTime? _selectedBirthDate;
  int? _calculatedAge;

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _showLocationRationaleAndRequest() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('location_rationale_title', 'Location access rationale')),
        content: Text(
          _tx(
            'location_rationale_body',
            'We use your location to show nearby offers and merchants, improve offer relevance, verify role requests, and personalize promotional offers.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('cancel', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('continue', 'Continue')),
          ),
        ],
      ),
    );
    if (approved == true) {
      await _getLocation();
    }
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('passwords_do_not_match'.tr())),
      );
      return;
    }
    if (_selectedBirthDate == null || _calculatedAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tx('select_birth_date_required', 'Please select birth date.'))),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tx('select_gender_required', 'Please select gender.'))),
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
      await CompanyServerService.signUp(
        email: email,
        password: password,
        role: 'customer',
        fullName: _fullNameController.text.trim(),
        gender: _selectedGender,
        birthDate: _selectedBirthDate?.toIso8601String(),
        locationLat: _userPosition?.latitude,
        locationLng: _userPosition?.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('account_created_success'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('generic_error_with_message'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('signup_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: _tx('full_name', 'Full name'),
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return _tx('enter_full_name', 'Please enter full name');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedBirthDate == null
                      ? _tx('birth_date', 'Birth date')
                      : '${_tx('birth_date', 'Birth date')}: ${_selectedBirthDate!.toIso8601String().split('T').first}',
                ),
                subtitle: _calculatedAge == null
                    ? null
                    : Text(_tx('calculated_age', 'Age: {age}').replaceAll('{age}', '$_calculatedAge')),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(now.year - 20, now.month, now.day),
                    firstDate: DateTime(1940),
                    lastDate: now,
                  );
                  if (picked == null) return;
                  setState(() {
                    _selectedBirthDate = picked;
                    _calculatedAge = now.year - picked.year -
                        ((now.month < picked.month ||
                                (now.month == picked.month && now.day < picked.day))
                            ? 1
                            : 0);
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: _tx('gender', 'Gender'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'male',
                    child: Text(_tx('gender_male', 'Male')),
                  ),
                  DropdownMenuItem(
                    value: 'female',
                    child: Text(_tx('gender_female', 'Female')),
                  ),
                  DropdownMenuItem(
                    value: 'prefer_not_to_say',
                    child: Text(_tx('gender_prefer_not_to_say', 'Prefer not to disclose')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return _tx('select_gender_required', 'Please select gender');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showLocationRationaleAndRequest,
                icon: const Icon(Icons.my_location_outlined),
                label: Text(
                  _userPosition == null
                      ? _tx('request_location_access', 'Request location access')
                      : _tx('location_captured', 'Location captured'),
                ),
              ),
              if (_userPosition != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _tx('location_coordinates', 'Lat: {lat}, Lng: {lng}')
                        .replaceAll('{lat}', _userPosition!.latitude.toStringAsFixed(6))
                        .replaceAll('{lng}', _userPosition!.longitude.toStringAsFixed(6)),
                  ),
                ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_locationError!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'confirm_password'.tr(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'confirm_password_prompt'.tr();
                  if (text != _passwordController.text.trim()) {
                    return 'passwords_do_not_match'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('signup_button'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
