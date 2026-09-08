import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class GiftManagementScreen extends StatefulWidget {
  final String ownerLabel;

  const GiftManagementScreen({super.key, required this.ownerLabel});

  @override
  State<GiftManagementScreen> createState() => _GiftManagementScreenState();
}

class _GiftManagementScreenState extends State<GiftManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _gifts = const [];
  Map<String, dynamic> _analytics = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        CompanyServerService.getMyGiftDefinitions(),
        CompanyServerService.getMyGiftAnalytics().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _gifts = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _analytics = (results[1] as Map<String, dynamic>);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGift() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _GiftDefinitionDialog(),
    );
    if (created == true) await _load();
  }

  Future<void> _launchCampaign(Map<String, dynamic> gift) async {
    final launched = await showDialog<bool>(
      context: context,
      builder: (_) => _GiftCampaignDialog(gift: gift),
    );
    if (launched == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('gift_management_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGift,
        icon: const Icon(Icons.add),
        label: Text('new_gift'.tr()),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'owner_gifts'.tr(namedArgs: {'owner': widget.ownerLabel}),
              style: kDisplayTextStyle(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'gift_management_description'.tr(),
              style: kBodyTextStyle(size: 13, color: kInk.withValues(alpha: 0.68)),
            ),
            const SizedBox(height: 16),
            _GiftAnalyticsStrip(analytics: _analytics),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                  title: Text('gift_load_error'.tr()),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    tooltip: 'retry'.tr(),
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (_gifts.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard_outlined, color: kTeal),
                  title: Text('no_gifts_yet'.tr()),
                  subtitle: Text('no_gifts_yet_hint'.tr()),
                ),
              )
            else
              ..._gifts.map((gift) => _GiftDefinitionCard(
                    gift: gift,
                    onLaunchCampaign: () => _launchCampaign(gift),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _GiftAnalyticsStrip extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const _GiftAnalyticsStrip({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('gifts_title'.tr(), analytics['giftCount'] ?? 0, Icons.card_giftcard_outlined, kTeal),
      ('campaigns_title'.tr(), analytics['campaignCount'] ?? 0, Icons.campaign_outlined, kGold),
      ('recipients_title'.tr(), analytics['assignmentCount'] ?? 0, Icons.people_outline, kIndigo),
      ('redemption_rate_title'.tr(), '${analytics['redemptionRate'] ?? 0}%', Icons.trending_up_outlined, kTealDark),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return SizedBox(
          width: 158,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$3, color: item.$4),
                  const SizedBox(height: 8),
                  Text('${item.$2}', style: kDisplayTextStyle(size: 20, weight: FontWeight.w800, color: item.$4)),
                  Text(item.$1, style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.68))),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _GiftDefinitionCard extends StatelessWidget {
  final Map<String, dynamic> gift;
  final VoidCallback onLaunchCampaign;

  const _GiftDefinitionCard({required this.gift, required this.onLaunchCampaign});

  @override
  Widget build(BuildContext context) {
    final title = (gift['title'] ?? 'هدية').toString();
    final type = (gift['giftType'] ?? '').toString();
    final status = (gift['status'] ?? '').toString();
    final description = (gift['description'] ?? '').toString();
    final expiresAt = (gift['expiresAt'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_giftcard_outlined, color: kTeal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: kBodyTextStyle(size: 16, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(label: Text(_typeLabel(type)), visualDensity: VisualDensity.compact),
                          Chip(label: Text(status.isEmpty ? 'no_status'.tr() : status), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(description, style: kBodyTextStyle(size: 13, color: kInk.withValues(alpha: 0.76))),
            ],
            if (expiresAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('صالحة حتى: $expiresAt', style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.62))),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLaunchCampaign,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('إطلاق حملة لهذه الهدية'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'PHYSICAL_PRODUCT':
        return 'منتج عيني';
      case 'VOUCHER':
        return 'قسيمة';
      case 'DISCOUNT':
        return 'خصم';
      case 'SERVICE':
        return 'خدمة';
      case 'STORE_CREDIT':
        return 'رصيد شراء';
      default:
        return type.isEmpty ? 'هدية' : type;
    }
  }
}

class _GiftDefinitionDialog extends StatefulWidget {
  const _GiftDefinitionDialog();

  @override
  State<_GiftDefinitionDialog> createState() => _GiftDefinitionDialogState();
}

class _GiftDefinitionDialogState extends State<_GiftDefinitionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  final _discountController = TextEditingController();
  final _termsController = TextEditingController();
  final _pickupController = TextEditingController();
  String _giftType = 'VOUCHER';
  DateTime? _expiresAt;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _discountController.dispose();
    _termsController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await CompanyServerService.createGiftDefinition(
        giftType: _giftType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        valueAmount: num.tryParse(_valueController.text.trim()),
        discountPercentage: int.tryParse(_discountController.text.trim()),
        terms: _termsController.text.trim(),
        pickupInstructions: _pickupController.text.trim(),
        status: 'ACTIVE',
        expiresAt: _expiresAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الهدية.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء الهدية: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('هدية جديدة'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _giftType,
                  decoration: const InputDecoration(labelText: 'نوع الهدية'),
                  items: const [
                    DropdownMenuItem(value: 'PHYSICAL_PRODUCT', child: Text('منتج عيني')),
                    DropdownMenuItem(value: 'VOUCHER', child: Text('قسيمة')),
                    DropdownMenuItem(value: 'DISCOUNT', child: Text('خصم')),
                    DropdownMenuItem(value: 'SERVICE', child: Text('خدمة')),
                    DropdownMenuItem(value: 'STORE_CREDIT', child: Text('رصيد شراء')),
                  ],
                  onChanged: (value) => setState(() => _giftType = value ?? 'VOUCHER'),
                ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'اسم الهدية'),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'اسم الهدية مطلوب' : null,
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                  minLines: 2,
                  maxLines: 4,
                ),
                TextFormField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'القيمة إن وجدت'),
                ),
                if (_giftType == 'DISCOUNT')
                  TextFormField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'نسبة الخصم'),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null || parsed < 0 || parsed > 100) return 'أدخل نسبة بين 0 و100';
                      return null;
                    },
                  ),
                TextFormField(
                  controller: _pickupController,
                  decoration: const InputDecoration(labelText: 'تعليمات الاستلام'),
                ),
                TextFormField(
                  controller: _termsController,
                  decoration: const InputDecoration(labelText: 'الشروط'),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_expiresAt == null ? 'اختيار تاريخ الانتهاء' : 'ينتهي: ${_dateLabel(_expiresAt!)}'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text('cancel'.tr())),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          label: Text('save'.tr()),
        ),
      ],
    );
  }
}

