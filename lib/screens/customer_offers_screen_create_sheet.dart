import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class CreateCustomerOfferSheet extends StatefulWidget {
  const CreateCustomerOfferSheet({super.key});

  @override
  State<CreateCustomerOfferSheet> createState() => _CreateCustomerOfferSheetState();
}

class _CreateCustomerOfferSheetState extends State<CreateCustomerOfferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = 'SERVICES';
  bool _acceptsPointsTrade = false;
  bool _merchantOnly = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await CompanyServerService.createCustomerCommunityOffer(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        priceLyd: double.tryParse(_priceController.text.trim()) ?? 0,
        acceptsPointsTrade: _acceptsPointsTrade,
        visibilityScope: _merchantOnly ? 'MY_MERCHANTS_ONLY' : 'PUBLIC_COMMUNITY',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر نشر العرض: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إضافة عرض أو طلب', style: kDisplayTextStyle(size: 20, weight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'العنوان مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'الوصف مطلوب' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'الفئة'),
                  items: const [
                    DropdownMenuItem(value: 'FOOD', child: Text('طعام')),
                    DropdownMenuItem(value: 'REAL_ESTATE', child: Text('عقارات')),
                    DropdownMenuItem(value: 'SERVICES', child: Text('خدمات')),
                    DropdownMenuItem(value: 'RENTALS', child: Text('إيجارات')),
                  ],
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'القيمة بالدينار الليبي (اختياري)'),
                  validator: (value) => value != null && value.trim().isNotEmpty && double.tryParse(value.trim()) == null
                      ? 'أدخل قيمة صحيحة'
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptsPointsTrade,
                  onChanged: (value) => setState(() => _acceptsPointsTrade = value),
                  title: const Text('قبول التبادل بالنقاط'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _merchantOnly,
                  onChanged: (value) => setState(() => _merchantOnly = value),
                  title: const Text('إظهاره للتجار الذين تعاملت معهم فقط'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.publish_outlined),
                    label: const Text('نشر العرض'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
