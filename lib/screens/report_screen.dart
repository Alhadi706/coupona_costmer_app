import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  String? _storeName;
  String? _description;
  XFile? _pickedImage;

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
  String? _storeId; // لتخزين ID المحل المختار

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  void _submitReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // حفظ البلاغ في Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'type': _selectedType,
        'storeName': _storeName,
        'description': _description,
        'createdAt': DateTime.now().toIso8601String(),
        // يمكنك إضافة بيانات المستخدم أو الصورة إذا أردت
        // 'userId': ...
        // 'imageUrl': ...
        'status': 'new', // جديد
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('report_sent'.tr()),
          content: Text('report_sent_message'.tr()),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {}); // لإجبار الشاشة على إعادة البناء عند تغيير اللغة
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        key: ValueKey(context.locale.languageCode),
        appBar: AppBar(
          title: Text('report_product_or_service'.tr()),
          backgroundColor: Colors.deepPurple.shade700,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // اسم المحل أو العلامة التجارية
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: () async {
                      try {
                        final snap = await FirebaseService.firestore.collection('merchants').get();
                        final list = snap.docs.map((d) {
                          final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
                          return {
                            'id': d.id,
                            'name': (m['name'] ?? m['storeName'] ?? '').toString(),
                          };
                        }).where((store) => (store['name'] as String).isNotEmpty).toList();
                        return list;
                      } catch (e) {
                        debugPrint('Fetch merchants error: $e');
                        return const <Map<String, dynamic>>[];
                      }
                    }(),
                    builder: (context, snapshot) {
                      final stores = snapshot.data ?? [];
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
                            _storeId = selection['id'];
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
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
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
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
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
        ),
      ),
    );
  }
}

