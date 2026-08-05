import 'package:coupona_app/modules/invoice/services/invoice_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Parses restaurant receipt with clear total and order number', () {
    const text = '''
المطعم الشامي
09/08/2025
طلبية رقم / 229 /
الكمية السعر الاجمالي
2 22.00 44.00
المجموع : 44.00
''';

    final parsed = InvoiceTextParser.parse(text);
    expect(parsed.storeName, 'المطعم الشامي');
    expect(parsed.invoiceNumber, isNull);
    expect(parsed.orderNumber, '229');
    expect(parsed.total, 44.00);
    expect(parsed.category, 'food');
  });

  test('Parses receipt where total appears as boxed value', () {
    const text = '''
سندوتشات نسيم
طرابلس قصر بن غشير
طلب خارجي
11:3 26-07-2025
رقم الفاتورة 142035
رقم الطلب 80
الإجمالي 41.00 DL
''';

    final parsed = InvoiceTextParser.parse(text);
    expect(parsed.storeName, 'سندوتشات نسيم');
    expect(parsed.invoiceNumber, '142035');
    expect(parsed.orderNumber, '80');
    expect(parsed.total, 41.00);
    expect(parsed.category, 'food');
  });

  test('Parses item-table receipt and detects bottom total', () {
    const text = '''
شـنـابو
2025-05-17
رقم الطلب: 308
نوع الطلب: طلب خارجي
اسم الصنف الكمية السعر الإجمالي
شاورما دجاج بالجبنة 1 9.00 9
صحن بطاطا وسط 1 7.00 7
إجمالي الفاتورة 16 دل
''';

    final parsed = InvoiceTextParser.parse(text);
    expect(parsed.storeName, 'شـنـابو');
    expect(parsed.invoiceNumber, isNull);
    expect(parsed.orderNumber, '308');
    expect(parsed.total, 16);
    expect(parsed.category, 'food');
  });
}