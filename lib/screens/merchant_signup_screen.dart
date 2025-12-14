import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../constants/merchant_categories.dart';
import '../models/merchant.dart';
import '../services/firestore/community_repository.dart';
import '../services/firestore/firebase_auth_service.dart';
import '../services/firestore/merchant_repository.dart';
import '../services/merchant_code_service.dart';
import 'map_picker_screen.dart';
import 'merchant_dashboard_screen.dart';

class MerchantSignupScreen extends StatefulWidget {
  const MerchantSignupScreen({super.key});

  @override
  State<MerchantSignupScreen> createState() => _MerchantSignupScreenState();
}

class _MerchantSignupScreenState extends State<MerchantSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customCategoryController = TextEditingController();
  LatLng? _selectedLocation;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  final List<String> _selectedCategories = <String>[];
  final List<String> _customCategories = <String>[];

  late final MerchantRepository _merchantRepository;
  late final FirebaseAuthService _authService;
  late final MerchantCodeService _merchantCodeService;
  late final CommunityRepository _communityRepository;

  @override
  void initState() {
    super.initState();
    _merchantRepository = MerchantRepository();
    _authService = FirebaseAuthService();
    _merchantCodeService = MerchantCodeService();
    _communityRepository = CommunityRepository();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _passwordController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _selectedLocation),
      ),
    );
    if (picked != null) {
      setState(() => _selectedLocation = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      _showError('merchant_signup_pick_location');
      return;
    }
    if (_selectedCategories.isEmpty && _customCategories.isEmpty) {
      _showError('merchant_signup_category_required');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final credential = await _authService.registerMerchant(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _storeNameController.text.trim(),
      );
      debugPrint('Merchant signup step: auth user created ${credential.user?.uid}');

      final merchantId = credential.user?.uid;
      if (merchantId == null) {
        throw Exception('missing_merchant_id');
      }

      final merchantCode = await _merchantCodeService.ensureCodeForMerchant(merchantId);
      debugPrint('Merchant signup step: code reserved $merchantCode');

      final now = Timestamp.now();
      final merchant = Merchant(
        id: merchantId,
        name: _storeNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        logoUrl: null,
        location: _selectedLocation != null
            ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude)
            : null,
        merchantCode: merchantCode,
        merchantCodeAssignedAt: now,
        categories: _combinedCategories(),
        isActive: true,
        pointsPerCurrency: null,
        createdAt: now,
        updatedAt: now,
      );

      await _merchantRepository.upsertMerchant(merchant);
      debugPrint('Merchant signup step: merchant profile stored');

      await _ensureDefaultCommunityRoom(merchant);
      debugPrint('Merchant signup step: default community ensured');

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantDashboardScreen(
            merchantId: merchantId,
            successMessageKey: 'merchant_signup_success',
          ),
        ),
      );
    } on FirebaseAuthException catch (authError, stack) {
      debugPrint('Merchant signup auth error: ${authError.code}\n$stack');
      _showError(_mapAuthError(authError));
    } on FirebaseException catch (firestoreError, stack) {
      debugPrint('Merchant signup firestore error: ${firestoreError.code}\n$stack');
      final key = firestoreError.code == 'permission-denied'
          ? 'merchant_signup_error_permission'
          : 'merchant_signup_error';
      _showError(key);
    } on Exception catch (error, stack) {
      debugPrint('Merchant signup exception: $error\n$stack');
      final key = error.toString().contains('merchant_code_unavailable')
          ? 'merchant_code_generate_error'
          : 'merchant_signup_error';
      _showError(key);
    } catch (error, stack) {
      debugPrint('Merchant signup unknown error (${error.runtimeType}): $error\n$stack');
      _showError('merchant_signup_error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _ensureDefaultCommunityRoom(Merchant merchant) async {
    try {
      final existing = await FirebaseFirestore.instance
          .collection('communities')
          .where('merchantId', isEqualTo: merchant.id)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return;
      }
      await _communityRepository.createRoom(
        merchantId: merchant.id,
        name: merchant.name,
        initialMembers: [merchant.id],
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Default community creation failed: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('Unexpected default community error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  List<String> _combinedCategories() => <String>{
        ..._selectedCategories,
        ..._customCategories.map((c) => c.trim()),
      }.where((element) => element.isNotEmpty).toList();

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'merchant_signup_error_email_in_use';
      case 'weak-password':
        return 'merchant_signup_error_weak_password';
      case 'network-request-failed':
        return 'merchant_signup_error_network';
      default:
        return 'merchant_signup_error';
    }
  }

  void _showError(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(key.tr())),
    );
  }

  void _addCustomCategory() {
    final value = _customCategoryController.text.trim();
    if (value.isEmpty) return;
    if (_customCategories.contains(value)) {
      _customCategoryController.clear();
      return;
    }
    setState(() {
      _customCategories.add(value);
      _customCategoryController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = _selectedLocation != null
        ? 'merchant_signup_location_selected'.tr(args: [
            '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
          ])
        : 'merchant_signup_location_placeholder'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text('merchant_signup_title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'merchant_signup_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'merchant_signup_email'.tr(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'field_required'.tr();
                  }
                  if (!value.contains('@')) {
                    return 'email_invalid'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'merchant_signup_phone'.tr(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'field_required'.tr();
                  }
                  final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
                  if (digits.length < 6) {
                    return 'merchant_signup_phone_invalid'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: 'merchant_signup_store_name'.tr(),
                  prefixIcon: const Icon(Icons.store_mall_directory_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'field_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'merchant_signup_password'.tr(),
                  hintText: 'merchant_signup_password_hint'.tr(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'field_required'.tr();
                  }
                  if (value.trim().length < 6) {
                    return 'password_min_length'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickLocation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'merchant_signup_pick_location'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locationLabel,
                              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildCategorySelector(context),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text('merchant_signup_submit'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'merchant_signup_category_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'merchant_signup_category_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kMerchantCategories.map((category) {
            final label = category['label'] as String;
            final icon = category['icon'] as IconData;
            final isSelected = _selectedCategories.contains(label);
            return ChoiceChip(
              avatar: Icon(icon, color: isSelected ? Colors.white : Colors.deepPurple),
              label: Text(label.tr()),
              selected: isSelected,
              selectedColor: Colors.deepPurple,
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(label);
                  } else {
                    _selectedCategories.add(label);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('merchant_signup_category_custom_label'.tr(), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customCategoryController,
                decoration: InputDecoration(
                  hintText: 'merchant_signup_category_custom_hint'.tr(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _addCustomCategory,
              icon: const Icon(Icons.add),
              label: Text('merchant_signup_category_add'.tr()),
            ),
          ],
        ),
        if (_customCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _customCategories.map((category) {
              return InputChip(
                label: Text(category),
                onDeleted: () => setState(() => _customCategories.remove(category)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
