import 'package:coupona_app/modules/invoice/services/invoice_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExpectedInvoice {
  final String name;
  final String text;
  final double total;
  final String invoiceNumber;
  final String? orderNumber;
  final String storeName;
  final String invoiceDate;
  final String category;

  const _ExpectedInvoice({
    required this.name,
    required this.text,
    required this.total,
    required this.invoiceNumber,
    required this.orderNumber,
    required this.storeName,
    required this.invoiceDate,
    required this.category,
  });
}

void main() {
  test('Invoice parser extracts key fields accurately from sample invoices', () {
    const samples = <_ExpectedInvoice>[
      _ExpectedInvoice(
        name: 'Arabic grocery invoice',
        text: '''
اسم المحل: سوبر ماركت ربيع
رقم الفاتورة: 123456
التاريخ: 2025-06-03
المجموع: 13 ريال
''',
        total: 13,
        invoiceNumber: '123456',
        orderNumber: null,
        storeName: 'سوبر ماركت ربيع',
        invoiceDate: '2025-06-03',
        category: 'grocery',
      ),
      _ExpectedInvoice(
        name: 'English restaurant invoice',
        text: '''
Store: Ocean Restaurant
Invoice No: INV-90012
Date: 07/25/2026
Grand Total: 48.75 SAR
''',
        total: 48.75,
        invoiceNumber: 'INV-90012',
        orderNumber: null,
        storeName: 'Ocean Restaurant',
        invoiceDate: '07/25/2026',
        category: 'food',
      ),
      _ExpectedInvoice(
        name: 'Pharmacy invoice mixed format',
        text: '''
Merchant: Alshifa Pharmacy
Invoice Number: RX778899
2026/07/26
Amount Due: 92,40 SAR
''',
        total: 92.40,
        invoiceNumber: 'RX778899',
        orderNumber: null,
        storeName: 'Alshifa Pharmacy',
        invoiceDate: '2026/07/26',
        category: 'pharmacy',
      ),
      _ExpectedInvoice(
        name: 'Fuel station invoice',
        text: '''
Seller: Fast Fuel Station
INV # FUEL-77661
Date: 26-07-2026
Total 210 SAR
''',
        total: 210,
        invoiceNumber: 'FUEL-77661',
        orderNumber: null,
        storeName: 'Fast Fuel Station',
        invoiceDate: '26-07-2026',
        category: 'transport',
      ),
    ];

    var totalChecks = 0;
    var passedChecks = 0;

    for (final sample in samples) {
      final parsed = InvoiceTextParser.parse(sample.text);
      final checks = <bool>[
        parsed.total != null && (parsed.total! - sample.total).abs() < 0.001,
        parsed.invoiceNumber == sample.invoiceNumber,
        parsed.orderNumber == sample.orderNumber,
        parsed.storeName == sample.storeName,
        parsed.invoiceDate == sample.invoiceDate,
        parsed.category == sample.category,
      ];

      for (var i = 0; i < checks.length; i++) {
        totalChecks++;
        if (checks[i]) {
          passedChecks++;
        }
      }

      expect(
        checks.every((ok) => ok),
        isTrue,
        reason: 'Failed sample: ${sample.name}',
      );
    }

    final accuracy = passedChecks / totalChecks;
    expect(
      accuracy,
      greaterThanOrEqualTo(0.95),
      reason: 'Expected parser extraction accuracy >= 95%, got ${(accuracy * 100).toStringAsFixed(2)}%',
    );
  });
}