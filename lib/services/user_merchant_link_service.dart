import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/invoice.dart';
import '../models/merchant_point_rules.dart';
import 'firebase_service.dart';
import 'firestore/community_repository.dart';
import 'firestore/invoice_repository.dart';
import 'firestore/merchant_point_rules_repository.dart';
import 'firestore/merchant_customer_room_repository.dart';
import 'firestore/merchant_repository.dart';
import 'merchant_code_service.dart';

/// Utilities for maintaining relationships between merchants and customers.
class UserMerchantLinkService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final MerchantCodeService _codeService = MerchantCodeService();
  static final InvoiceRepository _invoiceRepository = InvoiceRepository();
  static final MerchantCustomerRoomRepository _roomRepository = MerchantCustomerRoomRepository();
  static final MerchantRepository _merchantRepository = MerchantRepository();
  static final MerchantPointRulesRepository _pointRulesRepository = MerchantPointRulesRepository();
  static final CommunityRepository _communityRepository = CommunityRepository();

  /// Persist a scanned invoice into Firestore and return a status key.
  static Future<String> sendDataToLinkAgent({
    required String merchantCode,
    required Map<String, dynamic> invoicePayload,
  }) async {
    final normalizedCode = _codeService.normalizeCode(merchantCode);
    if (normalizedCode.isEmpty) {
      debugPrint('Invoice link aborted: empty merchant code');
      return 'invoice_link_missing_code';
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('Invoice link aborted: user not authenticated');
      return 'invoice_link_failed_not_logged_in';
    }

    String? merchantId;
    try {
      merchantId = await _codeService.findMerchantIdByCode(normalizedCode);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Merchant code lookup failed: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      return 'invoice_link_failed';
    }

    if (merchantId == null) {
      debugPrint('Invoice link aborted: unknown merchant code $normalizedCode');
      return 'invoice_link_failed_unknown_code';
    }

    final cleanPayload = Map<String, dynamic>.from(invoicePayload)
      ..removeWhere((key, value) => value == null);

    final totalAmount = (cleanPayload['total_amount'] as num?)?.toDouble() ?? 0;
    final invoiceNumber = cleanPayload['invoice_number']?.toString() ?? 'OCR-${DateTime.now().millisecondsSinceEpoch}';
    final rawText = cleanPayload['raw_text']?.toString();

    try {
      debugPrint('Linking invoice for merchant=$merchantId customer=${user.uid}');
      debugPrint('Creating invoice document...');

      final invoiceItems = _extractInvoiceItems(cleanPayload['items']);
      final merchant = await _merchantRepository.fetchMerchant(merchantId);
      final MerchantPointRules? pointRules = await _safeFetchPointRules(merchantId);
      final double merchantPointsEarned = _calculateMerchantPoints(
        pointRules: pointRules,
        fallbackMultiplier: merchant?.pointsPerCurrency ?? 0,
        totalAmount: totalAmount,
        items: invoiceItems,
      );
      final brandBreakdown = _extractBrandBreakdown(cleanPayload['brand_points']);
      for (final item in invoiceItems) {
        final brandId = item.brandId;
        if ((brandId ?? '').isEmpty || item.points <= 0) continue;
        brandBreakdown[brandId!] = (brandBreakdown[brandId] ?? 0) + item.points;
      }

      final docRef = await _invoiceRepository.createInvoice(
        merchantId: merchantId,
        customerId: user.uid,
        invoiceNumber: invoiceNumber,
        totalAmount: totalAmount,
        items: invoiceItems,
        status: 'pending',
        ocrText: rawText,
        merchantCode: normalizedCode,
        merchantPointsOverride: merchantPointsEarned > 0 ? merchantPointsEarned : null,
        brandPointBreakdown: brandBreakdown,
      );

      debugPrint('Invoice created with id=${docRef.id}');
      debugPrint('Writing invoice link...');

      await FirebaseService.firestore.collection('invoiceLinks').doc(docRef.id).set({
        'invoiceId': docRef.id,
        'merchantId': merchantId,
        'merchantCode': normalizedCode,
        'customerId': user.uid,
        'payload': cleanPayload,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Invoice link stored. Ensuring room...');

      await _roomRepository.ensureRoomExists(merchantId: merchantId, customerId: user.uid);
      await _communityRepository.addMemberToMerchantRooms(
        merchantId: merchantId,
        memberId: user.uid,
      );

      debugPrint('Room ensured successfully.');

      return 'invoice_link_success';
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Invoice link failed: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      return 'invoice_link_failed';
    } catch (error, stackTrace) {
      debugPrint('Invoice link unexpected failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 'invoice_link_failed';
    }
  }

  static List<InvoiceItem> _extractInvoiceItems(dynamic rawItems) {
    if (rawItems is! List) return const <InvoiceItem>[];
    final List<InvoiceItem> items = [];
    for (final entry in rawItems) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      items.add(InvoiceItem(
        productId: map['productId']?.toString() ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        price: (map['price'] as num?)?.toDouble() ?? 0,
        points: (map['points'] as num?)?.toDouble() ?? 0,
        brandId: map['brandId']?.toString(),
      ));
    }
    return items;
  }

  static Future<MerchantPointRules?> _safeFetchPointRules(String merchantId) async {
    try {
      return await _pointRulesRepository.fetchRules(merchantId);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Point rules fetch failed: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    } catch (error, stackTrace) {
      debugPrint('Point rules fetch unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static double _calculateMerchantPoints({
    required MerchantPointRules? pointRules,
    required double fallbackMultiplier,
    required double totalAmount,
    required List<InvoiceItem> items,
  }) {
    double points = 0;
    if (pointRules != null) {
      // حسب عدد المنتجات
      if (pointRules.enablePerItem && pointRules.pointsPerItem > 0) {
        final totalUnits = items.fold<int>(0, (runningTotal, item) => runningTotal + (item.quantity > 0 ? item.quantity : 0));
        if (totalUnits > 0) {
          points += totalUnits * pointRules.pointsPerItem;
        }
      }
      // حسب قيمة الفاتورة
      if (pointRules.enablePerAmount && pointRules.amountStep > 0 && pointRules.pointsPerAmountStep > 0) {
        final steps = (totalAmount / pointRules.amountStep).floor();
        if (steps > 0) {
          points += steps * pointRules.pointsPerAmountStep;
        }
      }
      // حسب الأصناف (boosts)
      if (pointRules.enableBoosts && pointRules.boosts.isNotEmpty) {
        final boostMap = <String, double>{
          for (final boost in pointRules.boosts)
            if (boost.productId.isNotEmpty && boost.extraPoints > 0) boost.productId: boost.extraPoints,
        };
        if (boostMap.isNotEmpty) {
          for (final item in items) {
            final boost = boostMap[item.productId];
            if (boost == null) continue;
            final qty = item.quantity > 0 ? item.quantity : 0;
            if (qty <= 0) continue;
            points += boost * qty;
          }
        }
      }
    }

    if (points <= 0 && fallbackMultiplier > 0 && totalAmount > 0) {
      points = totalAmount * fallbackMultiplier;
    }
    return points;
  }

  static Map<String, double> _extractBrandBreakdown(dynamic rawBreakdown) {
    if (rawBreakdown is! Map) return <String, double>{};
    final Map<String, double> result = {};
    rawBreakdown.forEach((key, value) {
      if (key == null) return;
      final brandId = key.toString();
      if (brandId.isEmpty) return;
      final points = (value as num?)?.toDouble() ?? 0;
      if (points <= 0) return;
      result[brandId] = points;
    });
    return result;
  }

  static Future<List<String>> fetchDistinctCustomerIdsForMerchant(String merchantId) async {
    final snapshot = await FirebaseService.firestore
        .collection('invoiceLinks')
        .where('merchantId', isEqualTo: merchantId)
        .get();
    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final userId = doc.data()['customerId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        ids.add(userId);
      }
    }
    return ids.toList();
  }

  static Future<List<String>> fetchDistinctMerchantIdsForUser(String userId) async {
    final snapshot = await FirebaseService.firestore
        .collection('invoiceLinks')
        .where('customerId', isEqualTo: userId)
        .get();
    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final merchantId = doc.data()['merchantId']?.toString();
      if (merchantId != null && merchantId.isNotEmpty) {
        ids.add(merchantId);
      }
    }
    return ids.toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMerchantsByIds(
    List<String> merchantIds, {
    String collectionName = 'merchants',
  }) async {
    if (merchantIds.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (final id in merchantIds) {
      final doc = await FirebaseService.firestore.collection(collectionName).doc(id).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          continue;
        }
        final map = Map<String, dynamic>.from(data);
        map['id'] = doc.id;
        results.add(map);
      }
    }
    return results;
  }

  static Future<List<Map<String, dynamic>>> fetchCustomerProfiles(
    List<String> customerIds, {
    String collectionName = 'profiles',
  }) async {
    if (customerIds.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (final id in customerIds) {
      final doc = await FirebaseService.firestore.collection(collectionName).doc(id).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          continue;
        }
        final map = Map<String, dynamic>.from(data);
        map['id'] = doc.id;
        results.add(map);
      }
    }
    return results;
  }

}
