// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'invoice_ocr_service.dart';
import 'invoice_text_parser.dart';

class _WebInvoiceOcrService implements InvoiceOcrService {
  @override
  Future<String> extractText(XFile image) async {
    final bytes = await image.readAsBytes();
    final tesseract = js_util.getProperty<Object?>(html.window, 'Tesseract');
    if (tesseract == null) {
      throw StateError('Tesseract.js is not loaded in web/index.html');
    }

    final sourceUrl = await _bytesToImageUrl(bytes);
    try {
      final sourceImage = await _loadImage(sourceUrl);
      final variants = await _buildCandidateDataUrls(sourceImage);

      String bestText = '';
      var bestScore = -1;

      for (final candidateUrl in variants) {
        final text = await _recognizeWithTesseract(tesseract, candidateUrl);
        final score = _scoreRecognizedText(text);
        if (score > bestScore) {
          bestScore = score;
          bestText = text;
        }
      }

      return bestText.trim();
    } finally {
      html.Url.revokeObjectUrl(sourceUrl);
    }
  }

  Future<String> _bytesToImageUrl(Uint8List bytes) async {
    final blob = html.Blob(<Object?>[bytes]);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  Future<html.ImageElement> _loadImage(String url) {
    final completer = Completer<html.ImageElement>();
    final image = html.ImageElement();
    image.onLoad.first.then((_) => completer.complete(image));
    image.onError.first.then((_) => completer.completeError(StateError('Unable to load image for OCR')));
    image.src = url;
    return completer.future;
  }

  Future<List<String>> _buildCandidateDataUrls(html.ImageElement image) async {
    final int width = image.naturalWidth > 0 ? image.naturalWidth : (image.width ?? 0);
    final int height = image.naturalHeight > 0 ? image.naturalHeight : (image.height ?? 0);
    if (width <= 0 || height <= 0) {
      return <String>[];
    }

    final variants = <String>[];
    variants.add(_imageToDataUrl(image, 0.0, 0.0, width.toDouble(), height.toDouble()));

    final topHeights = <double>[0.42, 0.58, 0.75];
    for (final ratio in topHeights) {
      final cropHeight = (height * ratio).round().clamp(1, height);
      variants.add(_imageToDataUrl(image, 0.0, 0.0, width.toDouble(), cropHeight.toDouble()));
    }

    return variants;
  }

  String _imageToDataUrl(html.ImageElement image, double sx, double sy, double sw, double sh) {
    final canvas = html.CanvasElement(width: sw.round(), height: sh.round());
    final context = canvas.context2D;
    context.drawImageScaledFromSource(image, sx, sy, sw, sh, 0, 0, sw, sh);
    return canvas.toDataUrl('image/jpeg', 0.95);
  }

  Future<String> _recognizeWithTesseract(Object tesseract, String dataUrl) async {
    final promise = js_util.callMethod<Object?>(
      tesseract,
      'recognize',
      <Object?>[dataUrl, 'ara+eng'],
    );
    if (promise == null) {
      return '';
    }
    final result = await js_util.promiseToFuture<Object>(promise);
    final data = js_util.getProperty<Object?>(result, 'data');
    if (data == null) {
      return '';
    }
    final text = js_util.getProperty<Object?>(data, 'text');
    return (text ?? '').toString().trim();
  }

  int _scoreRecognizedText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return 0;

    final parserResult = InvoiceTextParser.parse(normalized);
    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    var score = normalized.length ~/ 20;
    score += lines.length * 4;
    score += (parserResult.storeConfidence * 100).round();
    if (parserResult.storeName != null && parserResult.storeName!.isNotEmpty) {
      score += 90;
    }
    if (parserResult.storeCandidates.isNotEmpty) {
      score += 20;
    }

    for (final line in lines.take(4)) {
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(line)) score += 20;
      if (RegExp(r'مطعم|مطبخ|شامي|سندوتش|restaurant|cafe|burger|شاورما|بيتزا', caseSensitive: false).hasMatch(line)) {
        score += 25;
      }
      if (line.length >= 4 && line.length <= 50) score += 4;
      if (RegExp(r'\d{5,}').hasMatch(line)) score -= 8;
    }

    final digitCount = RegExp(r'\d').allMatches(normalized).length;
    if (digitCount > lines.length * 10) score -= 20;
    return score;
  }
}

InvoiceOcrService createInvoiceOcrServiceImpl() => _WebInvoiceOcrService();