import 'package:flutter_test/flutter_test.dart';

import 'package:coupona_app/modules/accounting/models/ledger_entry.dart';
import 'package:coupona_app/modules/accounting/models/point_account.dart';
import 'package:coupona_app/modules/accounting/models/wallet_account.dart';

void main() {
  test('WalletAccount map roundtrip', () {
    final wallet = WalletAccount(
      ownerId: 'u1',
      balance: 15.5,
      currency: 'SAR',
      updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

    final parsed = WalletAccount.fromMap(wallet.toMap());
    expect(parsed.ownerId, 'u1');
    expect(parsed.balance, 15.5);
    expect(parsed.currency, 'SAR');
  });

  test('PointAccount map roundtrip', () {
    final points = PointAccount(
      ownerId: 'u1',
      availablePoints: 100,
      lifetimePoints: 150,
      updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

    final parsed = PointAccount.fromMap(points.toMap());
    expect(parsed.availablePoints, 100);
    expect(parsed.lifetimePoints, 150);
  });

  test('LedgerEntry map roundtrip', () {
    final entry = LedgerEntry(
      ownerId: 'u1',
      type: LedgerEntryType.cashbackEarned,
      amount: 12.0,
      points: 0,
      reference: 'INV-101',
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

    final parsed = LedgerEntry.fromMap(entry.toMap());
    expect(parsed.type, LedgerEntryType.cashbackEarned);
    expect(parsed.amount, 12.0);
    expect(parsed.reference, 'INV-101');
  });
}
