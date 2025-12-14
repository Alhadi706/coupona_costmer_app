import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coupona_app/services/imgur_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:coupona_app/services/firebase_service.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';

class AddCouponScreen extends StatefulWidget {
  final String? merchantId;
  const AddCouponScreen({super.key, this.merchantId});

  @override
  State<AddCouponScreen> createState() => _AddCouponScreenState();
}

class _AddCouponScreenState extends State<AddCouponScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _offerType;
  String? _category;
  String? _titleType;
  String? _discountType; // نوع التخفيض (نسبة/قيمة)
  String? _discountValue; // قيمة التخفيض
  String? _price;
  String? _description;
  XFile? _pickedImage;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _location;
  bool _isLoading = false;

  final TextEditingController _locationController = TextEditingController();

  // بدل النصوص الثابتة في القوائم بمفاتيح ترجمة
  final List<String> _offerTypes = [
    'offer_discount_product',
    'offer_real_estate',
    'offer_resthouse',
    'other',
  ];
  final List<String> _categories = [
    'restaurants', 'real_estate', 'clothes', 'electronics', 'resthouses', 'health', 'activities', 'other'
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return null;
    try {
      if (kIsWeb) {
        debugPrint('Uploading image to Firebase Storage (web)');
        final bytes = await _pickedImage!.readAsBytes().timeout(const Duration(seconds: 10));
        final fileName = 'offers/${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}';
        final ref = FirebaseService.storage.ref().child(fileName);
        // putData can take time; guard with timeout
        try {
          final uploadSnapshot = await ref.putData(bytes).timeout(const Duration(seconds: 15));
          debugPrint('Upload snapshot state: ${uploadSnapshot.state}');
          final url = await ref.getDownloadURL().timeout(const Duration(seconds: 5));
          debugPrint('Got download URL: $url');
          return url;
        } on TimeoutException catch (te) {
          debugPrint('Firebase upload timed out: $te');
          return null;
        }
      } else {
        debugPrint('Uploading image to Imgur (non-web)');
        try {
          return await ImgurService.uploadImage(File(_pickedImage!.path)).timeout(const Duration(seconds: 15));
        } on TimeoutException catch (te) {
          debugPrint('Imgur upload timed out: $te');
          return null;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_upload_image'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    debugPrint('تم استدعاء _submit');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_auth_required'.tr())),
      );
      return;
    }

    final isMerchantSubmission = widget.merchantId != null;
    final ownerType = isMerchantSubmission ? 'merchant' : 'customer';
    final merchantId = isMerchantSubmission ? widget.merchantId : null;
    final customerId = ownerType == 'customer' ? user.uid : null;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_required_fields'.tr())),
      );
      return;
    }

    _formKey.currentState!.save();
    // تحقق من صحة التواريخ
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_end_before_start'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('قبل رفع الصورة');
      String? imageUrl = await _uploadImage();
      debugPrint('بعد رفع الصورة');
      if (imageUrl == null || imageUrl.isEmpty) {
        imageUrl = 'assets/img/map_sample.png';
      }
      debugPrint('قبل إضافة العرض إلى Firestore');
      bool writeSucceeded = false;
      try {
        debugPrint('Adding offer to Firestore');
        // guard Firestore write with a timeout so UI won't hang indefinitely
        await FirebaseFirestore.instance
            .collection('offers')
            .add({
              'ownerType': ownerType,
              'merchantId': merchantId,
              'customerId': customerId,
              'createdBy': user.uid,
              'category': _category!,
              'titleType': _titleType,
              'discountType': _discountType,
              'discountValue': _discountValue,
              'price': _price,
              'description': _description,
              'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
              'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
              'location': _location,
              'imageUrl': imageUrl,
              'createdAt': Timestamp.now(),
            })
            .timeout(const Duration(seconds: 8));
        writeSucceeded = true;
        debugPrint('بعد إضافة العرض إلى Firestore');
      } catch (e, stack) {
        // Log the Firestore error and notify the user. Do not show success dialog.
        debugPrint('خطأ أثناء إضافة العرض إلى Firestore: $e\n$stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error_save_offer_firestore'.tr())),
          );
        }
      }

      // الآن نعتمد على Firestore فقط.
      if (!writeSucceeded) {
        // Keep loading false and return so user can retry.
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      debugPrint('قبل إظهار Dialog النجاح');
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green, size: 56),
            ),
          ),
          content: Text('success_offer'.tr(), textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // يغلق الـ Dialog فقط
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('back_to_home'.tr(), style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
      debugPrint('بعد إظهار Dialog النجاح');
      // بعد إغلاق الـ Dialog نرجع للـ screen السابق مع نتيجة نجاح
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    } catch (e, stack) {
      debugPrint('Add offer error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_add_offer'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_location != null) {
      _locationController.text = _location!;
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
          title: Text('add_coupon_title'.tr()),
          backgroundColor: Colors.deepPurple.shade700,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'offer_type'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  value: _offerType,
                  items: _offerTypes.map((type) => DropdownMenuItem(
                    value: type,
                    // عند عرض القيم في واجهة المستخدم استخدم tr() دائمًا
                    child: Text(type.tr()),
                  )).toList(),
                  onChanged: (val) => setState(() {
                    _offerType = val;
                    // عند التحقق من القيم استخدم المفاتيح وليس النصوص
                    _titleType = val == 'offer_discount_product' ? 'discount' : null;
                  }),
                  validator: (val) => val == null ? 'error_required_fields'.tr() : null,
                ),
                const SizedBox(height: 16),
                
                if (_offerType == 'offer_discount_product') ...[
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'discount_type'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    value: _discountType,
                    items: [
                      DropdownMenuItem(value: 'percent', child: Text('discount_percent'.tr())),
                      DropdownMenuItem(value: 'fixed', child: Text('discount_fixed'.tr())),
                    ],
                    onChanged: (val) => setState(() => _discountType = val),
                    validator: (val) => val == null ? 'error_required_fields'.tr() : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'discount_value'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSaved: (val) => _discountValue = val,
                    validator: (val) => (val == null || val.isEmpty) ? 'error_required_fields'.tr() : null,
                  ),
                  const SizedBox(height: 16),
                ],
                
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'category'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  value: _category,
                  items: _categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    // عند عرض القيم في واجهة المستخدم استخدم tr() دائمًا
                    child: Text(cat.tr()),
                  )).toList(),
                  onChanged: (val) => setState(() => _category = val),
                  validator: (val) => val == null ? 'error_required_fields'.tr() : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'price'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (val) => _price = val,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'description'.tr(),
                    hintText: 'description_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onSaved: (val) => _description = val,
                  validator: (val) => (val == null || val.isEmpty) ? 'error_required_fields'.tr() : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.attach_file),
                      label: Text('attach_image'.tr()),
                    ),
                    const SizedBox(width: 12),
                    if (_pickedImage != null)
                      Expanded(
                        child: Text(
                          'image_selected'.tr(),
                          style: TextStyle(color: Colors.green.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isStart: true),
                        child: Text(_startDate == null ? 'start_date'.tr() : _startDate!.toString().split(' ')[0]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isStart: false),
                        child: Text(_endDate == null ? 'end_date'.tr() : _endDate!.toString().split(' ')[0]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'location'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MapPickerScreen(),
                          ),
                        );
                        if (result != null && result is LatLng) {
                          setState(() {
                            _locationController.text =
                                '${result.latitude},${result.longitude}';
                            _location = _locationController.text;
                          });
                        }
                      },
                    ),
                  ),
                  onSaved: (val) => _location = val,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('publish_offer'.tr(), style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// أضف مفاتيح الترجمة الجديدة في ملفات ar.json و en.json
// مثال (ar.json):
// "offer_discount_product": "تخفيض على منتج / خدمة",
// "offer_real_estate": "عرض عقار للبيع",
// "offer_resthouse": "عرض استراحة للإيجار",
// "other": "أخرى",
// "restaurants": "مطاعم",
// "real_estate": "عقارات",
// "clothes": "ملابس",
// "electronics": "إلكترونيات",
// "resthouses": "استراحات",
// "health": "صحة",
// "activities": "أنشطة"
// مثال (en.json):
// "offer_discount_product": "Discount on Product/Service",
// "offer_real_estate": "Real Estate Offer",
// "offer_resthouse": "Resthouse for Rent",
// "other": "Other",
// "restaurants": "Restaurants",
// "real_estate": "Real Estate",
// "clothes": "Clothes",
// "electronics": "Electronics",
// "resthouses": "Resthouses",
// "health": "Health",
// "activities": "Activities"