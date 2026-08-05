import 'package:flutter_test/flutter_test.dart';

import 'package:coupona_app/modules/coupon_lifecycle/coupon_lifecycle_rules.dart';

void main() {
  group('CouponLifecycleRules', () {
    test('draft can move to pending review', () {
      expect(
        CouponLifecycleRules.canTransition(
          from: CouponLifecycleStatus.draft,
          to: CouponLifecycleStatus.pendingReview,
        ),
        isTrue,
      );
    });

    test('pending review cannot move directly to redeemed', () {
      expect(
        CouponLifecycleRules.canTransition(
          from: CouponLifecycleStatus.pendingReview,
          to: CouponLifecycleStatus.redeemed,
        ),
        isFalse,
      );
    });

    test('parse and storage mapping are stable', () {
      final status = CouponLifecycleRules.parseStatus('pending_review');
      expect(status, CouponLifecycleStatus.pendingReview);
      expect(CouponLifecycleRules.toStorageValue(status), 'pending_review');
    });
  });
}
