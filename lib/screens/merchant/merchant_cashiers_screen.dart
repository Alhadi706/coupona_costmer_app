import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/cashier.dart';
import '../../services/firestore/cashier_repository.dart';

class MerchantCashiersScreen extends StatefulWidget {
  final String merchantId;
  const MerchantCashiersScreen({super.key, required this.merchantId});

  @override
  State<MerchantCashiersScreen> createState() => _MerchantCashiersScreenState();
}

class _MerchantCashiersScreenState extends State<MerchantCashiersScreen> {
  late final CashierRepository _cashierRepository;

  @override
  void initState() {
    super.initState();
    _cashierRepository = CashierRepository();
  }

  void _openCashierForm({Cashier? cashier}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _CashierForm(
            merchantId: widget.merchantId,
            cashierRepository: _cashierRepository,
            cashier: cashier,
          ),
        );
      },
    );
  }

  Future<void> _deactivateCashier(Cashier cashier) async {
    await _cashierRepository.deactivateCashier(cashier.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('merchant_cashiers_deactivated'.tr(args: [cashier.userId]))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_cashiers_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCashierForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text('merchant_cashiers_add'.tr()),
      ),
      body: StreamBuilder<List<Cashier>>(
        stream: _cashierRepository.watchCashiers(widget.merchantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_cashiers_error'.tr()));
          }
          final cashiers = snapshot.data ?? const [];
          if (cashiers.isEmpty) {
            return Center(child: Text('merchant_cashiers_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cashiers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final cashier = cashiers[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cashier.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                    child: Icon(Icons.badge_outlined, color: cashier.isActive ? Colors.green : Colors.grey),
                  ),
                  title: Text(cashier.userId),
                  subtitle: Wrap(
                    spacing: 6,
                    children: cashier.permissions
                        .map((permission) => Chip(label: Text(permission)))
                        .toList(),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openCashierForm(cashier: cashier);
                      } else if (value == 'deactivate') {
                        _deactivateCashier(cashier);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text('edit'.tr())),
                      if (cashier.isActive)
                        PopupMenuItem(value: 'deactivate', child: Text('merchant_cashiers_action_deactivate'.tr())),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CashierForm extends StatefulWidget {
  final String merchantId;
  final CashierRepository cashierRepository;
  final Cashier? cashier;
  const _CashierForm({
    required this.merchantId,
    required this.cashierRepository,
    this.cashier,
  });

  @override
  State<_CashierForm> createState() => _CashierFormState();
}

class _CashierFormState extends State<_CashierForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userIdController;
  final Set<String> _permissions = {};
  bool _submitting = false;
  static const _availablePermissions = [
    'scan_invoices',
    'redeem_rewards',
    'manage_products',
  ];

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController(text: widget.cashier?.userId ?? '');
    _permissions.addAll(widget.cashier?.permissions ?? const []);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final cashier = Cashier(
        id: widget.cashier?.id ?? '',
        merchantId: widget.merchantId,
        userId: _userIdController.text.trim(),
        permissions: _permissions.toList(),
        isActive: widget.cashier?.isActive ?? true,
      );
      if (widget.cashier == null) {
        await widget.cashierRepository.addCashier(cashier);
      } else {
        await widget.cashierRepository.saveCashier(cashier);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_cashiers_save_error'.tr())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.cashier != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'merchant_cashiers_edit_title'.tr() : 'merchant_cashiers_add_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _userIdController,
              decoration: InputDecoration(labelText: 'merchant_cashiers_field_user'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('merchant_cashiers_field_permissions'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            ..._availablePermissions.map(
              (permission) => CheckboxListTile(
                value: _permissions.contains(permission),
                title: Text(permission.tr()),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _permissions.add(permission);
                    } else {
                      _permissions.remove(permission);
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    child: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('save'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
