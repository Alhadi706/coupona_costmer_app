import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:coupona_app/services/company_server_service.dart';
import 'package:coupona_app/theme/design_tokens.dart';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';

class AddCouponScreen extends StatefulWidget {
  const AddCouponScreen({super.key});

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
      final bytes = await _pickedImage!.readAsBytes();
      if (bytes.isNotEmpty) {
        return CompanyServerService.uploadImageBytes(
          bytes,
          mimeType: _pickedImage!.mimeType ?? _mimeTypeForPath(_pickedImage!.path),
        );
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_upload_image'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
      return null;
    }
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    debugPrint('تم استدعاء _submit');
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
      final DateTime now = DateTime.now().toUtc();
      String? imageUrl = await _uploadImage();
      debugPrint('بعد رفع الصورة');
      if (imageUrl == null || imageUrl.isEmpty) {
        imageUrl = 'assets/img/map_sample.png';
      }
      await CompanyServerService.createOffer({
        'offerType': _offerType!,
        'category': _category!,
        'titleType': _titleType,
        'discountType': _discountType,
        'discountValue': _discountValue,
        'price': _price,
        'description': _description,
        'startDate': _startDate?.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'location': _location,
        'imageUrl': imageUrl,
        'createdAt': now.toIso8601String(),
        'lifecycleStatus': 'pending_review',
        'lifecycleUpdatedAt': now.toIso8601String(),
        'lifecycleReason': 'created_from_add_coupon_screen',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('success_offer'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      debugPrint('بعد إظهار Dialog النجاح');
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
          backgroundColor: kTeal,
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
                          style: TextStyle(color: kTeal),
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
                      foregroundColor: kWhite,
                      backgroundColor: kTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: kWhite)
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