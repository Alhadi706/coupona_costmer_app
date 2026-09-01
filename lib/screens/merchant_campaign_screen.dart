import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class MerchantCampaignScreen extends StatefulWidget {
  const MerchantCampaignScreen({super.key});

  @override
  State<MerchantCampaignScreen> createState() => _MerchantCampaignScreenState();
}

class _MerchantCampaignScreenState extends State<MerchantCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _discountController = TextEditingController(text: '50');
  final _giftController = TextEditingController();
  final _minimumInvoiceController = TextEditingController(text: '100');
  final _inactiveDaysController = TextEditingController(text: '60');

  String _campaignType = 'early_access_discount';
  String _segmentFilter = 'top_spenders';
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 3));
  bool _submitting = false;
  bool _loadingCampaigns = true;
  String? _loadError;
  List<Map<String, dynamic>> _campaigns = const [];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _discountController.dispose();
    _giftController.dispose();
    _minimumInvoiceController.dispose();
    _inactiveDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    try {
      final campaigns = await CompanyServerService.getMyCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  Map<String, dynamic> get _segmentParams {
    switch (_segmentFilter) {
      case 'top_spenders':
        return const {'months': 6, 'topPercent': 10};
      case 'frequent_visitors':
        return const {'months': 6, 'minVisits': 3};
      case 'inactive':
        return {'inactiveDays': int.tryParse(_inactiveDaysController.text) ?? 60};
      default:
        return const {};
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startsAt : _endsAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startsAt = DateTime(picked.year, picked.month, picked.day);
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(days: 3));
        }
      } else {
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String get _campaignMessagePreview {
    final custom = _messageController.text.trim();
    if (custom.isNotEmpty) return custom;
    switch (_campaignType) {
      case 'free_gift':
        return 'اشتقنالك! أبرز هذا الكوبون عند الكاشير لتحصل على هديتك الخاصة.';
      case 'raffle':
        return 'السحب مخصص لعملاء مؤهلين بناءً على نشاطهم السابق. لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطهم أو مشترياتهم العادية.';
      default:
        return 'بصفتك عميلاً مميزاً، حصلت على أولوية التسوق بخصم حصري قبل الجميع.';
    }
  }

  Future<void> _launchCampaign() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_endsAt.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون تاريخ الانتهاء بعد تاريخ البداية.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await CompanyServerService.createCampaign(
        campaignType: _campaignType,
        title: _titleController.text.trim(),
        description: _campaignMessagePreview,
        segmentFilter: _segmentFilter,
        segmentParams: _segmentParams,
        startsAt: _startsAt,
        endsAt: _endsAt,
        discountPercentage: _campaignType == 'early_access_discount'
            ? num.tryParse(_discountController.text)
            : null,
        giftDescription: _campaignType == 'free_gift' ? _giftController.text.trim() : null,
        minInvoiceAmount: _campaignType == 'raffle'
            ? num.tryParse(_minimumInvoiceController.text)
            : null,
      );
      if (!mounted) return;
      final audience = result['segmentSize'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إطلاق الحملة وإرسالها إلى $audience من العملاء.')),
      );
      _titleController.clear();
      _messageController.clear();
      setState(() => _loadingCampaigns = true);
      await _loadCampaigns();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إطلاق الحملة: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        title: const Text('إطلاق حملة مستهدفة'),
        backgroundColor: kIndigo,
        foregroundColor: kWhite,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCampaigns,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildIntro(),
              const SizedBox(height: 16),
              Form(key: _formKey, child: _buildCampaignForm()),
              const SizedBox(height: 24),
              Text('الحملات الأخيرة', style: kDisplayTextStyle(size: 18)),
              const SizedBox(height: 10),
              _buildCampaignHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kIndigo,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
      ),
      child: Row(
        children: [
          const Icon(Icons.ads_click_outlined, color: kGold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كافئ العملاء الذين يستحقون', style: kDisplayTextStyle(size: 18, color: kWhite)),
                const SizedBox(height: 4),
                Text(
                  'اختر جمهوراً مبنياً على السلوك، ثم أرسل لكل عميل كوبون QR خاصاً وآمناً.',
                  style: kBodyTextStyle(size: 13, color: kWhite.withValues(alpha: 0.86)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نوع الحملة', style: kBodyTextStyle(weight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'early_access_discount', icon: Icon(Icons.percent), label: Text('خصم VIP')),
              ButtonSegment(value: 'free_gift', icon: Icon(Icons.card_giftcard_outlined), label: Text('هدية')),
              ButtonSegment(value: 'raffle', icon: Icon(Icons.confirmation_number_outlined), label: Text('سحب')),
            ],
            selected: {_campaignType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() => _campaignType = selection.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'اسم الحملة', border: OutlineInputBorder()),
            validator: (value) => (value ?? '').trim().isEmpty ? 'اسم الحملة مطلوب.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _segmentFilter,
            decoration: const InputDecoration(labelText: 'شريحة العملاء', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'top_spenders', child: Text('أعلى 10% شراءً خلال 6 أشهر')),
              DropdownMenuItem(value: 'frequent_visitors', child: Text('الأكثر زيارة (3 زيارات فأكثر)')),
              DropdownMenuItem(value: 'inactive', child: Text('العملاء المنقطعون')),
              DropdownMenuItem(value: 'coalition_network', child: Text('عملاء شبكة التحالف')),
              DropdownMenuItem(value: 'all', child: Text('جميع عملاء المتجر')),
            ],
            onChanged: (value) => setState(() => _segmentFilter = value ?? 'top_spenders'),
          ),
          if (_segmentFilter == 'inactive') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _inactiveDaysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مدة الانقطاع بالأيام', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          if (_campaignType == 'early_access_discount')
            TextFormField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'نسبة الخصم %', border: OutlineInputBorder()),
              validator: (value) {
                final discount = num.tryParse(value ?? '');
                return discount == null || discount <= 0 || discount > 100 ? 'أدخل نسبة من 1 إلى 100.' : null;
              },
            ),
          if (_campaignType == 'free_gift')
            TextFormField(
              controller: _giftController,
              decoration: const InputDecoration(labelText: 'وصف الهدية', border: OutlineInputBorder()),
              validator: (value) => (value ?? '').trim().isEmpty ? 'وصف الهدية مطلوب.' : null,
            ),
          if (_campaignType == 'raffle')
            TextFormField(
              controller: _minimumInvoiceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'حد إنفاق سابق للشريحة (اختياري)',
                helperText: 'شرط أهلية تاريخي فقط، وليس شرط شراء جديد للمشاركة.',
                border: OutlineInputBorder(),
              ),
              validator: (value) => num.tryParse(value ?? '') == null ? 'أدخل مبلغاً صحيحاً.' : null,
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'نص التهنئة (اختياري)',
              hintText: 'اتركه فارغاً لاستخدام رسالة مناسبة تلقائياً.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateButton(label: 'تبدأ', value: _startsAt, onTap: () => _pickDate(start: true))),
              const SizedBox(width: 8),
              Expanded(child: _dateButton(label: 'تنتهي', value: _endsAt, onTap: () => _pickDate(start: false))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kMint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(kRadiusCardCompact),
              border: Border.all(color: kTeal.withValues(alpha: 0.35)),
            ),
            child: Text(_campaignMessagePreview, style: kBodyTextStyle(size: 13, height: 1.6)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _launchCampaign,
              icon: _submitting
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('إطلاق الحملة والإرسال'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton({required String label, required DateTime value, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_outlined),
      label: Text('$label ${_dateLabel(value)}', overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildCampaignHistory() {
    if (_loadingCampaigns) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('تعذر تحميل الحملات'),
        subtitle: Text(_loadError!),
        trailing: IconButton(onPressed: _loadCampaigns, icon: const Icon(Icons.refresh), tooltip: 'إعادة المحاولة'),
      );
    }
    if (_campaigns.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.campaign_outlined, color: kTeal),
        title: Text('لا توجد حملات بعد'),
        subtitle: Text('ستظهر الحملات التي تطلقها هنا.'),
      );
    }
    return Column(
      children: _campaigns.take(8).map((campaign) {
        final type = (campaign['campaign_type'] ?? '').toString();
        final icon = switch (type) {
          'free_gift' => Icons.card_giftcard_outlined,
          'raffle' => Icons.confirmation_number_outlined,
          _ => Icons.percent,
        };
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(icon, color: kTeal),
            title: Text((campaign['title'] ?? 'حملة').toString()),
            subtitle: Text('${_dateLabel(DateTime.parse(campaign['starts_at'].toString()))} - ${_dateLabel(DateTime.parse(campaign['ends_at'].toString()))}'),
            trailing: Text((campaign['status'] ?? 'active').toString()),
          ),
        );
      }).toList(),
    );
  }
}