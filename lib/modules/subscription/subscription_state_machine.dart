enum SubscriptionStatus {
  trial,
  active,
  gracePeriod,
  suspended,
}

class SubscriptionStateMachine {
  static SubscriptionStatus parse(String raw) {
    switch (raw) {
      case 'trial':
        return SubscriptionStatus.trial;
      case 'active':
        return SubscriptionStatus.active;
      case 'grace_period':
        return SubscriptionStatus.gracePeriod;
      case 'suspended':
        return SubscriptionStatus.suspended;
      default:
        throw ArgumentError('Unknown subscription status: $raw');
    }
  }

  static bool canTransition({
    required SubscriptionStatus from,
    required SubscriptionStatus to,
  }) {
    if (from == to) return true;
    switch (from) {
      case SubscriptionStatus.trial:
        return to == SubscriptionStatus.active || to == SubscriptionStatus.gracePeriod;
      case SubscriptionStatus.active:
        return to == SubscriptionStatus.gracePeriod || to == SubscriptionStatus.suspended;
      case SubscriptionStatus.gracePeriod:
        return to == SubscriptionStatus.active || to == SubscriptionStatus.suspended;
      case SubscriptionStatus.suspended:
        return to == SubscriptionStatus.active;
    }
  }

  static void assertAllowed({
    required SubscriptionStatus from,
    required SubscriptionStatus to,
  }) {
    if (!canTransition(from: from, to: to)) {
      throw StateError('Forbidden subscription transition: $from -> $to');
    }
  }
}
