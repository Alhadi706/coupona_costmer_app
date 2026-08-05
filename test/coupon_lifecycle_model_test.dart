import 'package:flutter_test/flutter_test.dart';

import 'package:coupona_app/modules/coupon_lifecycle/coupon_lifecycle_rules.dart';
import 'package:coupona_app/modules/coupon_lifecycle/models/coupon_lifecycle_record.dart';

void main() {
  test('CouponLifecycleRecord map conversion', () {
    final record = CouponLifecycleRecord(
      offerId: 'offer-1',
      status: CouponLifecycleStatus.active,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
      lastReason: 'approved_and_started',
    );

    final map = record.toMap();
    final parsed = CouponLifecycleRecord.fromMap(
      offerId: 'offer-1',
      map: <String, dynamic>{
        ...map,
        'createdAt': '2026-01-01T00:00:00Z',
      },
    );

    expect(parsed.offerId, 'offer-1');
    expect(parsed.status, CouponLifecycleStatus.active);
    expect(parsed.lastReason, 'approved_and_started');
  });
}
