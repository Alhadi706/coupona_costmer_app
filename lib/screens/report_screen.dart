import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  String? _storeName;
  String? _description;
  String? _selectedStoreId;

  final List<String> merchants = [
    'كوكاكولا',
    'بيبسي',
    'مطعم الشاطئ',
    'صيدلية الحياة',
    'سوبرماركت المدينة',
  ];
  final List<String> products = [
    'كوكاكولا زيرو',
    'بيبسي دايت',
    'مياه معدنية',
    'شيبس',
    'عصير برتقال',
  ];
  final List<String> issueTypes = [
    'صلاحية',
    'جودة',
    'سعر',
    'خدمة',
    'أخرى',
  ];

  String? selectedMerchant;
  String? selectedProduct;
  String? selectedIssueType;
  String? location;
  String? reportText;

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (_selectedStoreId == null || _selectedStoreId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a store from your eligible stores.')),
        );
        return;
      }
      try {
        await CompanyServerService.createReport(
          reportType: _selectedType ?? 'other',
          targetStoreId: _selectedStoreId!,
          description: _description ?? reportText ?? '',
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the report. Please try again.')),
        );
        return;
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('report_sent'.tr()),
          content: Text(
            '${'report_sent_message'.tr()}\n${_storeName ?? ''}${_description == null || _description!.isEmpty ? '' : '\n${_description!}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }
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
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'report_type'.tr(),
                  border: OutlineInputBorder(),
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
                  labelText: 'store_name_or_entity'.tr(),
                  hintText: 'example_supermarket_rabea'.tr(),
                  border: OutlineInputBorder(),
                ),
                onSaved: (val) => _storeName = val,
                validator: (val) => (val == null || val.isEmpty) ? 'please_enter_store_name'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'report_description'.tr(),
                  hintText: 'write_details_here'.tr(),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                onSaved: (val) => _description = val,
                validator: (val) => (val == null || val.isEmpty) ? 'please_write_report_description'.tr() : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // اسم المحل أو العلامة التجارية
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: CompanyServerService.getEligibleReportStores(),
                    builder: (context, snapshot) {
                      List<Map<String, dynamic>> stores = [];
                      if (snapshot.hasData) {
                        stores = snapshot.data!
                            .map((data) => {
                                  'id': data['storeId'],
                                  'name': data['storeName'] ?? '',
                                })
                            .where((store) => (store['name'] as String).isNotEmpty)
                            .toList();
                      }
                      return Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return stores.where((store) {
                            return (store['name'] as String).toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (store) => store['name'] ?? '',
                        onSelected: (Map<String, dynamic> selection) {
                          setState(() {
                            selectedMerchant = selection['name'];
                            _selectedStoreId = selection['id']?.toString();
                            _storeName = selection['name']?.toString();
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: tr('store_name_or_entity'),
                              border: const OutlineInputBorder(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // اسم المنتج
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return products.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        selectedProduct = selection;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: tr('product_name'),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // نوع المشكلة
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: tr('issue_type'),
                      border: const OutlineInputBorder(),
                    ),
                    items: issueTypes.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(tr(type)),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedIssueType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // تحديد الموقع
                  if (selectedMerchant == null || selectedMerchant!.isEmpty) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.location_on),
                      label: Text(tr('pick_store_location_on_map_optional')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: kWhite,
                      ),
                      onPressed: () async {
                        final LatLng? result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MapPickerScreen(
                              initialLocation: location != null ? LatLng(double.parse(location!.split(',')[0]), double.parse(location!.split(',')[1])) : null,
                            ),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            location = "${result.latitude},${result.longitude}";
                          });
                        }
                      },
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 8),
                      Text('الموقع المختار: $location', style: const TextStyle(color: Colors.green)),
                    ],
                  ],
                  const SizedBox(height: 16),
                  // نص البلاغ
                  TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: tr('report_description_optional'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      reportText = value;
                    },
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
            ],
          ),
        ),
      ),
    );
  }
}

