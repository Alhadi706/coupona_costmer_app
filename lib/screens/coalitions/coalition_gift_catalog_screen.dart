import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/company_server_service.dart';

/// Coalition Shared Gift Catalog Screen (Merchant View)
/// Implements Pro-Rata Multi-Sponsor Coalition Engine v3
class CoalitionGiftCatalogScreen extends StatefulWidget {
  final String coalitionId;
  final String coalitionName;

  const CoalitionGiftCatalogScreen({
    super.key,
    required this.coalitionId,
    required this.coalitionName,
  });

  @override
  State<CoalitionGiftCatalogScreen> createState() => _CoalitionGiftCatalogScreenState();
}

class _CoalitionGiftCatalogScreenState extends State<CoalitionGiftCatalogScreen> {
  List<dynamic> _gifts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    setState(() => _loading = true);
    try {
      final response = await CompanyServerService.getCoalitionGiftCatalog(widget.coalitionId);
      if (response['gifts'] != null) {
        setState(() => _gifts = response['gifts']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('coalition_gift_create_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showCreateGiftDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateGiftDialog(
        coalitionId: widget.coalitionId,
        onCreated: _loadGifts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('coalition_gift_catalog_title'.tr()),
      ),
      body: Column(
        children: [
          // Subtitle & create button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'coalition_gift_catalog_subtitle'.tr(),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showCreateGiftDialog,
                  icon: const Icon(Icons.add),
                  label: Text('coalition_gift_create'.tr()),
                ),
              ],
            ),
          ),

          // Gifts list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _gifts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'coalition_gift_no_gifts'.tr(),
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGifts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _gifts.length,
                          itemBuilder: (ctx, i) => _buildGiftCard(_gifts[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCard(dynamic gift) {
    final title = gift['title'] ?? '';
    final description = gift['description'] ?? '';
    final requiredPoints = gift['required_points'] ?? 0;
    final creator = gift['creator_name'] ?? '';
    final quantityRedeemed = gift['quantity_redeemed'] ?? 0;
    final quantityLimit = gift['quantity_limit'];
    final expiresAt = gift['expires_at'];
    final discountPercentage = gift['discount_percentage'] ?? 0;
    final targetNew = gift['target_new_customers'] == true;
    final targetVip = gift['target_vip_customers'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.black87)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$requiredPoints ${'coalition_gift_points_label'.tr()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'coalition_gift_creator'.tr(namedArgs: {'name': creator}),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (quantityLimit != null) ...[
              const SizedBox(height: 4),
              Text(
                'coalition_gift_redeemed'.tr(namedArgs: {'count': quantityRedeemed.toString(), 'limit': quantityLimit.toString()}),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'coalition_gift_expires_on'.tr(namedArgs: {'date': expiresAt.toString()}),
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
            if (discountPercentage > 0) ...[
              const SizedBox(height: 4),
              Text(
                'coalition_gift_discount_applied'.tr(namedArgs: {'percent': discountPercentage.toString()}),
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
            if (targetNew || targetVip) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (targetNew) Chip(label: Text('coalition_gift_targeting_new'.tr()), padding: EdgeInsets.zero),
                  if (targetVip) Chip(label: Text('coalition_gift_targeting_vip'.tr()), padding: EdgeInsets.zero),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating a new shared coalition gift
class _CreateGiftDialog extends StatefulWidget {
  final String coalitionId;
  final VoidCallback onCreated;

  const _CreateGiftDialog({required this.coalitionId, required this.onCreated});

  @override
  State<_CreateGiftDialog> createState() => _CreateGiftDialogState();
}

class _CreateGiftDialogState extends State<_CreateGiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _monetaryValueCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _minFrequencyCtrl = TextEditingController();
  final _maxDaysCtrl = TextEditingController();

  String _campaignType = 'standard';
  bool _targetNew = false;
  bool _targetVip = false;
  DateTime? _expiresAt;
  bool _creating = false;

  Future<void> _createGift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _creating = true);
    try {
      await CompanyServerService.createCoalitionGift(
        coalitionId: widget.coalitionId,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        requiredPoints: int.parse(_pointsCtrl.text),
        monetaryValue: _monetaryValueCtrl.text.trim().isEmpty ? null : double.parse(_monetaryValueCtrl.text),
        campaignType: _campaignType,
        discountPercentage: _discountCtrl.text.trim().isEmpty ? 0 : int.parse(_discountCtrl.text),
        quantityLimit: _quantityCtrl.text.trim().isEmpty ? null : int.parse(_quantityCtrl.text),
        expiresAt: _expiresAt?.toIso8601String(),
        targetNewCustomers: _targetNew,
        targetVipCustomers: _targetVip,
        minPurchaseFrequency: _minFrequencyCtrl.text.trim().isEmpty ? null : int.parse(_minFrequencyCtrl.text),
        maxDaysSinceLastVisit: _maxDaysCtrl.text.trim().isEmpty ? null : int.parse(_maxDaysCtrl.text),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('coalition_gift_create_success'.tr())),
        );
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('coalition_gift_create_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('coalition_gift_create'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'coalition_gift_title_label'.tr(),
                  hintText: 'coalition_gift_title_hint'.tr(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'coalition_create_name_required'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  labelText: 'coalition_gift_description_label'.tr(),
                  hintText: 'coalition_gift_description_hint'.tr(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pointsCtrl,
                decoration: InputDecoration(
                  labelText: 'coalition_gift_points_label'.tr(),
                  hintText: 'coalition_gift_points_hint'.tr(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v) == null || int.parse(v) <= 0)
                    ? 'merchant_gifting_invalid_threshold'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monetaryValueCtrl,
                decoration: InputDecoration(
                  labelText: 'coalition_gift_monetary_value_label'.tr(),
                  hintText: 'coalition_gift_monetary_value_hint'.tr(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _campaignType,
                decoration: InputDecoration(labelText: 'coalition_gift_campaign_type_label'.tr()),
                items: [
                  DropdownMenuItem(value: 'standard', child: Text('coalition_gift_campaign_standard'.tr())),
                  DropdownMenuItem(value: 'new_acquisition', child: Text('coalition_gift_campaign_new_acquisition'.tr())),
                  DropdownMenuItem(value: 'vip_loyalty', child: Text('coalition_gift_campaign_vip_loyalty'.tr())),
                ],
                onChanged: (v) => setState(() => _campaignType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountCtrl,
                decoration: InputDecoration(
                  labelText: 'coalition_gift_discount_label'.tr(),
                  hintText: 'coalition_gift_discount_hint'.tr(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                decoration: InputDecoration(
                  labelText: 'coalition_gift_quantity_label'.tr(),
                  hintText: 'coalition_gift_quantity_hint'.tr(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('coalition_gift_expires_label'.tr()),
                trailing: _expiresAt == null
                    ? ElevatedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _expiresAt = picked);
                        },
                        child: const Text('Select'),
                      )
                    : TextButton(
                        onPressed: () => setState(() => _expiresAt = null),
                        child: Text(DateFormat('yyyy-MM-dd').format(_expiresAt!)),
                      ),
              ),
              const Divider(),
              Text('coalition_gift_targeting_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              CheckboxListTile(
                value: _targetNew,
                onChanged: (v) => setState(() => _targetNew = v!),
                title: Text('coalition_gift_target_new_customers'.tr()),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _targetVip,
                onChanged: (v) => setState(() => _targetVip = v!),
                title: Text('coalition_gift_target_vip_customers'.tr()),
                contentPadding: EdgeInsets.zero,
              ),
              if (_targetVip) ...[
                TextFormField(
                  controller: _minFrequencyCtrl,
                  decoration: InputDecoration(
                    labelText: 'coalition_gift_min_frequency_label'.tr(),
                    hintText: 'coalition_gift_min_frequency_hint'.tr(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxDaysCtrl,
                  decoration: InputDecoration(labelText: 'coalition_gift_max_days_label'.tr()),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: Text('coalition_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _creating ? null : _createGift,
          child: Text(_creating ? 'coalition_gift_creating'.tr() : 'coalition_gift_create_button'.tr()),
        ),
      ],
    );
  }
}
