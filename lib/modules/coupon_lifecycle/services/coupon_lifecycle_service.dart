import '../../../services/company_server_service.dart';
import '../coupon_lifecycle_rules.dart';
import '../models/coupon_lifecycle_record.dart';

class CouponLifecycleService {
  Stream<CouponLifecycleRecord?> watchOfferLifecycle(String offerId) {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => CompanyServerService.getOfferLifecycle(offerId))
        .startWithFuture(CompanyServerService.getOfferLifecycle(offerId))
        .map((data) {
      if (data == null) return null;
      return CouponLifecycleRecord.fromMap(offerId: offerId, map: data);
    });
  }

  Future<void> ensureLifecycleDefaults(String offerId) async {
    await CompanyServerService.ensureOfferLifecycleDefaults(offerId);
  }

  Future<void> transitionOffer({
    required String offerId,
    required CouponLifecycleStatus targetStatus,
    String? reason,
  }) async {
    await CompanyServerService.transitionOfferLifecycle(
      offerId: offerId,
      targetStatus: CouponLifecycleRules.toStorageValue(targetStatus),
      reason: reason,
    );
  }

  Future<void> syncTemporalStatus(String offerId) async {
    await CompanyServerService.syncOfferTemporalStatus(offerId);
  }
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
