// filepath: lib/screens/scan_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoOpenCamera && _capturedImage == null) {
      _didAutoOpenCamera = true;
      Future.delayed(Duration.zero, () => _captureImage(isPanorama: false));
    }
  }

  Future<void> _captureImage({bool isPanorama = false}) async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _ocrResult = null;
    });
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });
        // هنا منطق دمج الصور إذا كان isPanorama = true
        // ثم منطق قراءة الفاتورة (OCR)
        await _processInvoice(image);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'حدث خطأ أثناء التقاط الصورة';
      });
    }
  }

  Future<void> _processInvoice(XFile image) async {
    // محاكاة معالجة OCR واستخراج البيانات
    await Future.delayed(const Duration(seconds: 2));
    // هنا تضع منطق OCR الحقيقي لاحقًا
    // مثال نتيجة وهمية:
    setState(() {
      _isProcessing = false;
      _ocrResult = '''\nرقم الفاتورة: 123456\nاسم المحل: سوبر ماركت ربيع\nالتاريخ: 2025-06-03\nالمنتجات:\n- عصير برتقال ×2 = 10 ريال\n- خبز ×1 = 3 ريال\nالمجموع: 13 ريال\n''';
    });
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _ocrResult = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('scan_invoice_icon'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : _capturedImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.deepPurple, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text('scan_invoice_place_inside_frame'.tr(), style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _captureImage(isPanorama: false),
                            icon: const Icon(Icons.camera_alt),
                            label: Text('scan_invoice_capture'.tr()),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, textStyle: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _captureImage(isPanorama: true),
                            icon: const Icon(Icons.panorama),
                            label: Text('scan_invoice_capture_long'.tr()),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade200),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ]
                    ],
                  )
                : Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_capturedImage!.path),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_ocrResult != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_ocrResult!, style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reset,
                          child: const Text('إعادة التصوير'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // هنا منطق المتابعة أو إضافة النقاط
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('scan_invoice_success'.tr()),
                                content: Text('scan_invoice_points_added'.tr()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text('ok'.tr()),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text('continue'.tr()),
                        ),
                      ]
                    ],
                  ),
      ),
    );
  }
}