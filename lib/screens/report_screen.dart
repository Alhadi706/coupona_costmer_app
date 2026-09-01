import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'map_picker_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _storeSearchController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();

  bool _loadingStores = true;
  String? _storesError;
  List<Map<String, dynamic>> _eligibleStores = const <Map<String, dynamic>>[];

  String? _selectedType;
  String? _description;
  String? _selectedStoreId;
  String? _selectedBrandId;
  String? _selectedProductName;
  LatLng? _manualLocation;
  XFile? _evidenceImage;
  Uint8List? _evidenceBytes;
  bool _uploading = false;
  List<Map<String, dynamic>> _productOptions = const <Map<String, dynamic>>[];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadEligibleStores();
    _storeSearchController.addListener(_searchStores);
    _productNameController.addListener(_loadProductOptions);
  }

  Future<void> _loadProductOptions() async {
    final query = _productNameController.text.trim();
    if (_selectedProductName != null && query != _selectedProductName) {
      _selectedProductName = null;
      _selectedBrandId = null;
    }
    if (query.length < 2) {
      if (mounted) setState(() => _productOptions = const <Map<String, dynamic>>[]);
      return;
    }
    setState(() => _loadingProducts = true);
    try {
      final options = await CompanyServerService.getReportProductOptions(query);
      if (!mounted || _productNameController.text.trim() != query) return;
      setState(() => _productOptions = options);
    } catch (_) {
      if (mounted) setState(() => _productOptions = const <Map<String, dynamic>>[]);
    } finally {
      if (mounted && _productNameController.text.trim() == query) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  @override
  void dispose() {
    _storeSearchController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _loadEligibleStores() async {
    setState(() {
      _loadingStores = true;
      _storesError = null;
    });
    try {
      final stores = await CompanyServerService.getEligibleReportStores(query: _storeSearchController.text.trim());
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

  Future<void> _searchStores() async {
    final query = _storeSearchController.text.trim();
    List<Map<String, dynamic>> stores;
    try {
      stores = await CompanyServerService.getEligibleReportStores(query: query);
    } catch (_) {
      return;
    }
    if (!mounted || _storeSearchController.text.trim() != query) return;
    setState(() => _eligibleStores = stores);
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
      final unregisteredStore = _selectedStoreId?.startsWith('visited:') == true;
      if ((_selectedStoreId == null || _selectedStoreId!.isEmpty) && _manualLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('please_select_eligible_store'.tr())),
        );
        return;
      }
      if (unregisteredStore && _manualLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('report_location_required_for_unregistered'.tr())),
        );
        return;
      }
      setState(() => _uploading = true);
      try {
        String? imageUrl;
        if (_evidenceBytes != null) {
          imageUrl = await CompanyServerService.uploadImageBytes(_evidenceBytes!);
        }
        await CompanyServerService.createReport(
          reportType: _selectedType ?? 'other',
          targetStoreId: _selectedStoreId,
          targetBrandId: _selectedBrandId,
          description: _description ?? '',
          productName: _productNameController.text.trim().isEmpty ? null : _productNameController.text.trim(),
          imageUrl: imageUrl,
          locationLat: _manualLocation?.latitude,
          locationLng: _manualLocation?.longitude,
          locationAddress: _manualLocation == null ? null : '${_manualLocation!.latitude.toStringAsFixed(6)}, ${_manualLocation!.longitude.toStringAsFixed(6)}',
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('report_send_failed'.tr())),
        );
        return;
      } finally {
        if (mounted) setState(() => _uploading = false);
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
        _selectedBrandId = null;
        _selectedProductName = null;
        _manualLocation = null;
        _evidenceImage = null;
        _evidenceBytes = null;
        _productNameController.clear();
      });
    }
  }

  Future<void> _pickEvidenceImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _evidenceImage = image;
      _evidenceBytes = bytes;
    });
  }

  Future<void> _pickManualLocation() async {
    final location = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: _manualLocation)),
    );
    if (location != null && mounted) setState(() => _manualLocation = location);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('report_no_registered_stores'.tr()),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _pickManualLocation, icon: const Icon(Icons.map_outlined), label: Text('report_choose_map_location'.tr())),
              if (_manualLocation != null) Text('report_location_selected'.tr(namedArgs: {'lat': _manualLocation!.latitude.toStringAsFixed(5), 'lng': _manualLocation!.longitude.toStringAsFixed(5)})),
            ],
          ),
        ),
      );
    }

    final filtered = _eligibleStores;

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('report_no_matching_registered_stores'.tr()),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: _pickManualLocation, icon: const Icon(Icons.map_outlined), label: Text('report_choose_map_location'.tr())),
                      ],
                    ),
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
                      onTap: () => setState(() {
                        _selectedStoreId = storeId;
                        if (store['isRegistered'] == true) _manualLocation = null;
                      }),
                      child: Container(
                        color: selected ? kTeal.withValues(alpha: 0.06) : null,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected ? kTeal : Colors.grey,
                          ),
                          title: Text(storeName),
                          subtitle: store['isRegistered'] == true
                              ? Text((store['locationAddress'] ?? 'report_registered_store'.tr()).toString())
                              : Text('report_store_interactions_with_date'.tr(namedArgs: {
                                  'count': interactions,
                                  'date': lastDate.isEmpty ? '-' : lastDate,
                                })),
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
    final showProductSelector = _selectedType == 'expired' ||
      _selectedType == 'price_not_matching_offer' ||
      _selectedType == 'other_report';

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
                onChanged: (val) => setState(() {
                  _selectedType = val;
                  if (val != 'expired' && val != 'price_not_matching_offer' && val != 'other_report') {
                    _productNameController.clear();
                    _productOptions = const <Map<String, dynamic>>[];
                    _selectedBrandId = null;
                    _selectedProductName = null;
                  }
                }),
                validator: (val) => val == null ? 'please_select_report_type'.tr() : null,
              ),
              const SizedBox(height: 16),
              if (showProductSelector) ...[
                TextFormField(
                  controller: _productNameController,
                  decoration: InputDecoration(labelText: 'report_product_name'.tr(), hintText: 'report_product_name_hint'.tr(), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.inventory_2_outlined)),
                ),
                if (_loadingProducts) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                if (_productOptions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(8)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _productOptions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = _productOptions[index];
                        final name = (product['name'] ?? '').toString();
                        final brandName = (product['brandName'] ?? '').toString();
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(name),
                          subtitle: brandName.isEmpty ? Text('report_product_from_invoices'.tr()) : Text(brandName),
                          onTap: () => setState(() {
                            _productNameController.text = name;
                            _selectedBrandId = product['brandId']?.toString();
                            _selectedProductName = name;
                            _productOptions = const <Map<String, dynamic>>[];
                          }),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              Text(
                'report_eligible_stores_only_hint'.tr(),
                style: const TextStyle(color: kTealDark, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildEligibleStoresSelector(),
              const SizedBox(height: 16),
              if (_selectedStoreId == null || _selectedStoreId!.startsWith('visited:') || _manualLocation != null) ...[
                OutlinedButton.icon(onPressed: _pickManualLocation, icon: const Icon(Icons.map_outlined), label: Text(_manualLocation == null ? 'report_choose_map_location'.tr() : 'report_change_map_location'.tr())),
                if (_manualLocation != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('report_location_selected'.tr(namedArgs: {'lat': _manualLocation!.latitude.toStringAsFixed(5), 'lng': _manualLocation!.longitude.toStringAsFixed(5)}))),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(onPressed: _pickEvidenceImage, icon: const Icon(Icons.add_a_photo_outlined), label: Text(_evidenceImage == null ? 'report_add_image'.tr() : 'report_image_selected'.tr())),
              const SizedBox(height: 16),
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
                onPressed: _uploading ? null : () {
                  _submitReport();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _uploading ? 'uploading'.tr() : tr('send_report'),
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

