import 'package:flutter/material.dart';

import '../modules/accounting/models/ledger_entry.dart';
import '../modules/accounting/models/point_account.dart';
import '../modules/accounting/models/wallet_account.dart';
import '../modules/accounting/services/accounting_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_dual_wallet_rings.dart';

class WalletEngineScreen extends StatefulWidget {
  const WalletEngineScreen({super.key});

  @override
  State<WalletEngineScreen> createState() => _WalletEngineScreenState();
}

class _WalletEngineScreenState extends State<WalletEngineScreen> {
  final AccountingService _service = AccountingService();
  final TextEditingController _purchaseAmountController = TextEditingController();
  final TextEditingController _cashbackReferenceController = TextEditingController();
  final TextEditingController _redeemPointsController = TextEditingController();
  final TextEditingController _redeemReferenceController = TextEditingController();

  bool _isSubmittingCashback = false;
  bool _isSubmittingRedeem = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _service.ensureAccountingDocuments();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initError = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _purchaseAmountController.dispose();
    _cashbackReferenceController.dispose();
    _redeemPointsController.dispose();
    _redeemReferenceController.dispose();
    super.dispose();
  }

  Future<void> _submitCashback() async {
    final double? amount = double.tryParse(_purchaseAmountController.text.trim());
    final String reference = _cashbackReferenceController.text.trim();

    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغ شراء صحيح أكبر من صفر.');
      return;
    }
    if (reference.isEmpty) {
      _showError('مرجع العملية مطلوب.');
      return;
    }

    setState(() {
      _isSubmittingCashback = true;
    });

    try {
      await _service.applyCashbackFromPurchase(
        purchaseAmount: amount,
        reference: reference,
      );
      if (!mounted) return;
      _purchaseAmountController.clear();
      _cashbackReferenceController.clear();
      _showSuccess('تم احتساب الكاشباك والنقاط بنجاح.');
    } catch (error) {
      _showError('فشل احتساب الكاشباك: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCashback = false;
        });
      }
    }
  }

  Future<void> _submitRedeem() async {
    final int? points = int.tryParse(_redeemPointsController.text.trim());
    final String reference = _redeemReferenceController.text.trim();

    if (points == null || points <= 0) {
      _showError('أدخل عدد نقاط صحيح أكبر من صفر.');
      return;
    }
    if (reference.isEmpty) {
      _showError('مرجع الاسترداد مطلوب.');
      return;
    }

    setState(() {
      _isSubmittingRedeem = true;
    });

    try {
      await _service.redeemPoints(points: points, reference: reference);
      if (!mounted) return;
      _redeemPointsController.clear();
      _redeemReferenceController.clear();
      _showSuccess('تم استرداد النقاط بنجاح.');
    } catch (error) {
      _showError('فشل استرداد النقاط: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRedeem = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة والدفتر المحاسبي'),
        backgroundColor: kTealDark,
      ),
      body: _initError != null
          ? _ErrorCard(message: _initError!)
          : RefreshIndicator(
              onRefresh: _initialize,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: kWhite,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: StreamBuilder<PointAccount>(
                          stream: _service.watchPointAccount(),
                          builder: (context, snapshot) {
                            final points = snapshot.data;
                            final merchantPoints = (points?.availablePoints ?? 0).toDouble();
                            final brandPoints = (points?.lifetimePoints ?? 0).toDouble();
                            return KupunaDualWalletRings(
                              merchantPoints: merchantPoints,
                              brandPoints: brandPoints,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWalletCard(),
                  const SizedBox(height: 12),
                  _buildPointsCard(),
                  const SizedBox(height: 16),
                  _buildCashbackForm(),
                  const SizedBox(height: 16),
                  _buildRedeemForm(),
                  const SizedBox(height: 16),
                  _buildLedgerSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildWalletCard() {
    return StreamBuilder<WalletAccount>(
      stream: _service.watchWallet(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(title: 'تحميل بيانات المحفظة...');
        }
        if (snapshot.hasError) {
          return _ErrorCard(message: 'خطأ في تحميل المحفظة: ${snapshot.error}');
        }
        final WalletAccount wallet = snapshot.data ??
            WalletAccount(
              ownerId: '',
              balance: 0,
              currency: 'SAR',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            );
        return Card(
          child: ListTile(
            title: const Text('رصيد المحفظة'),
            subtitle: Text('آخر تحديث: ${wallet.updatedAt.toLocal()}'),
            trailing: Text(
              '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointsCard() {
    return StreamBuilder<PointAccount>(
      stream: _service.watchPointAccount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(title: 'تحميل بيانات النقاط...');
        }
        if (snapshot.hasError) {
          return _ErrorCard(message: 'خطأ في تحميل النقاط: ${snapshot.error}');
        }
        final PointAccount points = snapshot.data ??
            PointAccount(
              ownerId: '',
              availablePoints: 0,
              lifetimePoints: 0,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            );

        return Card(
          child: ListTile(
            title: const Text('رصيد النقاط'),
            subtitle: Text('إجمالي نقاط مكتسبة: ${points.lifetimePoints}'),
            trailing: Text(
              '${points.availablePoints} نقطة',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCashbackForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('احتساب كاشباك من عملية شراء',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _purchaseAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'مبلغ الشراء',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cashbackReferenceController,
              decoration: const InputDecoration(
                labelText: 'مرجع العملية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingCashback ? null : _submitCashback,
                child: _isSubmittingCashback
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تنفيذ احتساب الكاشباك'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('استرداد نقاط',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _redeemPointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد النقاط',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _redeemReferenceController,
              decoration: const InputDecoration(
                labelText: 'مرجع الاسترداد',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingRedeem ? null : _submitRedeem,
                child: _isSubmittingRedeem
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تنفيذ الاسترداد'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSection() {
    return StreamBuilder<List<LedgerEntry>>(
      stream: _service.watchLedgerEntries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(title: 'تحميل دفتر الحركات...');
        }
        if (snapshot.hasError) {
          return _ErrorCard(message: 'خطأ في تحميل الحركات: ${snapshot.error}');
        }
        final entries = snapshot.data ?? const <LedgerEntry>[];
        if (entries.isEmpty) {
          return const _EmptyCard(message: 'لا توجد حركات محاسبية بعد.');
        }
        return Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('الدفتر المحاسبي'),
                subtitle: Text('آخر 50 حركة'),
              ),
              const Divider(height: 1),
              ...entries.map((entry) => ListTile(
                    title: Text(_typeLabel(entry.type)),
                    subtitle: Text('${entry.reference} - ${entry.createdAt.toLocal()}'),
                    trailing: Text(
                      entry.type == LedgerEntryType.pointsRedeemed
                          ? '-${entry.points} pts'
                          : entry.points > 0
                              ? '+${entry.points} pts'
                              : '+${entry.amount.toStringAsFixed(2)} SAR',
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  String _typeLabel(LedgerEntryType type) {
    switch (type) {
      case LedgerEntryType.cashbackEarned:
        return 'كاشباك مكتسب';
      case LedgerEntryType.pointsEarned:
        return 'نقاط مكتسبة';
      case LedgerEntryType.pointsRedeemed:
        return 'نقاط مستردة';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}
