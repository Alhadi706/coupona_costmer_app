import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/company_server_service.dart';

const Color kMerchantPrimary = Color(0xFF0A5C43);
const Color kMerchantGold = Color(0xFFD9A441);

typedef BannerAdSubmitter = Future<void> Function(Map<String, dynamic> payload);
typedef BannerImagePicker = Future<BannerImageSelection?> Function();
typedef BannerImageUploader = Future<String?> Function(
  Uint8List bytes,
  String mimeType,
);

class BannerImageSelection {
  final Uint8List bytes;
  final String mimeType;

  const BannerImageSelection(this.bytes, {this.mimeType = 'image/jpeg'});
}

/// Dialog / Modal sheet for creating a new Ad Banner with local image upload & live interactive preview.
class CreateBannerDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onAdd;
  final BannerAdSubmitter? submitter;
  final BannerImagePicker? imagePicker;
  final BannerImageUploader? imageUploader;

  const CreateBannerDialog({
    super.key,
    required this.onAdd,
    this.submitter,
    this.imagePicker,
    this.imageUploader,
  });

  @override
  State<CreateBannerDialog> createState() => _CreateBannerDialogState();
}

class _CreateBannerDialogState extends State<CreateBannerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _externalUrlController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String _selectedImageMimeType = 'image/jpeg';

  String _targetType = 'category'; // 'category', 'offer', 'external'
  String _selectedCategory = 'قسم العصائر';
  String _selectedOffer = 'خصم 20% على حلويات العيد';

  String _selectedAudience = 'كافة الزبائن';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateLivePreview);
    _imageUrlController.addListener(_updateLivePreview);
    _externalUrlController.addListener(_updateLivePreview);
    _updateLinkController();
  }

  void _updateLivePreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateLivePreview);
    _imageUrlController.removeListener(_updateLivePreview);
    _externalUrlController.removeListener(_updateLivePreview);
    _titleController.dispose();
    _linkController.dispose();
    _imageUrlController.dispose();
    _externalUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      BannerImageSelection? selection;
      if (widget.imagePicker != null) {
        selection = await widget.imagePicker!();
      } else {
        final pickedFile = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (pickedFile != null) {
          selection = BannerImageSelection(
            await pickedFile.readAsBytes(),
            mimeType: pickedFile.mimeType ?? 'image/jpeg',
          );
        }
      }
      if (selection != null && mounted) {
        setState(() {
          _selectedImageBytes = selection!.bytes;
          _selectedImageMimeType = selection.mimeType;
          _imageUrlController.text =
              'data:${selection.mimeType};base64,${base64Encode(selection.bytes)}';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _imageUrlController.clear();
    });
  }

  void _updateLinkController() {
    if (_targetType == 'category') {
      _linkController.text = _selectedCategory;
    } else if (_targetType == 'offer') {
      _linkController.text = _selectedOffer;
    } else {
      _linkController.text = _externalUrlController.text.trim();
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final titleText = _titleController.text.trim();
    final hasImage =
        _selectedImageBytes != null ||
        _imageUrlController.text.trim().isNotEmpty;

    if (!hasImage) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار صورة البانر أولاً')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    _updateLinkController();
    var finalImageUrl = _imageUrlController.text.trim();

    if (_selectedImageBytes != null) {
      try {
        final uploadedUrl = widget.imageUploader != null
            ? await widget.imageUploader!(
                _selectedImageBytes!,
                _selectedImageMimeType,
              )
            : await CompanyServerService.uploadImageBytes(
                _selectedImageBytes!,
                mimeType: _selectedImageMimeType,
              );
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalImageUrl = uploadedUrl;
        } else {
          throw StateError('image_upload_returned_empty_url');
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر رفع صورة الإعلان. حاول مرة أخرى.'),
          ),
        );
        return;
      }
    }

    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'offerType': 'BANNER',
      'category': _targetType,
      'titleType': 'custom',
      'description': titleText.isNotEmpty ? titleText : 'بانر إعلاني جديد',
      'startDate': now.toIso8601String(),
      'endDate': _expiryDate.toUtc().toIso8601String(),
      'location': _selectedAudience,
      'imageUrl': finalImageUrl,
      'createdAt': now.toIso8601String(),
      'ctaType': _targetType,
      'ctaValue': _linkController.text.trim(),
    };

    try {
      await (widget.submitter ?? CompanyServerService.createBillboardAd)(
        payload,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('insufficient_gold_points')
                ? 'رصيدك الذهبي غير كافٍ لإطلاق البانر'
                : 'تعذر إرسال الإعلان للمراجعة. حاول مرة أخرى.',
          ),
        ),
      );
      return;
    }

    final newBanner = {
      'id': 'banner-${DateTime.now().millisecondsSinceEpoch}',
      'title': titleText.isNotEmpty ? titleText : 'بانر إعلاني جديد',
      'targetLink': _linkController.text.trim().isNotEmpty
          ? _linkController.text.trim()
          : 'الصفحة الرئيسية',
      'campaign_type': 'BANNER',
      'status': 'pending_review',
      'lifecycleStatus': 'pending_review',
      'issued_count': 0,
      'redeemed_count': 0,
      'ends_at': _expiryDate.toString().split(' ').first,
      'audience': _selectedAudience,
      'image_url': finalImageUrl,
    };

    widget.onAdd(newBanner);
    if (mounted) {
      setState(() => _isSubmitting = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تم إرسال الإعلان بنجاح!'),
          content: const Text(
            'تم خصم نقاط الإعلان وحفظ الطلب، وهو الآن قيد مراجعة وتفعيل إدارة المنصة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.add_photo_alternate,
                    color: kMerchantPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'إضافة بانر إعلاني رئيسي جديد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // 📲 2. Live Banner Interactive Preview
              _buildLivePreviewCard(),

              // 🖼️ 1. Local Image Upload Picker
              _buildImagePickerZone(),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                key: const Key('banner-title-field'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإعلان *',
                  hintText: 'مثال: خصم 20% على حلويات العيد',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title, color: kMerchantPrimary),
                ),
                validator: (val) {
                  final hasImg =
                      _selectedImageBytes != null ||
                      _imageUrlController.text.trim().isNotEmpty;
                  if ((val == null || val.trim().isEmpty) && !hasImg) {
                    return 'يرجى إدخال عنوان الإعلان';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 🎯 3. Smart Destination Link Dropdown
              _buildTargetDestinationSection(),
              const SizedBox(height: 16),

              // Audience Selection Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedAudience,
                decoration: const InputDecoration(
                  labelText: 'الجمهور المستهدف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups, color: kMerchantPrimary),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'كافة الزبائن',
                    child: Text('كافة الزبائن'),
                  ),
                  DropdownMenuItem(
                    value: 'أفضل العملاء',
                    child: Text('أفضل العملاء (Top Spenders)'),
                  ),
                  DropdownMenuItem(
                    value: 'العملاء غير النشطين',
                    child: Text('العملاء غير النشطين (Inactive)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAudience = val);
                },
              ),
              const SizedBox(height: 16),

              // Expiry Date Selection
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                title: const Text('تاريخ انتهاء الإعلان'),
                subtitle: Text(_expiryDate.toString().split(' ').first),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: kMerchantPrimary,
                ),
                onTap: _selectExpiryDate,
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                key: const Key('submit-banner-btn'),
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMerchantPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إطلاق البانر الإعلاني',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final displayTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'عنوان الإعلان المعاين';
    final formattedDate = _expiryDate.toString().split(' ').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kMerchantPrimary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: kMerchantPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'معاينة تفاعلية للإعلان (شاشة العميل)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
                child: _buildBannerPreviewImage(),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                left: 12,
                bottom: 34,
                child: Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                left: 12,
                bottom: 8,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kMerchantGold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🎯 $_selectedAudience',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '📅 $formattedDate',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPreviewImage() {
    if (_selectedImageBytes != null) {
      return Image.memory(
        key: const Key('banner-live-preview-image'),
        _selectedImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 130,
      );
    }
    final url = _imageUrlController.text.trim();
    if (url.isNotEmpty && !url.startsWith('data:')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 130,
        errorBuilder: (_, __, ___) => _buildPlaceholderGraphic(),
      );
    }
    return _buildPlaceholderGraphic();
  }

  Widget _buildPlaceholderGraphic() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kMerchantPrimary, kMerchantPrimary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.white70, size: 38),
          SizedBox(height: 4),
          Text(
            'معاينة صورة البانر',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'صورة البانر الإعلاني',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (_selectedImageBytes != null)
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kMerchantPrimary),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 90,
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.6),
                    radius: 14,
                    child: IconButton(
                      key: const Key('remove-banner-image-btn'),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: _clearSelectedImage,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            key: const Key('banner-image-picker-btn'),
            onTap: _pickBannerImage,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: kMerchantPrimary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kMerchantPrimary.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: kMerchantPrimary),
                  SizedBox(width: 8),
                  Text(
                    'اختيار صورة البانر من الجهاز',
                    style: TextStyle(
                      color: kMerchantPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTargetDestinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('banner-target-type-dropdown'),
          isExpanded: true,
          initialValue: _targetType,
          decoration: const InputDecoration(
            labelText: 'نوع الوجهة الإعلانية *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link, color: kMerchantPrimary),
          ),
          items: const [
            DropdownMenuItem(
              value: 'category',
              child: Text('قسم داخل المتجر (Store Category)'),
            ),
            DropdownMenuItem(
              value: 'offer',
              child: Text('عرض / كوبون خاص (Specific Offer)'),
            ),
            DropdownMenuItem(
              value: 'external',
              child: Text('رابط خارجي (External Web Link)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _targetType = val;
                _updateLinkController();
              });
            }
          },
        ),
        const SizedBox(height: 10),

        if (_targetType == 'category')
          DropdownButtonFormField<String>(
            key: const Key('banner-category-dropdown'),
            isExpanded: true,
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'اختر قسم المتجر المربوط',
              border: OutlineInputBorder(),
              prefixIcon: Icon(
                Icons.category_outlined,
                color: kMerchantPrimary,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'قسم العصائر',
                child: Text('قسم العصائر'),
              ),
              DropdownMenuItem(
                value: 'قسم الحلويات',
                child: Text('قسم الحلويات'),
              ),
              DropdownMenuItem(
                value: 'قسم المخبوزات',
                child: Text('قسم المخبوزات'),
              ),
              DropdownMenuItem(
                value: 'المأكولات الرئيسية',
                child: Text('المأكولات الرئيسية'),
              ),
              DropdownMenuItem(
                value: 'قسم العروض الخاصة',
                child: Text('قسم العروض الخاصة'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedCategory = val;
                  _updateLinkController();
                });
              }
            },
          )
        else if (_targetType == 'offer')
          DropdownButtonFormField<String>(
            key: const Key('banner-offer-dropdown'),
            isExpanded: true,
            initialValue: _selectedOffer,
            decoration: const InputDecoration(
              labelText: 'اختر العرض / الكوبون المربوط',
              border: OutlineInputBorder(),
              prefixIcon: Icon(
                Icons.local_offer_outlined,
                color: kMerchantPrimary,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'خصم 20% على حلويات العيد',
                child: Text('خصم 20% على حلويات العيد'),
              ),
              DropdownMenuItem(
                value: 'عرض اشتري 1 واحصل على 1 مجاناً',
                child: Text('عرض اشتري 1 واحصل على 1 مجاناً'),
              ),
              DropdownMenuItem(
                value: 'كوبون الترحيب 15% خصم',
                child: Text('كوبون الترحيب 15% خصم'),
              ),
              DropdownMenuItem(
                value: 'هدية مجانية عند الشراء بـ 50 دينار',
                child: Text('هدية مجانية عند الشراء بـ 50 دينار'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedOffer = val;
                  _updateLinkController();
                });
              }
            },
          )
        else if (_targetType == 'external')
          TextFormField(
            key: const Key('banner-link-field'),
            controller: _externalUrlController,
            decoration: const InputDecoration(
              labelText: 'الرابط الخارجي (URL) *',
              hintText: 'https://example.com/promo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.language, color: kMerchantPrimary),
            ),
            onChanged: (_) => _updateLinkController(),
          ),
      ],
    );
  }
}
