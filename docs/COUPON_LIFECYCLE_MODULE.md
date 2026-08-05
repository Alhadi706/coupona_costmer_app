# Coupon Lifecycle Module

## Scope

The Coupon Lifecycle Module adds a deterministic state machine for offer documents in Firestore. It introduces explicit lifecycle states and guarded transitions.

## Lifecycle States

- draft
- pending_review
- approved
- rejected
- active
- redeemed
- expired
- archived

## Transition Rules

- draft -> pending_review, archived
- pending_review -> approved, rejected, archived
- approved -> active, archived
- rejected -> pending_review, archived
- active -> redeemed, expired, archived
- redeemed -> archived
- expired -> archived

## Firestore Fields

The module writes these fields on offer documents:

- lifecycleStatus
- lifecycleUpdatedAt
- lifecycleReason
- publishedAt
- redeemedAt
- expiredAt
- archivedAt

## Service API

Main service file: lib/modules/coupon_lifecycle/services/coupon_lifecycle_service.dart

- ensureLifecycleDefaults(offerId)
- watchOfferLifecycle(offerId)
- transitionOffer(offerId, targetStatus, reason)
- syncTemporalStatus(offerId)

## UI

A utility admin screen is provided:

- lib/screens/coupon_lifecycle_screen.dart

It allows binding an offer ID, viewing current state, and executing valid transitions.

## Tests

- test/coupon_lifecycle_rules_test.dart
- test/coupon_lifecycle_model_test.dart
