import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;

import '../services/firebase_service.dart';
import '../services/firestore/customer_repository.dart';
import '../services/firestore/merchant_customer_room_repository.dart';
import '../services/firestore/notification_repository.dart';
import 'map_picker_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  XFile? _pickedImage;
  bool _isSubmitting = false;

  final List<String> products = [
    'كوكاكولا زيرو',
    'بيبسي دايت',
    'مياه معدنية',
    'شيبس',
    'عصير برتقال',
  ];
  final List<String> issueTypes = ['صلاحية', 'جودة', 'سعر', 'خدمة', 'أخرى'];

  String? selectedMerchant;
  String? selectedProduct;
  String? selectedIssueType;
  String? location;
  String? reportText;
  String? _storeId; // لتخزين ID المحل المختار

  final _customerRepository = CustomerRepository();
  final _notificationRepository = NotificationRepository();
  final _roomRepository = MerchantCustomerRoomRepository();

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    if (_storeId == null || _storeId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('report_select_store'.tr())));
      return;
    }
    if (selectedIssueType == null || selectedIssueType!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('report_select_issue'.tr())));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('report_login_required'.tr())));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = await _customerRepository.fetchCustomer(user.uid);
      final customerName = profile?.name.isNotEmpty == true
          ? profile!.name
          : (user.displayName ?? '');
      final customerPhone = profile?.phone ?? user.phoneNumber ?? '';

      final reportRef = await FirebaseService.firestore
          .collection('reports')
          .add({
            'merchantId': _storeId,
            'merchantName': selectedMerchant,
            'customerId': user.uid,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'productName': selectedProduct ?? '',
            'issueType': selectedIssueType ?? '',
            'description': reportText ?? '',
            'location': location,
            'status': 'new',
            'attachments': _pickedImage != null
                ? [_pickedImage!.path]
                : const [],
            'createdAt': FieldValue.serverTimestamp(),
          });

      try {
        await _notificationRepository.createNotification(
          userId: _storeId!,
          title: 'report_notification_title'.tr(
            namedArgs: {
              'customer': customerName.isEmpty
                  ? 'report_anonymous_user'.tr()
                  : customerName,
            },
          ),
          body: 'report_notification_body'.tr(
            namedArgs: {
              'customer': customerName.isEmpty
                  ? 'report_anonymous_user'.tr()
                  : customerName,
              'product': selectedProduct ?? '-',
              'issue': selectedIssueType ?? '',
            },
          ),
          type: 'report',
          metadata: {
            'reportId': reportRef.id,
            'merchantId': _storeId,
            'merchantName': selectedMerchant,
            'customerId': user.uid,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'productName': selectedProduct ?? '',
            'issueType': selectedIssueType ?? '',
            'description': reportText ?? '',
            'location': location,
          },
        );
      } on FirebaseException catch (error, stackTrace) {
        debugPrint('Skipped notification creation: ${error.message}');
        debugPrintStack(stackTrace: stackTrace);
      }

      await _roomRepository.ensureRoomExists(
        merchantId: _storeId!,
        customerId: user.uid,
      );

      final bool? navigateHome = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text('report_sent'.tr()),
          content: Text('report_sent_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );

      if (mounted && navigateHome == true) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('Report submission failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('report_submit_error'.tr())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      textDirection: context.locale.languageCode == 'ar'
          ? ui.TextDirection.rtl
          : ui.TextDirection.ltr,
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
                        final snap = await FirebaseService.firestore
                            .collection('merchants')
                            .get();
                        final list = snap.docs
                            .map((d) {
                              final m = Map<String, dynamic>.from(d.data());
                              return {
                                'id': d.id,
                                'name': (m['name'] ?? m['storeName'] ?? '')
                                    .toString(),
                              };
                            })
                            .where(
                              (store) => (store['name'] as String).isNotEmpty,
                            )
                            .toList();
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
                            return (store['name'] as String)
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (store) => store['name'] ?? '',
                        onSelected: (Map<String, dynamic> selection) {
                          setState(() {
                            selectedMerchant = selection['name'];
                            _storeId = selection['id'];
                          });
                        },
                        fieldViewBuilder:
                            (
                              context,
                              controller,
                              focusNode,
                              onEditingComplete,
                            ) {
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
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        selectedProduct = selection;
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
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
                    items: issueTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(tr(type)),
                          ),
                        )
                        .toList(),
                    value: selectedIssueType,
                    onChanged: (value) =>
                        setState(() => selectedIssueType = value),
                  ),
                  const SizedBox(height: 16),
                  // تحديد الموقع
                  if (selectedMerchant == null ||
                      selectedMerchant!.isEmpty) ...[
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
                              initialLocation: location != null
                                  ? LatLng(
                                      double.parse(location!.split(',')[0]),
                                      double.parse(location!.split(',')[1]),
                                    )
                                  : null,
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
                      Text(
                        'الموقع المختار: $location',
                        style: const TextStyle(color: Colors.green),
                      ),
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
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickImage,
                    icon: const Icon(Icons.attachment),
                    label: Text('attach_image'.tr()),
                  ),
                  if (_pickedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _pickedImage!.name,
                              style: const TextStyle(color: Colors.green),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isSubmitting ? tr('report_sending') : tr('send_report'),
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
