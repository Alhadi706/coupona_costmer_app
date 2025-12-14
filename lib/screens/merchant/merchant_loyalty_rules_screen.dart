import 'package:flutter/material.dart';
import '../../models/merchant_point_rules.dart';
import '../../services/firestore/merchant_point_rules_repository.dart';

class MerchantLoyaltyRulesScreen extends StatefulWidget {
  final String merchantId;
  const MerchantLoyaltyRulesScreen({super.key, required this.merchantId});

  @override
  State<MerchantLoyaltyRulesScreen> createState() => _MerchantLoyaltyRulesScreenState();
}

class _MerchantLoyaltyRulesScreenState extends State<MerchantLoyaltyRulesScreen> {
  late final MerchantPointRulesRepository _repository;
  MerchantPointRules? _rules;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _repository = MerchantPointRulesRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final rules = await _repository.fetchRules(widget.merchantId);
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'تعذر تحميل قواعد نقاط الولاء';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قواعد نقاط الولاء'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('أعد المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _rules == null
                  ? const Center(child: Text('لا توجد قواعد نقاط حالياً'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'كيف تحصل على النقاط؟',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'يمكنك جمع النقاط عند رفع فاتورتك من هذا المتجر. القواعد التالية تحدد كيف يتم احتساب النقاط.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (_rules!.enablePerItem)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.shopping_basket),
                                title: const Text('نقاط حسب عدد المنتجات'),
                                subtitle: Text('كل ${_rules!.pointsPerItem} منتج = نقطة واحدة'),
                              ),
                            ),
                          if (_rules!.enablePerAmount)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.attach_money),
                                title: const Text('نقاط حسب قيمة الفاتورة'),
                                subtitle: Text('كل ${_rules!.amountStep} دينار = ${_rules!.pointsPerAmountStep} نقطة'),
                              ),
                            ),
                          if (_rules!.enableBoosts && _rules!.boosts.isNotEmpty)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.star),
                                title: const Text('نقاط إضافية لأصناف مميزة'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _rules!.boosts.map((b) => Text('صنف ${b.productId}: +${b.extraPoints} نقطة')).toList(),
                                ),
                              ),
                            ),
                          if (!_rules!.enablePerItem && !_rules!.enablePerAmount && (!_rules!.enableBoosts || _rules!.boosts.isEmpty))
                            const Text('لا توجد قواعد نقاط مفعلة حالياً.'),
                        ],
                      ),
                    ),
    );
  }
}
