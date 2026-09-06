import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class CustomerOffersScreen extends StatefulWidget {
  const CustomerOffersScreen({super.key});

  @override
  State<CustomerOffersScreen> createState() => _CustomerOffersScreenState();
}

class _CustomerOffersScreenState extends State<CustomerOffersScreen> {
  late Future<List<Map<String, dynamic>>> _offersFuture;
  bool _showMyOffers = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  void _loadOffers() {
    _offersFuture = CompanyServerService.getCustomerCommunityOffers(
      myOnly: _showMyOffers,
    );
  }

  Future<void> _refreshOffers() async {
    setState(_loadOffers);
    await _offersFuture;
  }

  Future<void> _showCreateOfferSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateCustomerOfferSheet(),
    );
    if (created == true && mounted) {
      await _refreshOffers();
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> offer, String status) async {
    final offerId = (offer['id'] ?? '').toString();
    if (offerId.isEmpty) return;
    try {
      await CompanyServerService.updateCommunityOfferStatus(
        offerId: offerId,
        status: status,
      );
      if (!mounted) return;
      await _refreshOffers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة العرض: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض الزبائن'),
        backgroundColor: kTealDark,
        foregroundColor: kWhite,
        actions: [
          IconButton(
            onPressed: _refreshOffers,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOfferSheet,
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عرض'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('كل العروض')),
                ButtonSegment(value: true, label: Text('طلباتي')),
              ],
              selected: {_showMyOffers},
              onSelectionChanged: (selection) {
                setState(() {
                  _showMyOffers = selection.first;
                  _loadOffers();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _offersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: _refreshOffers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تعذر تحميل العروض، أعد المحاولة'),
                    ),
                  );
                }
                final offers = snapshot.data ?? const <Map<String, dynamic>>[];
                if (offers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _showMyOffers
                            ? 'لم تضف أي عروض أو طلبات بعد.'
                            : 'لا توجد عروض زبائن متاحة حالياً.',
                        textAlign: TextAlign.center,
                        style: kBodyTextStyle(size: 15, color: kInk.withValues(alpha: 0.7)),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refreshOffers,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: offers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _OfferCard(
                      offer: offers[index],
                      onStatusChanged: _updateStatus,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Future<void> Function(Map<String, dynamic> offer, String status) onStatusChanged;

  const _OfferCard({required this.offer, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final title = (offer['title'] ?? '').toString();
    final description = (offer['description'] ?? '').toString();
    final category = (offer['category'] ?? '').toString();
    final seller = (offer['seller_name'] ?? 'زبون').toString();
    final price = (offer['price_lyd'] as num?)?.toDouble() ?? 0;
    final points = (offer['points_required'] as num?)?.toInt() ?? 0;
    final status = (offer['status'] ?? 'ACTIVE').toString();
    final isOwner = offer['is_owner'] == true;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: kTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: kBodyTextStyle(size: 16, weight: FontWeight.w800)),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: kBodyTextStyle(size: 14, color: kInk.withValues(alpha: 0.75))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text(category)),
                Chip(label: Text('${price.toStringAsFixed(2)} د.ل')),
                if (offer['accepts_points_trade'] == true)
                  Chip(avatar: const Icon(Icons.stars, size: 16, color: kGold), label: Text('$points نقطة')),
                if (!isOwner) Chip(avatar: const Icon(Icons.person_outline, size: 16), label: Text(seller)),
              ],
            ),
            if (isOwner && status == 'ACTIVE') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onStatusChanged(offer, 'ARCHIVED'),
                    child: const Text('أرشفة'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => onStatusChanged(offer, 'SOLD'),
                    child: const Text('تم التنفيذ'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'SOLD' => ('تم التنفيذ', Colors.green),
      'ARCHIVED' => ('مؤرشف', Colors.grey),
      _ => ('نشط', kTeal),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}

class _CreateCustomerOfferSheet extends StatefulWidget {
  const _CreateCustomerOfferSheet();

  @override
  State<_CreateCustomerOfferSheet> createState() => _CreateCustomerOfferSheetState();
}

class _CreateCustomerOfferSheetState extends State<_CreateCustomerOfferSheet> {
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