import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'supabase_invoice_service.dart';

class DemoSeedService {
  /// يزرع بيانات تجريبية مرتبطة برمز تاجر واحد عبر عدة مصادر (Firestore + Supabase)
  static Future<void> seedMerchantDemo(String merchantCode) async {
    final fs = FirebaseFirestore.instance;

    // 1) متاجر مع إحداثيات ومعلومات أساسية
    await fs.collection('stores').add({
      'name': 'سوبرماركت المدينة - فرع السرايا',
      'merchant_code': merchantCode,
      'brand': 'كوكاكولا',
      'location': const GeoPoint(32.8872, 13.1913), // طرابلس كمثال
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2) عروض مرتبطة بالرمز
    final offersBatch = fs.batch();
    final offersRef = fs.collection('offers');
    final offerDocs = [
      {
        'id': 'O-${merchantCode}-1',
        'title': 'خصم 20% على مشروبات مختارة',
        'description': 'العرض ساري حتى نهاية الشهر',
        'merchant_code': merchantCode,
        'brand': 'كوكاكولا',
        'valid_until': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
  'createdAt': DateTime.now().toIso8601String(),
  'location': '32.8872,13.1913',
      },
      {
        'id': 'O-${merchantCode}-2',
        'title': 'اشترِ 2 واحصل على 1 مجانا',
        'description': 'خاص بعبوات 330 مل',
        'merchant_code': merchantCode,
        'brand': 'كوكاكولا',
        'valid_until': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
  'createdAt': DateTime.now().toIso8601String(),
  'location': '32.8850,13.1900',
      },
      {
        'id': 'O-${merchantCode}-3',
        'title': 'كاش باك 5% على كل فاتورة',
        'description': 'تطبق الشروط والأحكام',
        'merchant_code': merchantCode,
        'brand': 'كوكاكولا',
        'valid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
  'createdAt': DateTime.now().toIso8601String(),
  'location': '32.8890,13.1950',
      },
    ];
    for (final data in offerDocs) {
      offersBatch.set(offersRef.doc(), data);
    }
    await offersBatch.commit();

    // 3) مجموعة في المجتمع + رسالة أولية
    final groupRef = await fs.collection('groups').add({
      'name': 'مجموعة ${merchantCode} | عروض كوكاكولا',
      'desc': 'نقاشات وتجارب حول العروض وجودة المنتجات',
      'members': 12,
      'merchant_code': merchantCode,
      'created_at': DateTime.now().toIso8601String(),
    });
    await groupRef.collection('messages').add({
      'text': 'مرحبا بالجميع! شاركونا أفضل عرض وجدتموه اليوم 🎉',
      'sender': 'مشرف',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 4) بلاغ تجريبي (اختياري) لربط التقارير بالتاجر
    await fs.collection('reports').add({
      'type': 'جودة',
      'storeName': 'سوبرماركت المدينة - فرع السرايا',
      'description': 'ملاحظة على تخزين العبوات في الواجهة الشمسية',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'new',
      'merchant_code': merchantCode,
    });

    // 5) فواتير تجريبية في Supabase لقياس الارتباط
    final rnd = Random();
    for (int i = 1; i <= 5; i++) {
      final total = (rnd.nextInt(1500) + 500) / 10.0; // 50.0 .. 200.0
      await SupabaseInvoiceService.addInvoice(
        invoiceNumber: 'INV-$merchantCode-$i',
        storeName: 'سوبرماركت المدينة',
        date: DateTime.now().subtract(Duration(days: i)),
        products: [
          {
            'name': 'كوكاكولا 330ml',
            'quantity': 2,
            'unit_price': total / 2,
            'total_price': total,
          }
        ],
        total: total,
        userId: 'test_user', // TODO: استبدالها بمعرّف المستخدم الحقيقي
        merchantId: merchantCode, // مؤقتًا حتى توحيد المخطط إلى UUID
        uniqueHash: 'seed-$merchantCode-$i',
        merchantCode: merchantCode,
      );
    }
  }

  /// يحسب إحصائيات سريعة للتاجر عبر المصادر المتاحة
  static Future<Map<String, dynamic>> getMerchantStats(String merchantCode) async {
    final fs = FirebaseFirestore.instance;

    // Firestore counts
    final offersCount = (await fs.collection('offers').where('merchant_code', isEqualTo: merchantCode).get()).docs.length;
    final storesCount = (await fs.collection('stores').where('merchant_code', isEqualTo: merchantCode).get()).docs.length;
    final groupsCount = (await fs.collection('groups').where('merchant_code', isEqualTo: merchantCode).get()).docs.length;
    final reportsCount = (await fs.collection('reports').where('merchant_code', isEqualTo: merchantCode).get()).docs.length;

    // Supabase invoices
    List<Map<String, dynamic>> invoices = <Map<String, dynamic>>[];
    try {
      final rows = await SupabaseService.client
          .from('invoices')
          .select('*')
          .eq('merchant_code', merchantCode)
          .limit(1000);
      if (rows is List) {
        invoices = rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      // في حال عدم وجود العمود merchant_code أو أي فشل، نتجنب الكسر
      invoices = <Map<String, dynamic>>[];
    }
    final invoicesCount = invoices.length;
    final invoicesTotal = invoices.fold<double>(0.0, (sum, r) => sum + ((r['total'] ?? 0) as num).toDouble());

    return {
      'offers': offersCount,
      'stores': storesCount,
      'groups': groupsCount,
      'reports': reportsCount,
      'invoices': invoicesCount,
      'invoices_total': invoicesTotal,
    };
  }
}

/// دالة مساعدة (اختيارية) لتحديث جميع العروض القديمة التي لا تحتوي createdAt
/// استدعها يدويًا مرة واحدة إذا لاحظت فرقًا في العدادات
Future<void> backfillOffersCreatedAt() async {
  final fs = FirebaseFirestore.instance;
  final snap = await fs.collection('offers').get();
  final nowIso = DateTime.now().toIso8601String();
  for (final doc in snap.docs) {
    final data = doc.data();
    if (!data.containsKey('createdAt')) {
      await doc.reference.update({'createdAt': nowIso});
    }
  }
}
