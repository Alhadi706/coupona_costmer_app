// filepath: lib/screens/scan_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
// لا تستخدم File مباشرة على الويب
import 'dart:io' show File; // سيُهمل في الويب لكن تجنّب استدعائه عندما kIsWeb = true
import 'package:easy_localization/easy_localization.dart';
import '../services/invoice_parser.dart';
import '../services/supabase_invoice_service.dart';

class ScanInvoiceScreen extends StatefulWidget {
  const ScanInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  XFile? _capturedImage;
  bool _isProcessing = false;
  String? _ocrResult;
  String? _error;
  bool _didAutoOpenCamera = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final TextEditingController _merchantCodeController = TextEditingController(text: 'TRPCF2');

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoOpenCamera && _capturedImage == null) {
      _didAutoOpenCamera = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _captureImage();
        }
      });
    }
  }

  Future<void> _captureImage() async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _error = null;
      _ocrResult = null;
    });
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        // على الويب الكاميرا قد لا تعمل دائماً فنلجأ للمعرض
      );
      if (image != null) {
        if (!mounted) return;
        setState(() {
          _capturedImage = image;
        });
        await _processInvoice(image);
      } else {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'error_capturing_image'.tr();
      });
    }
  }

  Future<void> _processInvoice(XFile image) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _error = null;
      _ocrResult = null;
    });
    try {
      if (kIsWeb) {
        // مكتبة ML Kit غير مدعومة رسمياً على الويب حالياً
        setState(() {
          _isProcessing = false;
          _error = 'ميزة التعرف على النص غير مدعومة على الويب حالياً، جرّب التطبيق على الهاتف.';
        });
        return;
      }
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      if (!mounted) return;
      final extracted = recognizedText.text;
      if (!mounted) return;
      if (extracted.trim().isEmpty) {
        setState(() {
          _isProcessing = false;
          _ocrResult = 'no_text_found'.tr();
        });
        return;
      }

      // Parse invoice
      final parsed = parseInvoiceText(
        extracted,
        merchantCode: _merchantCodeController.text.trim().isEmpty ? 'UNKNOWN' : _merchantCodeController.text.trim(),
      );

      // Save to Supabase (يمكن لاحقاً إضافة check لمنع التكرار بقراءة unique_hash)
      try {
        await SupabaseInvoiceService.addInvoice(
          invoiceNumber: parsed.invoiceNumber,
          storeName: parsed.storeName,
          date: parsed.date,
          products: parsed.products,
          total: parsed.total,
          userId: 'test_user', // TODO: استبدلها بمعرّف المستخدم الحقيقي
          merchantId: parsed.merchantCode, // مؤقتاً نضع code في هذا الحقل
          uniqueHash: parsed.uniqueHash,
          merchantCode: parsed.merchantCode,
        );
      } catch (e) {
        // تجاهل الخطأ التخزيني حالياً لكن أظهر رسالة
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في حفظ الفاتورة: $e')),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _ocrResult = extracted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'error_processing_image'.tr();
      });
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _isProcessing = false;
      _ocrResult = null;
      _error = null;
      _didAutoOpenCamera = false;
    });
    didChangeDependencies();
  }

  Widget _buildResultView() {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('processing_invoice'.tr()),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reset,
              child: Text('try_again'.tr()),
            ),
          ],
        ),
      );
    }
    if (_ocrResult != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _merchantCodeController,
              decoration: const InputDecoration(
                labelText: 'رمز التاجر (Merchant Code)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_capturedImage != null)
              kIsWeb
                  ? Image.network(
                      _capturedImage!.path,
                      height: 200,
                      fit: BoxFit.contain,
                    )
                  : Image.file(
                      File(_capturedImage!.path),
                      fit: BoxFit.contain,
                      height: 200,
                    ),
            const SizedBox(height: 16),
            Text(
              'invoice_text'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SelectableText(
                  _ocrResult!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reset,
              child: Text('scan_another_invoice'.tr()),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'scan_invoice_to_get_text'.tr(),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('scan_invoice'.tr()),
        actions: [
          if (_capturedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'reset'.tr(),
            ),
        ],
      ),
      body: _buildResultView(),
    );
  }
}