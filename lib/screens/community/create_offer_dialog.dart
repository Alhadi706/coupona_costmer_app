import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/marketplace_api_client.dart';
import '../../theme/design_tokens.dart';
import 'community_marketplace_errors.dart';
import 'marketplace_categories.dart';

/// Bottom-sheet form used to publish a customer marketplace offer/request.
class CreateOfferDialog extends StatefulWidget {
  const CreateOfferDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateOfferDialog(),
    );
    return created == true;
  }

  @override
  State<CreateOfferDialog> createState() => _CreateOfferDialogState();
}

class _CreateOfferDialogState extends State<CreateOfferDialog> {
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceApiClient.createOffer(
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
      _showMessage(marketplaceErrorMessage(error, fallbackKey: 'marketplace_publish_failed'));
      if (error is MarketplaceSessionExpiredException && mounted) {
        // Close the sheet; the hosting tab detects the cleared session and
        // routes the user to login.
        Navigator.of(context).pop(false);
      }
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
                Text(
                  'marketplace_create_title'.tr(),
                  style: kDisplayTextStyle(size: 20, weight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'offer_title_label'.tr()),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'offer_description_label'.tr()),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(labelText: 'offer_category_label'.tr()),
                  items: kMarketplaceCategories
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(marketplaceCategoryLabel(value)),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'offer_price_label'.tr()),
                  validator: (value) =>
                      value != null && value.trim().isNotEmpty && double.tryParse(value.trim()) == null
                          ? 'invalid_amount'.tr()
                          : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptsPointsTrade,
                  onChanged: (value) => setState(() => _acceptsPointsTrade = value),
                  title: Text('offer_accepts_points_label'.tr()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _merchantOnly,
                  onChanged: (value) => setState(() => _merchantOnly = value),
                  title: Text('offer_merchants_only_label'.tr()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.publish_outlined),
                    label: Text('publish_offer'.tr()),
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
