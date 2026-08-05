enum CouponLifecycleStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  active,
  redeemed,
  expired,
  archived,
}

class CouponLifecycleRules {
  CouponLifecycleRules._();

  static const Map<CouponLifecycleStatus, Set<CouponLifecycleStatus>> _allowedTransitions =
      <CouponLifecycleStatus, Set<CouponLifecycleStatus>>{
    CouponLifecycleStatus.draft: <CouponLifecycleStatus>{
      CouponLifecycleStatus.pendingReview,
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.pendingReview: <CouponLifecycleStatus>{
      CouponLifecycleStatus.approved,
      CouponLifecycleStatus.rejected,
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.approved: <CouponLifecycleStatus>{
      CouponLifecycleStatus.active,
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.rejected: <CouponLifecycleStatus>{
      CouponLifecycleStatus.pendingReview,
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.active: <CouponLifecycleStatus>{
      CouponLifecycleStatus.redeemed,
      CouponLifecycleStatus.expired,
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.redeemed: <CouponLifecycleStatus>{
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.expired: <CouponLifecycleStatus>{
      CouponLifecycleStatus.archived,
    },
    CouponLifecycleStatus.archived: <CouponLifecycleStatus>{},
  };

  static bool canTransition({
    required CouponLifecycleStatus from,
    required CouponLifecycleStatus to,
  }) {
    if (from == to) {
      return true;
    }
    final Set<CouponLifecycleStatus> allowed =
        _allowedTransitions[from] ?? <CouponLifecycleStatus>{};
    return allowed.contains(to);
  }

  static CouponLifecycleStatus parseStatus(String? value) {
    switch (value) {
      case 'draft':
        return CouponLifecycleStatus.draft;
      case 'pending_review':
        return CouponLifecycleStatus.pendingReview;
      case 'approved':
        return CouponLifecycleStatus.approved;
      case 'rejected':
        return CouponLifecycleStatus.rejected;
      case 'active':
        return CouponLifecycleStatus.active;
      case 'redeemed':
        return CouponLifecycleStatus.redeemed;
      case 'expired':
        return CouponLifecycleStatus.expired;
      case 'archived':
        return CouponLifecycleStatus.archived;
      default:
        return CouponLifecycleStatus.draft;
    }
  }

  static String toStorageValue(CouponLifecycleStatus status) {
    switch (status) {
      case CouponLifecycleStatus.draft:
        return 'draft';
      case CouponLifecycleStatus.pendingReview:
        return 'pending_review';
      case CouponLifecycleStatus.approved:
        return 'approved';
      case CouponLifecycleStatus.rejected:
        return 'rejected';
      case CouponLifecycleStatus.active:
        return 'active';
      case CouponLifecycleStatus.redeemed:
        return 'redeemed';
      case CouponLifecycleStatus.expired:
        return 'expired';
      case CouponLifecycleStatus.archived:
        return 'archived';
    }
  }
}
