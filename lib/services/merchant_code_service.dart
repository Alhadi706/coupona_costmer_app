import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MerchantCodeService {
  MerchantCodeService({FirebaseFirestore? firestore, Random? random})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? _buildRandom();

  final FirebaseFirestore _firestore;
  final Random _random;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;

  CollectionReference<Map<String, dynamic>> get _codesCollection => _firestore.collection('merchantCodes');
  DocumentReference<Map<String, dynamic>> _merchantDoc(String merchantId) => _firestore.collection('merchants').doc(merchantId);

  /// Returns the existing merchant code or generates and reserves a new one.
  Future<String> ensureCodeForMerchant(String merchantId) async {
    final merchantSnap = await _merchantDoc(merchantId).get();
    final existing = merchantSnap.data()?['merchantCode']?.toString();
    if (existing != null && existing.isNotEmpty) {
      return normalizeCode(existing);
    }

    for (var attempt = 0; attempt < 10; attempt++) {
      final candidate = _generateCode();
      final reserved = await _tryReserveCode(candidate, merchantId);
      if (reserved) {
        return candidate;
      }
    }

    throw Exception('merchant_code_unavailable');
  }

  /// Fetches the merchant id for a code, or null if none exists.
  Future<String?> findMerchantIdByCode(String rawCode) async {
    final normalized = normalizeCode(rawCode);
    if (normalized.isEmpty) return null;
    final doc = await _codesCollection.doc(normalized).get();
    if (!doc.exists) return null;
    final merchantId = doc.data()?['merchantId']?.toString();
    return (merchantId ?? '').isEmpty ? null : merchantId;
  }

  String normalizeCode(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String prettyPrint(String rawCode) {
    final normalized = normalizeCode(rawCode);
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('-');
      }
      buffer.write(normalized[i]);
    }
    return buffer.toString();
  }

  Future<bool> _tryReserveCode(String code, String merchantId) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) return false;
    final codeDoc = _codesCollection.doc(normalized);
    final merchantRef = _merchantDoc(merchantId);
    try {
      return await _firestore.runTransaction<bool>((txn) async {
        final codeSnap = await txn.get(codeDoc);
        if (codeSnap.exists) {
          final existingMerchantId = codeSnap.data()?['merchantId']?.toString();
          if (existingMerchantId == merchantId) {
            txn.set(merchantRef, {
              'merchantCode': normalized,
              'merchantCodeAssignedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            return true;
          }
          return false;
        }

        txn.set(codeDoc, {
          'merchantId': merchantId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.set(merchantRef, {
          'merchantCode': normalized,
          'merchantCodeAssignedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      });
    } on FirebaseException {
      return false;
    }
  }

  static Random _buildRandom() {
    try {
      return Random.secure();
    } on UnsupportedError catch (error) {
      debugPrint('Secure random unavailable on this platform, falling back to pseudo-random generator: $error');
      return Random();
    }
  }

  String _generateCode() {
    final buffer = StringBuffer();
    for (var i = 0; i < _codeLength; i++) {
      final index = _random.nextInt(_alphabet.length);
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }
}
