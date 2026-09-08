import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class MerchantCampaignScreen extends StatefulWidget {
  final String? partnerMerchantId;
  final String? partnerMerchantName;

  const MerchantCampaignScreen({super.key, this.partnerMerchantId, this.partnerMerchantName});

  @override
  State<MerchantCampaignScreen> createState() => _MerchantCampaignScreenState();
}

class _MerchantCampaignScreenState extends State<MerchantCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _discountController = TextEditingController(text: '20');
  final _minimumInvoiceController = TextEditingController(text: '100');
  final _inactiveDaysController = TextEditingController(text: '30');
  final _maxRecipientsController = TextEditingController();
  final _maxSpendController = TextEditingController();
  final _estimatedCostController = TextEditingController();

  int _currentStep = 0; // 0: Audience, 1: Reward & Budget, 2: Schedule & Preview
  int _mobilePreviewTab = 0; // 0: Notification, 1: In-App Voucher

  String _campaignType = 'early_access_discount';
  String _segmentFilter = 'top_spenders';
  String _launchMode = 'active';
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 3));
  bool _submitting = false;
  bool _previewing = false;
  bool _showAdvancedBudget = false;

  Map<String, dynamic>? _audiencePreview;
  Set<String> _selectedCustomerIds = <String>{};
  bool _loadingCampaigns = true;
  String? _loadError;
  List<Map<String, dynamic>> _campaigns = const [];

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if ((widget.partnerMerchantName ?? '').isNotEmpty) {
      _titleController.text = 'حملة دعم ${widget.partnerMerchantName}';
    } else {
      _titleController.text = 'حملة خصم حصري للعملاء المميزين';
    }
    _loadCampaigns();
    _triggerAudiencePreview();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _messageController.dispose();
    _discountController.dispose();
    _minimumInvoiceController.dispose();
    _inactiveDaysController.dispose();
    _maxRecipientsController.dispose();
    _maxSpendController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    try {
      final campaigns = await CompanyServerService.getMyCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns
            .where((campaign) => (campaign['campaign_type'] ?? '').toString() != 'free_gift')
            .toList(growable: false);
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
        return {'inactiveDays': int.tryParse(_inactiveDaysController.text) ?? 30};
      case 'selected_customers':
        return {'selectedCustomerIds': _selectedCustomerIds.toList()};
      default:
        return const {};
    }
  }

  void _triggerAudiencePreview() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _previewAudience();
      }
    });
  }

  Future<void> _previewAudience() async {
    if (!mounted) return;
    setState(() => _previewing = true);
    try {
      final preview = await CompanyServerService.previewCampaign(
        segmentFilter: _segmentFilter,
        segmentParams: _segmentParams,
        partnerMerchantId: widget.partnerMerchantId,
        maxRecipients: int.tryParse(_maxRecipientsController.text.trim()),
        maxCampaignSpend: num.tryParse(_maxSpendController.text.trim()),
        estimatedCostPerRecipient: num.tryParse(_estimatedCostController.text.trim()),
      );
      if (mounted) setState(() => _audiencePreview = preview);
    } catch (error) {
      // Quiet fail for audience preview to avoid disruptive snackbars on keystroke
    } finally {
      if (mounted) setState(() => _previewing = false);
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
      case 'raffle':
        return 'السحب مخصص لعملاء مؤهلين بناءً على نشاطهم السابق. لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطهم أو مشترياتهم العادية.';
      default:
        final discountStr = _discountController.text.trim().isNotEmpty ? _discountController.text.trim() : '20';
        return 'بصفتك عميلاً مميزاً، حصلت على أولوية التسوق بخصم حصري %$discountStr قبل الجميع!';
    }
  }

  Future<void> _selectDirectCustomers() async {
    try {
      final customers = await CompanyServerService.getCampaignCustomers(
        partnerMerchantId: widget.partnerMerchantId,
      );
      if (!mounted) return;
      final selection = Set<String>.from(_selectedCustomerIds);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('اختيار مستلمين مباشرين'),
            content: SizedBox(
              width: 460,
              child: customers.isEmpty
                  ? const Text('لا يوجد عملاء سابقون يمكن إرسال هدية لهم.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      itemBuilder: (_, index) {
                        final customer = customers[index];
                        final customerId = (customer['id'] ?? '').toString();
                        return CheckboxListTile(
                          value: selection.contains(customerId),
                          onChanged: (checked) => setDialogState(() {
                            if (checked ?? false) {
                              selection.add(customerId);
                            } else {
                              selection.remove(customerId);
                            }
                          }),
                          title: Text((customer['name'] ?? customer['email'] ?? 'عميل').toString()),
                          subtitle: Text((customer['email'] ?? '').toString()),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _selectedCustomerIds = selection;
                  });
                  _triggerAudiencePreview();
                  Navigator.pop(dialogContext);
                },
                child: const Text('تأكيد الاختيار'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل قائمة العملاء: $error')));
    }
  }

  void _confirmAndLaunch() {
    if (!_formKey.currentState!.validate()) return;
    if (_segmentFilter == 'selected_customers' && _selectedCustomerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر عميلاً واحدًا على الأقل لإرسال الحملة المباشرة.')),
      );
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون تاريخ الانتهاء بعد تاريخ البداية.')),
      );
      return;
    }

    final audienceCount = _audiencePreview?['segmentSize'] ??
        (_segmentFilter == 'selected_customers' ? _selectedCustomerIds.length : 0);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusCard)),
        title: Row(
          children: const [
            Icon(Icons.rocket_launch_outlined, color: kTeal),
            SizedBox(width: 8),
            Text('تأكيد إطلاق الحملة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت تأكد من إطلاق هذه الحملة بالإعدادات التالية؟', style: kBodyTextStyle(size: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSand,
                borderRadius: BorderRadius.circular(kRadiusCardCompact),
              ),
              child: Column(
                children: [
                  _summaryRow('عنوان الحملة', _titleController.text.trim()),
                  _summaryRow('الشريحة', _getSegmentName(_segmentFilter)),
                  _summaryRow('الجمهور المتوقع', '🎯 $audienceCount زبوناً'),
                  _summaryRow('نوع المكافأة', _campaignType == 'early_access_discount' ? 'خصم VIP %${_discountController.text}' : 'سحب وتذاكر مؤهلة'),
                  _summaryRow('الفترة', '${_dateLabel(_startsAt)} ➔ ${_dateLabel(_endsAt)}'),
                  _summaryRow('طريقة الإطلاق', _getLaunchModeName(_launchMode)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تعديل الإعدادات'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kTeal),
            onPressed: () {
              Navigator.pop(dialogContext);
              _launchCampaign();
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('تأكيد الإطلاق الآن'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: kBodyTextStyle(size: 13, color: kMerchantMuted)),
          Flexible(
            child: Text(value, style: kBodyTextStyle(size: 13, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _getSegmentName(String code) {
    return switch (code) {
      'top_spenders' => 'الزبائن الأكثر شراءً (أعلى 10%)',
      'inactive' => 'الزبائن الغائبون',
      'frequent_visitors' => 'الزبائن الأكثر زيارة',
      'all' => 'جميع عملاء المتجر',
      'selected_customers' => 'عملاء محددون يدويًا',
      _ => code,
    };
  }

  String _getLaunchModeName(String code) {
    return switch (code) {
      'active' => 'إطلاق فوري',
      'scheduled' => 'مجدولة',
      'draft' => 'مسودة',
      _ => code,
    };
  }

  Future<void> _launchCampaign() async {
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
        minInvoiceAmount: _campaignType == 'raffle'
            ? num.tryParse(_minimumInvoiceController.text)
            : null,
        partnerMerchantId: widget.partnerMerchantId,
        launchMode: _launchMode,
        maxRecipients: int.tryParse(_maxRecipientsController.text.trim()),
        maxCampaignSpend: num.tryParse(_maxSpendController.text.trim()),
        estimatedCostPerRecipient: num.tryParse(_estimatedCostController.text.trim()),
      );
      if (!mounted) return;
      final audience = result['segmentSize'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_launchMode == 'active' ? 'تم إطلاق الحملة وإرسالها إلى $audience من العملاء.' : 'تم حفظ الحملة بنجاح.')),
      );
      setState(() {
        _currentStep = 0;
        _loadingCampaigns = true;
      });
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
      backgroundColor: kMerchantBg,
      appBar: AppBar(
        title: const Text('معالج إطلاق الحملات المستهدفة'),
        backgroundColor: kIndigo,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadCampaigns,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if ((widget.partnerMerchantName ?? '').isNotEmpty) ...[
                        Card(
                          elevation: 0,
                          color: kTeal.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusCardCompact),
                            side: const BorderSide(color: kTeal, width: 0.5),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.handshake_outlined, color: kTeal),
                            title: const Text('حملة دعم مشتركة'),
                            subtitle: Text('الجمهور من مشتري العلامة لدى ${widget.partnerMerchantName}، والاسترداد متاح في هذا المتجر فقط.'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildCurrentStepContent(),
                      const SizedBox(height: 24),
                      const Divider(color: kMerchantBorder),
                      const SizedBox(height: 12),
                      Text('الحملات الأخيرة السابقة', style: kDisplayTextStyle(size: 16)),
                      const SizedBox(height: 8),
                      _buildCampaignHistory(),
                    ],
                  ),
                ),
              ),
              _buildBottomNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: kWhite,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _stepItem(0, 'step_target_audience'.tr(), Icons.group_outlined),
              _stepLine(0),
              _stepItem(1, 'step_gift_discount'.tr(), Icons.card_giftcard),
              _stepLine(1),
              _stepItem(2, 'step_timing_preview'.tr(), Icons.mobile_screen_share),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: kMerchantBorder,
              color: kTeal,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    final color = isCompleted
        ? kTeal
        : (isActive ? kIndigo : kMerchantMuted);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (stepIndex < _currentStep || _validateCurrentStep()) {
            setState(() => _currentStep = stepIndex);
          }
        },
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isCompleted ? kTeal : (isActive ? kIndigo : kMerchantBorder),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: kWhite)
                  : Text('${stepIndex + 1}', style: kBodyTextStyle(size: 12, color: isActive ? kWhite : kMerchantMuted, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kBodyTextStyle(
                size: 11,
                color: color,
                weight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepLine(int afterStep) {
    final isDone = _currentStep > afterStep;
    return Container(
      width: 20,
      height: 2,
      color: isDone ? kTeal : kMerchantBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_segmentFilter == 'selected_customers' && _selectedCustomerIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار عميل واحد على الأقل.')),
        );
        return false;
      }
      return true;
    } else if (_currentStep == 1) {
      return _formKey.currentState?.validate() ?? true;
    }
    return true;
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Audience();
      case 1:
        return _buildStep2RewardBudget();
      case 2:
        return _buildStep3SchedulePreview();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 1: Audience Selection ---
  Widget _buildStep1Audience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: '👥 الخطوة 1: اختر الزبائن المستهدفين',
          subtitle: 'حدد الفئة المستهدفة لتظهر لك أعداد الزبائن الفعليين فوراً.',
        ),
        const SizedBox(height: 12),
        _buildSegmentRadioCard(
          filter: 'top_spenders',
          title: '🏆 الزبائن الأكثر شراءً (أعلى 10%)',
          subtitle: 'العملاء الأكثر إنفاقاً خلال الـ 6 أشهر الماضية لزيادة ولاء كبار العملاء.',
          icon: Icons.workspace_premium_outlined,
        ),
        const SizedBox(height: 10),
        _buildSegmentRadioCard(
          filter: 'inactive',
          title: '😴 الزبائن الغائبون (لم يتسوقوا منذ فترة)',
          subtitle: 'إعادة تفعيل العملاء المنقطعين لزيارات جديدة.',
          icon: Icons.snooze_outlined,
          extraContent: _segmentFilter == 'inactive'
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextFormField(
                    controller: _inactiveDaysController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _triggerAudiencePreview(),
                    decoration: const InputDecoration(
                      labelText: 'مدة الانقطاع بالأيام',
                      hintText: '30',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        _buildSegmentRadioCard(
          filter: 'frequent_visitors',
          title: '⭐ الزبائن الأكثر زيارة (3 زيارات فأكثر)',
          subtitle: 'مكافأة الزوار المنتظمين لتعزيز التكرار.',
          icon: Icons.repeat_outlined,
        ),
        const SizedBox(height: 10),
        _buildSegmentRadioCard(
          filter: 'all',
          title: '👥 جميع عملاء المتجر',
          subtitle: 'إرسال الحملة إلى كامل قاعدة عملائك المسجلين.',
          icon: Icons.groups_outlined,
        ),
        const SizedBox(height: 10),
        _buildSegmentRadioCard(
          filter: 'selected_customers',
          title: '🎯 عملاء محددون يدويًا',
          subtitle: 'تحديد قائمة مخصصة بالاسم من سجلات المتجر المباشرة.',
          icon: Icons.person_add_alt_1_outlined,
          extraContent: _segmentFilter == 'selected_customers'
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: _selectDirectCustomers,
                    icon: const Icon(Icons.contacts_outlined),
                    label: Text(_selectedCustomerIds.isEmpty
                        ? 'انقر لاختيار العملاء من القائمة'
                        : 'تم اختيار ${_selectedCustomerIds.length} عميل'),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildSegmentRadioCard({
    required String filter,
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? extraContent,
  }) {
    final isSelected = _segmentFilter == filter;
    final audienceCount = _audiencePreview != null ? (_audiencePreview!['segmentSize'] ?? 0) : null;

    return InkWell(
      onTap: () {
        setState(() => _segmentFilter = filter);
        _triggerAudiencePreview();
      },
      borderRadius: BorderRadius.circular(kRadiusCardCompact),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kTeal.withValues(alpha: 0.05) : kWhite,
          borderRadius: BorderRadius.circular(kRadiusCardCompact),
          border: Border.all(
            color: isSelected ? kTeal : kMerchantBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<String>(
                  value: filter,
                  // ignore: deprecated_member_use
                  groupValue: _segmentFilter,
                  activeColor: kTeal,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _segmentFilter = val);
                      _triggerAudiencePreview();
                    }
                  },
                ),
                Icon(icon, color: isSelected ? kTeal : kMerchantMuted, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: kBodyTextStyle(
                      weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? kTealDark : kMerchantDarkCharcoal,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  if (_previewing)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal))
                  else if (audienceCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kTeal,
                        borderRadius: BorderRadius.circular(kRadiusPill),
                      ),
                      child: Text(
                        '🎯 يستهدف $audienceCount زبوناً',
                        style: kBodyTextStyle(size: 11, color: kWhite, weight: FontWeight.w700),
                      ),
                    ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 48, left: 16),
              child: Text(subtitle, style: kBodyTextStyle(size: 12, color: kMerchantMuted)),
            ),
            if (extraContent != null)
              Padding(
                padding: const EdgeInsets.only(right: 48, top: 4),
                child: extraContent,
              ),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Reward & Budget ---
  Widget _buildStep2RewardBudget() {
    final discountVal = num.tryParse(_discountController.text) ?? 0;
    final maxRecipients = int.tryParse(_maxRecipientsController.text) ?? (_audiencePreview?['segmentSize'] ?? 0);
    final estCost = num.tryParse(_estimatedCostController.text) ?? 0;
    final totalEstBudget = estCost > 0 ? (maxRecipients * estCost) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: '🎁 الخطوة 2: حدد الخصم أو الهدية',
          subtitle: 'حدد تفاصيل المكافأة وقيمة العرض المقدم للعملاء.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(kRadiusCardCompact),
            border: Border.all(color: kMerchantBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'اسم الحملة',
                  hintText: 'مثال: خصم خاص لعملاء VIP',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val ?? '').trim().isEmpty ? 'اسم الحملة مطلوب.' : null,
              ),
              const SizedBox(height: 16),
              Text('نوع المكافأة', style: kBodyTextStyle(weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _rewardTypeCard(
                      type: 'early_access_discount',
                      title: 'خصم VIP %',
                      icon: Icons.percent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _rewardTypeCard(
                      type: 'raffle',
                      title: 'تذاكر سحب مؤهلة',
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_campaignType == 'early_access_discount') ...[
                TextFormField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'نسبة الخصم %',
                    hintText: '20',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final discount = num.tryParse(value ?? '');
                    return discount == null || discount <= 0 || discount > 100 ? 'أدخل نسبة من 1 إلى 100.' : null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _minimumInvoiceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'حد إنفاق سابق للشريحة (اختياري)',
                    hintText: '100',
                    border: OutlineInputBorder(),
                    helperText: 'شرط أهلية تاريخي للمشاركة في السحب.',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _maxRecipientsController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  _triggerAudiencePreview();
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'سقف المستفيدين (اختياري)',
                  hintText: 'مثال: 50',
                  border: OutlineInputBorder(),
                  helperText: 'يحدد أقصى عدد للكوبونات المرسلة للحملة.',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return null;
                  final count = int.tryParse(value!);
                  return count == null || count <= 0 ? 'أدخل عددًا صحيحًا أكبر من صفر.' : null;
                },
              ),
              const SizedBox(height: 16),
              Text('طريقة الإطلاق', style: kBodyTextStyle(weight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'active', icon: const Icon(Icons.send_outlined), label: Text('launch_immediate'.tr())),
                  ButtonSegment(value: 'scheduled', icon: const Icon(Icons.schedule), label: Text('launch_scheduled'.tr())),
                  ButtonSegment(value: 'draft', icon: const Icon(Icons.edit_note), label: Text('launch_draft'.tr())),
                ],
                selected: {_launchMode},
                onSelectionChanged: (val) => setState(() => _launchMode = val.first),
              ),
              const SizedBox(height: 16),
              // Budget Estimator Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(kRadiusCardCompact),
                  border: Border.all(color: kGold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: kGold, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ميزانية الخصم والتغطية التقديرية', style: kBodyTextStyle(weight: FontWeight.w700, size: 13)),
                          const SizedBox(height: 2),
                          Text(
                            'المستهدفون: $maxRecipients زبوناً '
                            '${_campaignType == 'early_access_discount' ? '• نسبة الخصم: %$discountVal' : ''}'
                            '${totalEstBudget != null ? ' • الميزانية التقديرية: $totalEstBudget د.أ' : ''}',
                            style: kBodyTextStyle(size: 12, color: kMerchantDarkCharcoal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Advanced settings expansion
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('إعدادات ميزانية تقدمية (اختياري)', style: kBodyTextStyle(size: 13, color: kIndigo, weight: FontWeight.w600)),
                    initiallyExpanded: _showAdvancedBudget,
                    onExpansionChanged: (val) => setState(() => _showAdvancedBudget = val),
                    children: [
                      TextFormField(
                        controller: _maxSpendController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للإنفاق التقديري',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          return (num.tryParse(value!) ?? 0) > 0 ? null : 'أدخل مبلغًا أكبر من صفر.';
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _estimatedCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'التكلفة التقديرية لكل مستفيد',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_maxSpendController.text.trim().isEmpty) return null;
                          return (num.tryParse(value ?? '') ?? 0) > 0 ? null : 'أدخل تكلفة تقديرية أكبر من صفر.';
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rewardTypeCard({required String type, required String title, required IconData icon}) {
    final isSelected = _campaignType == type;
    return InkWell(
      onTap: () => setState(() => _campaignType = type),
      borderRadius: BorderRadius.circular(kRadiusCardCompact),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? kTeal.withValues(alpha: 0.1) : kWhite,
          borderRadius: BorderRadius.circular(kRadiusCardCompact),
          border: Border.all(color: isSelected ? kTeal : kMerchantBorder, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? kTeal : kMerchantMuted, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: kBodyTextStyle(
                size: 12,
                weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? kTealDark : kMerchantDarkCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Schedule & Live Mobile Preview ---
  Widget _buildStep3SchedulePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: '📱 الخطوة 3: التوقيت ومعاينة الإشعار',
          subtitle: 'شاهد مباشرة كيف سيبدو العرض والإشعار داخل تطبيق هاتف الزبون.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildScheduleControls()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildMobileLivePreview()),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildScheduleControls(),
                  const SizedBox(height: 16),
                  _buildMobileLivePreview(),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildScheduleControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: kMerchantBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تاريخ صلاحية الحملة', style: kBodyTextStyle(weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateButton(label: 'تبدأ', value: _startsAt, onTap: () => _pickDate(start: true))),
              const SizedBox(width: 8),
              Expanded(child: _dateButton(label: 'تنتهي', value: _endsAt, onTap: () => _pickDate(start: false))),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'نص التهنئة / الرسالة الخاصة (اختياري)',
              hintText: 'اتركه فارغاً لاستخدام نص مميز تلقائي...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(kRadiusCardCompact),
              border: Border.all(color: kTeal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: kTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سيتم إرسال هذا التنبيه آلياً لجميع الزبائن المؤهلين فور الإطلاق.',
                    style: kBodyTextStyle(size: 12, color: kTealDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLivePreview() {
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'حملة خصم حصري';
    final message = _campaignMessagePreview;
    final discount = _discountController.text.trim().isNotEmpty ? _discountController.text.trim() : '20';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: kMerchantBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('📱 معاينة هاتف الزبون', style: kBodyTextStyle(weight: FontWeight.w700)),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('إشعار')),
                  ButtonSegment(value: 1, label: Text('كارت الهدية')),
                ],
                selected: {_mobilePreviewTab},
                onSelectionChanged: (val) => setState(() => _mobilePreviewTab = val.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mock Phone Screen Frame
          Center(
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF33333E), width: 6),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  // Phone Status Bar
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('9:41', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Icon(Icons.wifi, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Icon(Icons.battery_full, color: Colors.white, size: 10),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Screen Body
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: const Color(0xFFF3F4F6),
                    padding: const EdgeInsets.all(12),
                    child: _mobilePreviewTab == 0
                        ? _buildPhoneNotificationMockup(title, discount, message)
                        : _buildPhoneVoucherMockup(title, discount, message),
                  ),
                  const SizedBox(height: 10),
                  // Phone Home Bar
                  Container(
                    width: 90,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNotificationMockup(String title, String discount, String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: kTeal,
                    child: Icon(Icons.card_giftcard, size: 10, color: Colors.white),
                  ),
                  SizedBox(width: 6),
                  Text('كوبونا • الآن', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '🔔 مكافأة خاصة حصرياً لك!',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kIndigo),
              ),
              const SizedBox(height: 2),
              Text(
                _campaignType == 'early_access_discount'
                    ? '🎁 خصم %$discount حصري بصفة VIP! ينتهي خلال 3 أيام.'
                    : '🎟️ تأهلت لدخول السحب المميز حصرياً!',
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneVoucherMockup(String title, String discount, String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(4)),
                child: const Text('VIP EXCLUSIVE', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.qr_code, size: 16, color: kTeal),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kIndigo)),
          const SizedBox(height: 4),
          if (_campaignType == 'early_access_discount')
            Text('خصم %$discount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTeal))
          else
            const Text('تذكرة سحب مؤهلة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTeal)),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ينتهي ${_dateLabel(_endsAt)}',
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(6)),
                child: const Text('استخدام العرض', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Common Helpers ---
  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: kDisplayTextStyle(size: 18, color: kIndigo)),
        const SizedBox(height: 4),
        Text(subtitle, style: kBodyTextStyle(size: 13, color: kMerchantMuted)),
      ],
    );
  }

  Widget _dateButton({required String label, required DateTime value, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_outlined, size: 18),
      label: Text('$label ${_dateLabel(value)}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: kWhite,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _currentStep < 2
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kIndigo),
                    onPressed: () {
                      if (_validateCurrentStep()) {
                        setState(() => _currentStep++);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('التالي'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kTeal),
                    onPressed: _submitting ? null : _confirmAndLaunch,
                    icon: _submitting
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                        : const Icon(Icons.rocket_launch_outlined),
                    label: Text(_launchMode == 'active' ? '🚀 إطلاق الحملة الآن' : '💾 حفظ الحملة'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignHistory() {
    if (_loadingCampaigns) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('تعذر تحميل الحملات السابقة'),
        subtitle: Text(_loadError!),
        trailing: IconButton(onPressed: _loadCampaigns, icon: const Icon(Icons.refresh), tooltip: 'retry'.tr()),
      );
    }
    if (_campaigns.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.campaign_outlined, color: kTeal),
        title: Text('لا توجد حملات مسجلة بعد'),
        subtitle: Text('ستظهر جميع الحملات المطلقة هنا مع تقارير أداء الاسترداد.'),
      );
    }
    return Column(
      children: _campaigns.take(6).map((campaign) {
        final type = (campaign['campaign_type'] ?? '').toString();
        final icon = switch (type) {
          'raffle' => Icons.confirmation_number_outlined,
          _ => Icons.percent,
        };
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusCardCompact),
            side: const BorderSide(color: kMerchantBorder),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: kTeal.withValues(alpha: 0.1),
              child: Icon(icon, color: kTeal, size: 20),
            ),
            title: Text((campaign['title'] ?? 'حملة').toString(), style: kBodyTextStyle(weight: FontWeight.w700)),
            subtitle: Text(
              '${_dateLabel(DateTime.parse(campaign['starts_at'].toString()))} ➔ ${_dateLabel(DateTime.parse(campaign['ends_at'].toString()))}\n'
              'صادر: ${campaign['issued_count'] ?? 0} • مستبدل: ${campaign['redeemed_count'] ?? 0} • التحويل: ${campaign['conversionRate'] ?? 0}%',
              style: kBodyTextStyle(size: 11, color: kMerchantMuted),
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'campaign_actions'.tr(),
              onSelected: (action) async {
                if (action == 'launch') {
                  await CompanyServerService.launchCampaign((campaign['id'] ?? '').toString());
                } else if (action == 'pause') {
                  await CompanyServerService.updateCampaignStatus((campaign['id'] ?? '').toString(), 'paused');
                }
                if (mounted) {
                  setState(() => _loadingCampaigns = true);
                  await _loadCampaigns();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'launch', child: Text('إطلاق')),
                const PopupMenuItem(value: 'pause', child: Text('إيقاف مؤقت')),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
