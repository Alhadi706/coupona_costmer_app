import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/company_server_service.dart';
import 'map_picker_screen.dart';

typedef RoleRequestSubmitter = Future<Map<String, dynamic>> Function({
  required String businessName,
  required String commercialRegistration,
  required String planType,
  required String phone,
  required double locationLat,
  required double locationLng,
  String? locationAddress,
});

class RoleActivationRequestScreen extends StatefulWidget {
  final String roleType;
  final RoleRequestSubmitter? merchantSubmitter;
  final RoleRequestSubmitter? brandSubmitter;
  final LatLng? initialPickedLocation;

  const RoleActivationRequestScreen({
    super.key,
    required this.roleType,
    this.merchantSubmitter,
    this.brandSubmitter,
    this.initialPickedLocation,
  });

  @override
  State<RoleActivationRequestScreen> createState() => _RoleActivationRequestScreenState();
}

class _RoleActivationRequestScreenState extends State<RoleActivationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _commercialRegistrationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationAddressController = TextEditingController();
  String _planType = 'basic';
  LatLng? _pickedLocation;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialPickedLocation;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _commercialRegistrationController.dispose();
    _phoneController.dispose();
    _locationAddressController.dispose();
    super.dispose();
  }

  String _locationSummary() {
    if (_pickedLocation == null) return '';
    final lat = _pickedLocation!.latitude.toStringAsFixed(6);
    final lng = _pickedLocation!.longitude.toStringAsFixed(6);
    return '$lat, $lng';
  }

  Future<void> _pickLocation() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _pickedLocation),
      ),
    );
    if (selected == null) return;
    setState(() {
      _pickedLocation = selected;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_required_fields'.tr())),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final submitter = widget.roleType == 'merchant'
          ? (widget.merchantSubmitter ?? CompanyServerService.requestMerchantRole)
          : (widget.brandSubmitter ?? CompanyServerService.requestBrandRole);

      await submitter(
        businessName: _businessNameController.text.trim(),
        commercialRegistration: _commercialRegistrationController.text.trim(),
        planType: _planType,
        phone: _phoneController.text.trim(),
        locationLat: _pickedLocation!.latitude,
        locationLng: _pickedLocation!.longitude,
        locationAddress: _locationAddressController.text.trim().isEmpty
            ? null
            : _locationAddressController.text.trim(),
      );

      if (!mounted) return;

      if (widget.roleType == 'merchant') {
        FocusScope.of(context).unfocus();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('role_request_submitted'.tr())),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('generic_error_with_message'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMerchant = widget.roleType == 'merchant';
    return Scaffold(
      appBar: AppBar(
        title: Text((isMerchant ? 'activate_merchant_role' : 'activate_brand_role').tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: 'role_request_business_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'error_required_fields'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commercialRegistrationController,
                decoration: InputDecoration(
                  labelText: 'role_request_commercial_registration'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'error_required_fields'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'phone'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'error_required_fields'.tr() : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickLocation,
                icon: const Icon(Icons.location_on),
                label: Text('pick_location_on_map'.tr()),
              ),
              if (_pickedLocation != null) ...[
                const SizedBox(height: 8),
                Text(_locationSummary()),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationAddressController,
                decoration: InputDecoration(
                  labelText: 'location'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _planType,
                decoration: InputDecoration(
                  labelText: 'role_request_plan_type'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'basic', child: Text('basic')),
                  DropdownMenuItem(value: 'pro', child: Text('pro')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _planType = v);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('role_request_submit'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