class _GiftCampaignDialog extends StatefulWidget {
  final Map<String, dynamic> gift;

  const _GiftCampaignDialog({required this.gift});

  @override
  State<_GiftCampaignDialog> createState() => _GiftCampaignDialogState();
}

class _GiftCampaignDialogState extends State<_GiftCampaignDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _inactiveDaysController = TextEditingController(text: '60');
  final _maxRecipientsController = TextEditingController(text: '50');
  String _segmentFilter = 'all';
  DateTime _endsAt = DateTime.now().add(const Duration(days: 7));
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'حملة ${widget.gift['title'] ?? 'هدية'}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _inactiveDaysController.dispose();
    _maxRecipientsController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _segmentParams {
    switch (_segmentFilter) {
      case 'top_spenders':
        return const {'months': 6, 'topPercent': 10};
      case 'frequent_visitors':
        return const {'months': 6, 'minVisits': 3};
      case 'inactive':
        return {'inactiveDays': int.tryParse(_inactiveDaysController.text.trim()) ?? 60};
      default:
        return const <String, dynamic>{};
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() => _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  Future<void> _launch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _launching = true);
    try {
      final result = await CompanyServerService.launchGiftCampaign(
        giftDefinitionId: widget.gift['id'].toString(),
        title: _titleController.text.trim(),
        segmentFilter: _segmentFilter,
        segmentParams: _segmentParams,
        maxRecipients: int.tryParse(_maxRecipientsController.text.trim()),
        endsAt: _endsAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال الحملة إلى ${result['assignmentCount'] ?? 0} عميل.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إطلاق الحملة: $error')));
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إطلاق حملة هدية'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'عنوان الحملة'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'عنوان الحملة مطلوب' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _segmentFilter,
                decoration: const InputDecoration(labelText: 'الجمهور'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل العملاء المرتبطين')),
                  DropdownMenuItem(value: 'top_spenders', child: Text('الأعلى إنفاقًا')),
                  DropdownMenuItem(value: 'frequent_visitors', child: Text('الأكثر زيارة')),
                  DropdownMenuItem(value: 'inactive', child: Text('العملاء غير النشطين')),
                ],
                onChanged: (value) => setState(() => _segmentFilter = value ?? 'all'),
              ),
              if (_segmentFilter == 'inactive')
                TextFormField(
                  controller: _inactiveDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد أيام الانقطاع'),
                ),
              TextFormField(
                controller: _maxRecipientsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الحد الأقصى للمستلمين'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickEndDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('تنتهي: ${_dateLabel(_endsAt)}'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _launching ? null : () => Navigator.of(context).pop(false), child: Text('cancel'.tr())),
        FilledButton.icon(
          onPressed: _launching ? null : _launch,
          icon: _launching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
          label: Text('send'.tr()),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';