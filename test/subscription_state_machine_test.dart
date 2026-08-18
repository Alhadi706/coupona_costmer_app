import 'package:coupona_app/modules/subscription/subscription_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Allowed transitions match phase-3 state machine', () {
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.trial,
        to: SubscriptionStatus.active,
      ),
      isTrue,
    );
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.trial,
        to: SubscriptionStatus.gracePeriod,
      ),
      isTrue,
    );
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.gracePeriod,
        to: SubscriptionStatus.active,
      ),
      isTrue,
    );
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.gracePeriod,
        to: SubscriptionStatus.suspended,
      ),
      isTrue,
    );
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.suspended,
        to: SubscriptionStatus.active,
      ),
      isTrue,
    );
  });

  test('Forbidden transitions are rejected', () {
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.trial,
        to: SubscriptionStatus.suspended,
      ),
      isFalse,
    );
    expect(
      SubscriptionStateMachine.canTransition(
        from: SubscriptionStatus.suspended,
        to: SubscriptionStatus.trial,
      ),
      isFalse,
    );
    expect(
      () => SubscriptionStateMachine.assertAllowed(
        from: SubscriptionStatus.trial,
        to: SubscriptionStatus.suspended,
      ),
      throwsStateError,
    );
  });
}
