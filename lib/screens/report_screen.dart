import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _storeSearchController = TextEditingController();

  bool _loadingStores = true;
  String? _storesError;
  List<Map<String, dynamic>> _eligibleStores = const <Map<String, dynamic>>[];

  String? _selectedType;
  String? _description;
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    _loadEligibleStores();
    _storeSearchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _storeSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadEligibleStores() async {
    setState(() {
      _loadingStores = true;
      _storesError = null;
    });
    try {
      final stores = await CompanyServerService.getEligibleReportStores();
      if (!mounted) return;
      setState(() {
        _eligibleStores = stores;
        _loadingStores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStores = false;
        _storesError = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _filteredStores() {
    final query = _storeSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _eligibleStores;
    return _eligibleStores.where((store) {
      final name = (store['storeName'] ?? '').toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  String _formatLastInteractedAt(dynamic value) {
    final raw = value?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (_selectedStoreId == null || _selectedStoreId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('please_select_eligible_store'.tr())),
        );
        return;
      }
      try {
        await CompanyServerService.createReport(
          reportType: _selectedType ?? 'other',
          targetStoreId: _selectedStoreId!,
          description: _description ?? '',
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('report_send_failed'.tr())),
        );
        return;
      }
      if (!mounted) return;
      final selectedStore = _eligibleStores.where((s) => (s['storeId'] ?? '').toString() == _selectedStoreId).cast<Map<String, dynamic>>().toList();
      final selectedStoreName = selectedStore.isNotEmpty ? (selectedStore.first['storeName'] ?? '').toString() : '';
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('report_sent'.tr()),
          content: Text(
            '${'report_sent_message'.tr()}\n$selectedStoreName${_description == null || _description!.isEmpty ? '' : '\n${_description!}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
      _formKey.currentState!.reset();
      setState(() {
        _selectedType = null;
        _description = null;
        _selectedStoreId = null;
      });
    }
  }

  Widget _buildEligibleStoresSelector() {
    if (_loadingStores) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_storesError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('report_eligible_stores_load_error'.tr()),
              const SizedBox(height: 6),
              Text(
                _storesError!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _loadEligibleStores,
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    if (_eligibleStores.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('report_no_eligible_stores'.tr()),
        ),
      );
    }

    final filtered = _filteredStores();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _storeSearchController,
          decoration: InputDecoration(
            labelText: 'report_store_search_label'.tr(),
            hintText: 'search_store_or_category_hint'.tr(),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: kLine),
            borderRadius: BorderRadius.circular(12),
          ),
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('report_no_matching_eligible_stores'.tr()),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final store = filtered[index];
                    final storeId = (store['storeId'] ?? '').toString();
                    final storeName = (store['storeName'] ?? '').toString();
                    final interactions = (store['interactionsCount'] ?? 0).toString();
                    final lastDate = _formatLastInteractedAt(store['lastInteractedAt']);
                    final selected = _selectedStoreId == storeId;
                    return InkWell(
                      onTap: () => setState(() => _selectedStoreId = storeId),
                      child: Container(
                        color: selected ? kTeal.withValues(alpha: 0.06) : null,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected ? kTeal : Colors.grey,
                          ),
                          title: Text(storeName),
                          subtitle: Text(
                            'report_store_interactions_with_date'.tr(namedArgs: {
                              'count': interactions,
                              'date': lastDate.isEmpty ? '-' : lastDate,
                            }),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> reportTypes = [
      'expired',
      'bad_service',
      'inappropriate_treatment',
      'price_not_matching_offer',
      'misleading_advertisement',
      'other_report',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('report_product_or_service'.tr()),
        backgroundColor: kTealDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'report_eligible_stores_only_hint'.tr(),
                style: const TextStyle(color: kTealDark, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildEligibleStoresSelector(),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'report_type'.tr(),
                  border: const OutlineInputBorder(),
                ),
                initialValue: _selectedType,
                items: reportTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.tr()),
                )).toList(),
                onChanged: (val) => setState(() => _selectedType = val),
                validator: (val) => val == null ? 'please_select_report_type'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'report_description'.tr(),
                  hintText: 'write_details_here'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
                onSaved: (val) => _description = val,
                validator: (val) => (val == null || val.isEmpty) ? 'please_write_report_description'.tr() : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _submitReport();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  tr('send_report'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

