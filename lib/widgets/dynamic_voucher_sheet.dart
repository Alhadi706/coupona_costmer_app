import 'package:flutter/material.dart';

import '../modules/redemption/redemption_math.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

/// Per-store point balance offered to the customer inside the dynamic
/// voucher calculator. Backed by `GET /api/wallet/points/sources`.
class VoucherStoreBalance {
  final String merchantId;
  final String name;
  final int activePoints;

  const VoucherStoreBalance({
    required this.merchantId,
    required this.name,
    required this.activePoints,
  });
}

/// Bottom-sheet calculator that converts a LYD cash amount into a dynamic
/// redemption voucher bound to a customer-selected merchant.
///
/// Responsibility: store selection + live per-store balance validation +
/// voucher creation. The caller owns presenting the resulting QR code.
/// Pops with the raw `createDynamicVoucher` response map on success.
class DynamicVoucherSheet extends StatefulWidget {
  const DynamicVoucherSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DynamicVoucherSheet(),
    );
  }

  @override
  State<DynamicVoucherSheet> createState() => _DynamicVoucherSheetState();
}

class _DynamicVoucherSheetState extends State<DynamicVoucherSheet> {
  final TextEditingController _amountController = TextEditingController();

  List<VoucherStoreBalance> _stores = const <VoucherStoreBalance>[];
  String? _selectedMerchantId;
  bool _loadingSources = true;
  bool _loadFailed = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _loadStores() async {
    setState(() {
      _loadingSources = true;
      _loadFailed = false;
    });
    try {
      final data = await CompanyServerService.getWalletPointSources();
      final raw = (data['merchantSources'] as List?) ?? const <dynamic>[];
      final stores = raw
          .map((e) {
            final map = (e as Map).cast<String, dynamic>();
            return VoucherStoreBalance(
              merchantId: (map['sourceId'] ?? '').toString(),
              name: (map['sourceName'] ?? 'متجر').toString(),
              activePoints: _toInt(map['activePoints']),
            );
          })
          .where((store) => store.merchantId.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _loadingSources = false;
        _selectedMerchantId = _defaultMerchantSelection(stores);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSources = false;
        _loadFailed = true;
      });
    }
  }

  /// Pre-select the store with the highest active balance.
  String? _defaultMerchantSelection(List<VoucherStoreBalance> stores) {
    if (stores.isEmpty) return null;
    final sorted = List<VoucherStoreBalance>.from(stores)
      ..sort((a, b) => b.activePoints.compareTo(a.activePoints));
    return sorted.first.merchantId;
  }

  VoucherStoreBalance? get _selectedStore {
    for (final store in _stores) {
      if (store.merchantId == _selectedMerchantId) return store;
    }
    return null;
  }

  double get _amount =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  int get _requiredPoints => RedemptionMath.pointsRequiredForCash(_amount);

  /// Store-specific live validation message, or null when the current
  /// input is redeemable at the selected store.
  String? get _validationMessage {
    final store = _selectedStore;
    if (store == null) return null;
    if (store.activePoints <= 0) {
      return 'لا توجد لديك نقاط مسجلة لدى هذا المحل';
    }
    if (_amount > 0 && _requiredPoints > store.activePoints) {
      return 'عفواً، لا تملك نقاطاً كافية لدى هذا المحل لخصم هذا المبلغ '
          '(الرصيد المتاح: ${store.activePoints} نقطة | المطلوب: $_requiredPoints نقطة)';
    }
    return null;
  }

  bool get _canSubmit {
    final store = _selectedStore;
    return !_creating &&
        store != null &&
        store.activePoints > 0 &&
        _amount > 0 &&
        _requiredPoints <= store.activePoints;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _creating = true);
    try {
      final result = await CompanyServerService.createDynamicVoucher(
        cashValueLyD: _amount,
        points: _requiredPoints,
        merchantId: _selectedMerchantId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء القسيمة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingSources) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadFailed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          const Text('تعذر تحميل أرصدة المحلات، حاول مجدداً.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadStores,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
          const SizedBox(height: 24),
        ],
      );
    }
    if (_stores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'لا توجد لديك نقاط مسجلة لدى أي محل بعد.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    return _buildCalculator();
  }

  Widget _buildCalculator() {
    final store = _selectedStore;
    final warning = _validationMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حاسبة الاستبدال المالي',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'اختر المحل ثم أدخل المبلغ (1 د.ل = ${RedemptionMath.pointsPerLyD} نقاط)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _selectedMerchantId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'المحل / المتجر',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
          items: _stores
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s.merchantId,
                  child: Text(
                    '${s.name} (${s.activePoints} نقطة)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedMerchantId = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'مثال: 25',
            labelText: 'المبلغ بالـ LYD',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (warning != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _amount > 0
                  ? 'النقاط المطلوبة: $_requiredPoints نقطة • الرصيد المتاح لدى ${store?.name ?? ''}: ${store?.activePoints ?? 0} نقطة'
                  : 'أدخل المبلغ المطلوب لتحويله إلى نقاط استبدال.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            icon: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2),
            label: Text(_creating ? 'جارٍ الإنشاء...' : 'استبدال'),
          ),
        ),
      ],
    );
  }
}
