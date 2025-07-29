// filepath: lib/screens/scan_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  final TextRecognizer _textRecognizer = TextRecognizer();

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
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
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
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _ocrResult = recognizedText.text;
        if (_ocrResult!.isEmpty) {
          _ocrResult = 'no_text_found'.tr();
        }
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
            if (_capturedImage != null)
              Image.file(
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