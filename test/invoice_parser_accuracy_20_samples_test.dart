import 'package:coupona_app/modules/invoice/services/invoice_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sample {
  final String name;
  final String text;
  final double? total;
  final String? invoiceNumber;
  final String? storeName;
  final String? invoiceDate;
  final String category;

  const _Sample({
    required this.name,
    required this.text,
    required this.total,
    required this.invoiceNumber,
    required this.storeName,
    required this.invoiceDate,
    required this.category,
  });
}

bool _closeDouble(double? a, double? b) {
  if (a == null || b == null) return a == b;
  return (a - b).abs() < 0.001;
}

bool _sameText(String? a, String? b) {
  return (a ?? '').trim().toLowerCase() == (b ?? '').trim().toLowerCase();
}

void main() {
  test('Invoice parser accuracy report on 20 OCR-like samples', () {
    const samples = <_Sample>[
      _Sample(
        name: 'A1 grocery ar',
        text: 'اسم المحل: سوبر ماركت ربيع\nرقم الفاتورة: 123456\nالتاريخ: 2025-06-03\nالمجموع: 13 ريال',
        total: 13,
        invoiceNumber: '123456',
        storeName: 'سوبر ماركت ربيع',
        invoiceDate: '2025-06-03',
        category: 'grocery',
      ),
      _Sample(
        name: 'A2 food en',
        text: 'Store: Ocean Restaurant\nInvoice No: INV-90012\nDate: 07/25/2026\nGrand Total: 48.75 SAR',
        total: 48.75,
        invoiceNumber: 'INV-90012',
        storeName: 'Ocean Restaurant',
        invoiceDate: '07/25/2026',
        category: 'food',
      ),
      _Sample(
        name: 'A3 pharmacy en',
        text: 'Merchant: Alshifa Pharmacy\nInvoice Number: RX778899\n2026/07/26\nAmount Due: 92,40 SAR',
        total: 92.40,
        invoiceNumber: 'RX778899',
        storeName: 'Alshifa Pharmacy',
        invoiceDate: '2026/07/26',
        category: 'pharmacy',
      ),
      _Sample(
        name: 'A4 fuel en',
        text: 'Seller: Fast Fuel Station\nINV # FUEL-77661\nDate: 26-07-2026\nTotal 210 SAR',
        total: 210,
        invoiceNumber: 'FUEL-77661',
        storeName: 'Fast Fuel Station',
        invoiceDate: '26-07-2026',
        category: 'transport',
      ),
      _Sample(
        name: 'A5 grocery en',
        text: 'Store: Green Grocery\nInvoice No: 771199\nDate: 2026-07-01\nTOTAL: 88.20',
        total: 88.20,
        invoiceNumber: '771199',
        storeName: 'Green Grocery',
        invoiceDate: '2026-07-01',
        category: 'grocery',
      ),
      _Sample(
        name: 'A6 pharmacy ar',
        text: 'المتجر: صيدلية الشفاء\nفاتورة رقم: 882214\n2026-07-05\nالإجمالي: 57 ريال',
        total: 57,
        invoiceNumber: '882214',
        storeName: 'صيدلية الشفاء',
        invoiceDate: '2026-07-05',
        category: 'pharmacy',
      ),
      _Sample(
        name: 'A7 food ar',
        text: 'اسم المحل: مطعم النكهة\nرقم الفاتورة: 554433\nالتاريخ: 05/07/2026\nالمجموع: 129.5 ريال',
        total: 129.5,
        invoiceNumber: '554433',
        storeName: 'مطعم النكهة',
        invoiceDate: '05/07/2026',
        category: 'food',
      ),
      _Sample(
        name: 'A8 transport ar',
        text: 'المتجر: محطة وقود السريع\nرقم الفاتورة: 663300\n2026/07/06\nالمجموع: 180 ريال',
        total: 180,
        invoiceNumber: '663300',
        storeName: 'محطة وقود السريع',
        invoiceDate: '2026/07/06',
        category: 'transport',
      ),
      _Sample(
        name: 'A9 general en',
        text: 'Store: Home Supplies\nInvoice Number: HS-33210\nDate 2026-07-07\nAmount Due: 74.00 USD',
        total: 74,
        invoiceNumber: 'HS-33210',
        storeName: 'Home Supplies',
        invoiceDate: '2026-07-07',
        category: 'general',
      ),
      _Sample(
        name: 'A10 food coffee',
        text: 'Store: Sunrise Coffee\nInvoice No: CF-99881\nDate: 07-08-2026\nGrand Total: 21.25',
        total: 21.25,
        invoiceNumber: 'CF-99881',
        storeName: 'Sunrise Coffee',
        invoiceDate: '07-08-2026',
        category: 'food',
      ),
      _Sample(
        name: 'A11 grocery noisy',
        text: 'Store : Mega Super Market\nINV. # 919191\nDate: 2026/7/9\nTotal : 301 SAR',
        total: 301,
        invoiceNumber: '919191',
        storeName: 'Mega Super Market',
        invoiceDate: '2026/7/9',
        category: 'grocery',
      ),
      _Sample(
        name: 'A12 pharmacy mixed',
        text: 'Seller: CARE medicine plus\ninvoice number: MED-4488\n09/07/2026\namount due 45.5 sar',
        total: 45.5,
        invoiceNumber: 'MED-4488',
        storeName: 'CARE medicine plus',
        invoiceDate: '09/07/2026',
        category: 'pharmacy',
      ),
      _Sample(
        name: 'A13 transport en',
        text: 'Merchant: City Gas Station\nInvoice No: GAS-11223\nDate: 2026-07-10\nTotal: 95.8 SAR',
        total: 95.8,
        invoiceNumber: 'GAS-11223',
        storeName: 'City Gas Station',
        invoiceDate: '2026-07-10',
        category: 'transport',
      ),
      _Sample(
        name: 'A14 food en',
        text: 'Store: Family Cafe\nInvoice No: FC-7712\nDate: 10/07/2026\nTotal: 64 SAR',
        total: 64,
        invoiceNumber: 'FC-7712',
        storeName: 'Family Cafe',
        invoiceDate: '10/07/2026',
        category: 'food',
      ),
      _Sample(
        name: 'A15 ar general',
        text: 'اسم المحل: متجر اللوازم\nرقم الفاتورة: 7712345\nالتاريخ: 2026-07-11\nالمجموع: 39.99 ريال',
        total: 39.99,
        invoiceNumber: '7712345',
        storeName: 'متجر اللوازم',
        invoiceDate: '2026-07-11',
        category: 'general',
      ),
      _Sample(
        name: 'A16 grocery en simple',
        text: 'Store: Daily Grocery\nInvoice No: DG-50009\nDate: 2026-07-12\nGrand Total: 112.00',
        total: 112,
        invoiceNumber: 'DG-50009',
        storeName: 'Daily Grocery',
        invoiceDate: '2026-07-12',
        category: 'grocery',
      ),
      _Sample(
        name: 'A17 pharmacy ar',
        text: 'اسم المحل: صيدلية النخبة\nرقم الفاتورة: 118822\n12/07/2026\nالمجموع: 149 ريال',
        total: 149,
        invoiceNumber: '118822',
        storeName: 'صيدلية النخبة',
        invoiceDate: '12/07/2026',
        category: 'pharmacy',
      ),
      _Sample(
        name: 'A18 fuel station en',
        text: 'Store: Highway Fuel\nInvoice Number: HW-32100\nDate: 2026-07-13\nAmount Due: 266.70',
        total: 266.70,
        invoiceNumber: 'HW-32100',
        storeName: 'Highway Fuel',
        invoiceDate: '2026-07-13',
        category: 'transport',
      ),
      _Sample(
        name: 'A19 food restaurant ar',
        text: 'المتجر: مطعم الواحة\nرقم الفاتورة: 933001\n13-07-2026\nالإجمالي: 82 ريال',
        total: 82,
        invoiceNumber: '933001',
        storeName: 'مطعم الواحة',
        invoiceDate: '13-07-2026',
        category: 'food',
      ),
      _Sample(
        name: 'A20 general en',
        text: 'Merchant: Tech Market\nInvoice No: TM-77991\nDate: 2026/07/14\nTotal: 499.90 USD',
        total: 499.90,
        invoiceNumber: 'TM-77991',
        storeName: 'Tech Market',
        invoiceDate: '2026/07/14',
        category: 'general',
      ),
    ];

    var totalChecks = 0;
    var passedChecks = 0;

    var totalPass = 0;
    var invoicePass = 0;
    var storePass = 0;
    var datePass = 0;
    var categoryPass = 0;

    for (final s in samples) {
      final parsed = InvoiceTextParser.parse(s.text);
      final totalOk = _closeDouble(parsed.total, s.total);
      final invoiceOk = _sameText(parsed.invoiceNumber, s.invoiceNumber);
      final storeOk = _sameText(parsed.storeName, s.storeName);
      final dateOk = _sameText(parsed.invoiceDate, s.invoiceDate);
      final categoryOk = _sameText(parsed.category, s.category);

      if (totalOk) totalPass++;
      if (invoiceOk) invoicePass++;
      if (storeOk) storePass++;
      if (dateOk) datePass++;
      if (categoryOk) categoryPass++;

      final checks = [totalOk, invoiceOk, storeOk, dateOk, categoryOk];
      for (final ok in checks) {
        totalChecks++;
        if (ok) passedChecks++;
      }
    }

    final n = samples.length.toDouble();
    final totalAccuracy = totalPass / n;
    final invoiceAccuracy = invoicePass / n;
    final storeAccuracy = storePass / n;
    final dateAccuracy = datePass / n;
    final categoryAccuracy = categoryPass / n;
    final overallAccuracy = passedChecks / totalChecks;

    final report = StringBuffer()
      ..writeln('Invoice parser accuracy (20 samples):')
      ..writeln('total: ${(totalAccuracy * 100).toStringAsFixed(2)}% ($totalPass/20)')
      ..writeln('invoiceNumber: ${(invoiceAccuracy * 100).toStringAsFixed(2)}% ($invoicePass/20)')
      ..writeln('storeName: ${(storeAccuracy * 100).toStringAsFixed(2)}% ($storePass/20)')
      ..writeln('invoiceDate: ${(dateAccuracy * 100).toStringAsFixed(2)}% ($datePass/20)')
      ..writeln('category: ${(categoryAccuracy * 100).toStringAsFixed(2)}% ($categoryPass/20)')
      ..writeln('overall field accuracy: ${(overallAccuracy * 100).toStringAsFixed(2)}% ($passedChecks/$totalChecks)');

    // ignore: avoid_print
    print(report.toString());

    expect(totalAccuracy, greaterThanOrEqualTo(0.90));
    expect(invoiceAccuracy, greaterThanOrEqualTo(0.90));
    expect(storeAccuracy, greaterThanOrEqualTo(0.90));
    expect(dateAccuracy, greaterThanOrEqualTo(0.90));
    expect(categoryAccuracy, greaterThanOrEqualTo(0.90));
    expect(overallAccuracy, greaterThanOrEqualTo(0.92));
  });
}