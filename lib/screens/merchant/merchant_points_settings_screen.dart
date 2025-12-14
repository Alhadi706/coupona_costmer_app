import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/merchant_point_rules.dart';
import '../../services/firestore/merchant_point_rules_repository.dart';

class MerchantPointsSettingsScreen extends StatefulWidget {
  const MerchantPointsSettingsScreen({super.key, required this.merchantId});

  final String merchantId;

  @override
  State<MerchantPointsSettingsScreen> createState() => _MerchantPointsSettingsScreenState();
}

class _MerchantPointsSettingsScreenState extends State<MerchantPointsSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MerchantPointRulesRepository();

  MerchantPointRules _rules = defaultMerchantPointRules();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final fetched = await _repository.fetchRules(widget.merchantId);
      if (!mounted) return;
      setState(() {
        _rules = fetched ?? defaultMerchantPointRules();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _repository.saveRules(widget.merchantId, _rules);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('merchant_points_settings_saved'.tr())));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('merchant_points_settings_error'.tr(namedArgs: {'error': error.toString()}))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateEnablePerItem(bool value) {
    setState(() {
      _rules = _rules.copyWith(enablePerItem: value);
    });
  }
  void _updateEnablePerAmount(bool value) {
    setState(() {
      _rules = _rules.copyWith(enablePerAmount: value);
    });
  }
  void _updateEnableBoosts(bool value) {
    setState(() {
      _rules = _rules.copyWith(enableBoosts: value);
    });
  }

  void _updatePointsPerItem(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return;
    setState(() => _rules = _rules.copyWith(pointsPerItem: parsed));
  }

  void _updateAmountStep(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return;
    setState(() => _rules = _rules.copyWith(amountStep: parsed));
  }

  void _updatePointsPerAmountStep(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return;
    setState(() => _rules = _rules.copyWith(pointsPerAmountStep: parsed));
  }

  Future<void> _addBoost() async {
    final productController = TextEditingController();
    final pointsController = TextEditingController(text: '1');
    final result = await showDialog<MerchantPointBoost>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('merchant_points_settings_add_boost'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productController,
                decoration: InputDecoration(labelText: 'merchant_points_settings_product_hint'.tr()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pointsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'merchant_points_settings_extra_points'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
            FilledButton(
              onPressed: () {
                final productId = productController.text.trim();
                final extraPoints = double.tryParse(pointsController.text.trim()) ?? 0;
                if (productId.isEmpty || extraPoints <= 0) {
                  return;
                }
                Navigator.of(context).pop(MerchantPointBoost(productId: productId, extraPoints: extraPoints));
              },
              child: Text('save'.tr()),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    setState(() {
      _rules = _rules.copyWith(boosts: [..._rules.boosts, result]);
    });
  }

  void _removeBoost(int index) {
    setState(() {
      final updated = [..._rules.boosts]..removeAt(index);
      _rules = _rules.copyWith(boosts: updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('merchant_points_settings_title'.tr()),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('save'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
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
                        Text('merchant_points_settings_load_error'.tr(), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text('merchant_points_settings_retry'.tr()),
                        ),
                      ],
                    ),
                  ),
                )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'يمكنك تفعيل أكثر من طريقة لاحتساب النقاط. سيتم جمع النقاط من كل قاعدة مفعلة تلقائياً.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مثال: إذا فعّلت قاعدة القيمة وقاعدة الأصناف، سيحصل الزبون على نقاط من كلتيهما عند رفع الفاتورة.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text('merchant_points_settings_description'.tr()),
                    const SizedBox(height: 16),
                    Text('merchant_points_settings_mode_label'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _rules.enablePerItem,
                      onChanged: _updateEnablePerItem,
                      title: Text('merchant_points_settings_mode_per_item'.tr()),
                      subtitle: Text('مثال: كل 5 منتجات = 1 نقطة. يمكنك تحديد العدد بالأسفل.'),
                    ),
                    if (_rules.enablePerItem)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          key: const ValueKey('pointsPerItem'),
                          initialValue: _rules.pointsPerItem.toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'عدد المنتجات لكل نقطة',
                            helperText: 'مثال: إذا وضعت 5، كل 5 منتجات تمنح الزبون نقطة واحدة.',
                          ),
                          onChanged: _updatePointsPerItem,
                          validator: (value) {
                            if (!_rules.enablePerItem) return null;
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'يرجى إدخال عدد صحيح أكبر من صفر';
                            }
                            return null;
                          },
                        ),
                      ),
                    SwitchListTile(
                      value: _rules.enablePerAmount,
                      onChanged: _updateEnablePerAmount,
                      title: Text('merchant_points_settings_mode_per_amount'.tr()),
                      subtitle: Text('مثال: كل 10 دينار = 1 نقطة. يمكنك تحديد القيمة بالأسفل.'),
                    ),
                    if (_rules.enablePerAmount)
                      Column(
                        children: [
                          TextFormField(
                            key: const ValueKey('amountStep'),
                            initialValue: _rules.amountStep.toString(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'قيمة الفاتورة لكل نقطة',
                              helperText: 'مثال: إذا وضعت 10، كل 10 دينار تمنح الزبون نقطة واحدة.',
                            ),
                            onChanged: _updateAmountStep,
                            validator: (value) {
                              if (!_rules.enablePerAmount) return null;
                              final parsed = double.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'يرجى إدخال قيمة أكبر من صفر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('pointsPerAmountStep'),
                            initialValue: _rules.pointsPerAmountStep.toString(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'عدد النقاط لكل قيمة',
                              helperText: 'مثال: إذا وضعت 2، كل 10 دينار تمنح الزبون نقطتين.',
                            ),
                            onChanged: _updatePointsPerAmountStep,
                            validator: (value) {
                              if (!_rules.enablePerAmount) return null;
                              final parsed = double.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'يرجى إدخال عدد نقاط أكبر من صفر';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    SwitchListTile(
                      value: _rules.enableBoosts,
                      onChanged: _updateEnableBoosts,
                      title: Text('نقاط إضافية حسب الصنف'),
                      subtitle: Text('مثال: الصابون = 3 نقاط، الخبز = 1 نقطة، العصير = 4 نقاط...'),
                    ),
                    if (_rules.enableBoosts)
                      Column(
                        children: [
                          Row(
                            children: [
                              Text('الأصناف المميزة', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton.icon(onPressed: _addBoost, icon: const Icon(Icons.add), label: Text('إضافة صنف')), 
                            ],
                          ),
                          if (_rules.boosts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('لم تقم بإضافة أي صنف بعد.'),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(_rules.boosts.length, (index) {
                                final boost = _rules.boosts[index];
                                return Chip(
                                  label: Text('${boost.productId} · +${boost.extraPoints}'),
                                  onDeleted: () => _removeBoost(index),
                                );
                              }),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'سيتم جمع النقاط من جميع القواعد المفعلة تلقائياً عند رفع الفاتورة من قبل الزبون. تأكد من ضبط القيم بدقة لضمان عدالة النظام.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
