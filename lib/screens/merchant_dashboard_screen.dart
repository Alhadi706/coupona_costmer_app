import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_loyalty_health_ring.dart';
import '../widgets/design_system/kupuna_offer_card.dart';
import '../widgets/design_system/kupuna_status_pill.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  final bool embedded;

  const MerchantDashboardScreen({super.key, this.embedded = false});

  const MerchantDashboardScreen.embedded({super.key}) : embedded = true;

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final TextEditingController _branchNameController = TextEditingController();
  final TextEditingController _branchAddressController = TextEditingController();
  final TextEditingController _branchLocationController = TextEditingController();
  final TextEditingController _managerBranchIdController = TextEditingController();
  final TextEditingController _managerUserIdController = TextEditingController();
  final TextEditingController _cashierBranchIdController = TextEditingController();
  final TextEditingController _cashierUserIdController = TextEditingController();
  final TextEditingController _pointValueController = TextEditingController();

  bool _canReviewInvoices = false;
  bool _canCreateOffers = false;
  bool _canManageGroup = false;
  bool _canViewReports = false;
  bool _canViewSettlements = false;
  bool _canAddCashiers = false;
  bool _canReplyReports = false;
  bool _canEditPointValue = false;

  bool _loading = true;
  bool _savingPointValue = false;
  String? _error;
  String? _result;
  double? _currentPointValue;
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  Map<String, dynamic> _loyalty = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchLocationController.dispose();
    _managerBranchIdController.dispose();
    _managerUserIdController.dispose();
    _cashierBranchIdController.dispose();
    _cashierUserIdController.dispose();
    _pointValueController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        CompanyServerService.getMerchantBranches(),
        CompanyServerService.getMerchantLoyaltyHealth(),
        CompanyServerService.getMyInvoices(limit: 20),
        CompanyServerService.getMerchantProfile(),
        CompanyServerService.getOffers(),
      ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(results[3] as Map<dynamic, dynamic>);
      final pointValueRaw = profile['pointValue'];
      final pointValue = pointValueRaw == null ? null : double.tryParse(pointValueRaw.toString());
      setState(() {
        _branches = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _loyalty = Map<String, dynamic>.from(results[1] as Map<dynamic, dynamic>);
        _invoices = List<Map<String, dynamic>>.from(results[2] as List<dynamic>);
        _offers = List<Map<String, dynamic>>.from(results[4] as List<dynamic>);
        _currentPointValue = pointValue;
        _pointValueController.text = pointValue == null ? '' : pointValue.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  StatusPillKind _branchStatusToPill(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().toLowerCase();
    if (status == 'active') {
      return StatusPillKind.approvedMint;
    }
    if (status == 'pending' || status == 'under_review') {
      return StatusPillKind.pending;
    }
    return StatusPillKind.rejected;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  StatusPillKind _invoiceStatusToPill(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().toLowerCase();
    if (status == 'approved' || status == 'active') {
      return StatusPillKind.approvedMint;
    }
    if (status == 'processing' || status == 'pending_review' || status == 'under_review') {
      return StatusPillKind.pending;
    }
    return StatusPillKind.rejected;
  }

  Widget _buildIndigoSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kPaddingCardCompact),
      decoration: BoxDecoration(
        color: kIndigoLight,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kLineDark, width: kBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: kDisplayTextStyle(
              size: 15,
              weight: FontWeight.w700,
              color: kWhite,
            ),
          ),
          const SizedBox(height: kGapTight),
          child,
        ],
      ),
    );
  }

  Future<void> _savePointValue() async {
    final pointValue = double.tryParse(_pointValueController.text.trim());
    if (pointValue == null || pointValue <= 0) {
      setState(() {
        _result = 'Please enter a valid point value greater than zero.';
      });
      return;
    }

    setState(() {
      _savingPointValue = true;
      _result = null;
    });

    try {
      final data = await CompanyServerService.setMerchantPointValue(pointValue: pointValue);
      final updated = double.tryParse((data['pointValue'] ?? pointValue).toString()) ?? pointValue;
      if (!mounted) return;
      setState(() {
        _currentPointValue = updated;
        _pointValueController.text = updated.toString();
        _result = 'Point value saved: $updated';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPointValue = false;
        });
      }
    }
  }

  Future<void> _createBranch() async {
    if (_branchNameController.text.trim().isEmpty) return;
    try {
      final created = await CompanyServerService.createMerchantBranch(
        name: _branchNameController.text.trim(),
        address: _branchAddressController.text.trim(),
        location: _branchLocationController.text.trim(),
      );
      setState(() {
        _result = 'Branch created: ${created['id'] ?? ''}';
      });
      _branchNameController.clear();
      _branchAddressController.clear();
      _branchLocationController.clear();
      await _load();
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Future<void> _addManager() async {
    try {
      await CompanyServerService.addMerchantBranchManager(
        branchId: _managerBranchIdController.text.trim(),
        userId: _managerUserIdController.text.trim(),
      );
      await CompanyServerService.updateBranchManagerPermissions(
        branchId: _managerBranchIdController.text.trim(),
        userId: _managerUserIdController.text.trim(),
        canReviewInvoices: _canReviewInvoices,
        canCreateOffers: _canCreateOffers,
        canManageGroup: _canManageGroup,
        canViewReports: _canViewReports,
        canViewSettlements: _canViewSettlements,
        canAddCashiers: _canAddCashiers,
        canReplyReports: _canReplyReports,
        canEditPointValue: _canEditPointValue,
      );
      setState(() {
        _result = 'Manager assigned and permissions updated.';
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Future<void> _bindCashier() async {
    try {
      final data = await CompanyServerService.bindCashierToBranch(
        branchId: _cashierBranchIdController.text.trim(),
        cashierUserId: _cashierUserIdController.text.trim(),
      );
      setState(() {
        _result = 'Cashier bound: ${data['id'] ?? ''}';
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: kIndigo,
              borderRadius: BorderRadius.circular(kRadiusCardLarge),
              border: Border.all(color: kLineDark, width: kBorderWidth),
            ),
            padding: const EdgeInsets.all(kPaddingCard),
            child: Column(
              children: [
                const Center(
                  child: KupunaLoyaltyHealthRing(scorePercent: 78),
                ),
                const SizedBox(height: kGapList),
                Text(
                  'Merchant Loyalty Health',
                  style: kDisplayTextStyle(
                    size: 18,
                    weight: FontWeight.w700,
                    color: kWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score: ${_toDouble(_loyalty['score']).toStringAsFixed(0)} | Trend: ${_loyalty['trend'] ?? '-'}',
                  style: kBodyTextStyle(
                    size: 12,
                    weight: FontWeight.w400,
                    color: kWhite.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: kGapTight),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: kGold),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: kBodyTextStyle(
                  size: 12,
                  weight: FontWeight.w500,
                  color: kGold,
                ),
              ),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _result!,
                style: kBodyTextStyle(
                  size: 12,
                  weight: FontWeight.w500,
                  color: kGold,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Set Point Value'),
            subtitle: Text('Current: ${_currentPointValue?.toString() ?? '-'}'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _pointValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Point Value',
                  helperText: 'Used in grant/cashback calculations (points = purchaseAmount / pointValue).',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _savingPointValue ? null : _savePointValue,
                child: Text(_savingPointValue ? 'Saving...' : 'Save Point Value'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildIndigoSection(
            title: 'Branches',
            child: Column(
              children: _branches
                  .map((branch) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: kIndigo,
                          borderRadius: BorderRadius.circular(kRadiusCardCompact),
                          border: Border.all(color: kLineDark, width: kBorderWidth),
                        ),
                        child: ListTile(
                          title: Text(
                            (branch['name'] ?? 'Unnamed branch').toString(),
                            style: kBodyTextStyle(
                              size: 14,
                              weight: FontWeight.w600,
                              color: kWhite,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ID: ${branch['id'] ?? ''}\n${branch['address'] ?? ''}',
                                style: kBodyTextStyle(
                                  size: 12,
                                  weight: FontWeight.w400,
                                  color: kWhite.withValues(alpha: 0.86),
                                ),
                              ),
                              const SizedBox(height: 6),
                              KupunaStatusPill(
                                kind: _branchStatusToPill(branch['status']),
                                labelOverride: (branch['status'] ?? 'pending').toString(),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Create Branch'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _branchNameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _branchAddressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: _branchLocationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _createBranch, child: const Text('Create')),
            ],
          ),
          ExpansionTile(
            title: const Text('Assign Branch Manager + Permissions'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _managerBranchIdController,
                decoration: const InputDecoration(labelText: 'Branch ID'),
              ),
              TextField(
                controller: _managerUserIdController,
                decoration: const InputDecoration(labelText: 'Manager User ID'),
              ),
              SwitchListTile(
                value: _canReviewInvoices,
                title: const Text('Can review invoices'),
                onChanged: (value) => setState(() => _canReviewInvoices = value),
              ),
              SwitchListTile(
                value: _canCreateOffers,
                title: const Text('Can create offers'),
                onChanged: (value) => setState(() => _canCreateOffers = value),
              ),
              SwitchListTile(
                value: _canManageGroup,
                title: const Text('Can manage group'),
                onChanged: (value) => setState(() => _canManageGroup = value),
              ),
              SwitchListTile(
                value: _canViewReports,
                title: const Text('Can view reports'),
                onChanged: (value) => setState(() => _canViewReports = value),
              ),
              SwitchListTile(
                value: _canViewSettlements,
                title: const Text('Can view settlements'),
                onChanged: (value) => setState(() => _canViewSettlements = value),
              ),
              SwitchListTile(
                value: _canAddCashiers,
                title: const Text('Can add cashiers'),
                onChanged: (value) => setState(() => _canAddCashiers = value),
              ),
              SwitchListTile(
                value: _canReplyReports,
                title: const Text('Can reply reports'),
                onChanged: (value) => setState(() => _canReplyReports = value),
              ),
              SwitchListTile(
                value: _canEditPointValue,
                title: const Text('Can edit point value'),
                onChanged: (value) => setState(() => _canEditPointValue = value),
              ),
              ElevatedButton(onPressed: _addManager, child: const Text('Save manager permissions')),
            ],
          ),
          ExpansionTile(
            title: const Text('Bind Cashier To Branch'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _cashierBranchIdController,
                decoration: const InputDecoration(labelText: 'Branch ID'),
              ),
              TextField(
                controller: _cashierUserIdController,
                decoration: const InputDecoration(labelText: 'Cashier User ID'),
              ),
              ElevatedButton(onPressed: _bindCashier, child: const Text('Bind Cashier')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PointsConversionScreen()),
                  );
                },
                child: const Text('Points Conversion'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RewardQrCodeScreen()),
                  );
                },
                child: const Text('Create Reward QR'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildIndigoSection(
            title: 'Latest Offers',
            child: Column(
              children: _offers.take(6).map((offer) {
                final String title = (offer['description'] ?? offer['title'] ?? 'Offer').toString();
                final String category = (offer['category'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KupunaOfferCard(
                    offer: <String, dynamic>{
                      ...offer,
                      'title': title,
                      'subtitle': category,
                      'sourceType': 'merchant',
                    },
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          _buildIndigoSection(
            title: 'Recent My Invoices',
            child: Column(
              children: _invoices
                  .map((invoice) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: kIndigo,
                          borderRadius: BorderRadius.circular(kRadiusCardCompact),
                          border: Border.all(color: kLineDark, width: kBorderWidth),
                        ),
                        child: ListTile(
                          title: Text(
                            (invoice['merchantName'] ?? 'Unknown merchant').toString(),
                            style: kBodyTextStyle(
                              size: 14,
                              weight: FontWeight.w600,
                              color: kWhite,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Invoice: ${invoice['invoiceNumber'] ?? '-'} | Total: ${invoice['totalAmount'] ?? '-'}',
                                style: kBodyTextStyle(
                                  size: 12,
                                  weight: FontWeight.w400,
                                  color: kWhite.withValues(alpha: 0.86),
                                ),
                              ),
                              const SizedBox(height: 6),
                              KupunaStatusPill(
                                kind: _invoiceStatusToPill(invoice['state'] ?? invoice['lifecycleStatus']),
                                labelOverride: (invoice['state'] ?? invoice['lifecycleStatus'] ?? 'processing').toString(),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          _buildIndigoSection(
            title: 'Reports & Settlements Snapshot',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Invoices: ${_invoices.length}',
                    style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite),
                  ),
                  backgroundColor: kIndigo,
                  side: const BorderSide(color: kLineDark, width: kBorderWidth),
                ),
                Chip(
                  label: Text(
                    'Branches: ${_branches.length}',
                    style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite),
                  ),
                  backgroundColor: kIndigo,
                  side: const BorderSide(color: kLineDark, width: kBorderWidth),
                ),
                Chip(
                  label: Text(
                    'Offers: ${_offers.length}',
                    style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite),
                  ),
                  backgroundColor: kIndigo,
                  side: const BorderSide(color: kLineDark, width: kBorderWidth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: kIndigo,
      appBar: AppBar(title: const Text('Merchant Dashboard')),
      body: _buildBody(),
    );
  }
}
