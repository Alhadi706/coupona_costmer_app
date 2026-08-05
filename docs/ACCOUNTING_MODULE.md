# Accounting Module (Wallet + Ledger + Points + Cashback)

## Scope
This module implements the accounting core for authenticated customers:
- Wallet Engine
- Ledger
- Points Engine
- Cashback Engine

## Backend/Data Strategy
Backend is implemented using Firebase Firestore transactions as the source of truth.

Collections used:
- `wallet_accounts/{userId}`
- `point_accounts/{userId}`
- `ledger_entries/{entryId}`

### wallet_accounts document shape
- ownerId: string (required)
- balance: number (required, >= 0)
- currency: string (required, default `SAR`)
- updatedAt: ISO-8601 string UTC (required)

### point_accounts document shape
- ownerId: string (required)
- availablePoints: integer (required, >= 0)
- lifetimePoints: integer (required, >= 0)
- updatedAt: ISO-8601 string UTC (required)

### ledger_entries document shape
- ownerId: string (required)
- type: string enum (`cashbackEarned`, `pointsEarned`, `pointsRedeemed`)
- amount: number (required, may be 0)
- points: integer (required, may be 0)
- reference: string (required)
- createdAt: ISO-8601 string UTC (required)

## Firestore Index Requirement
The ledger stream query requires a composite index:
- ownerId ASC
- createdAt DESC

Index file:
- `firestore.indexes.json`

## Internal Service API Contract
Service class:
- `AccountingService`

Methods:
- `Future<void> ensureAccountingDocuments()`
  - Creates wallet/point documents for authenticated user if missing.

- `Stream<WalletAccount> watchWallet()`
  - Returns wallet stream for authenticated user.

- `Stream<PointAccount> watchPointAccount()`
  - Returns point account stream for authenticated user.

- `Stream<List<LedgerEntry>> watchLedgerEntries({int limit = 50})`
  - Returns latest ledger entries.

- `Future<void> applyCashbackFromPurchase({required double purchaseAmount, required String reference})`
  - Validates amount.
  - Computes cashback and points.
  - Atomically updates wallet + points.
  - Writes ledger entries for cashback and points.

- `Future<void> redeemPoints({required int points, required String reference})`
  - Validates redemption constraints.
  - Atomically deducts points.
  - Writes ledger entry for redemption.

## Business Rules
In `AccountingRules`:
- cashbackRate = 5%
- pointsPerUnit = 1
- amount must be finite and > 0
- points redemption must be > 0 and <= available points

## UI Integration
Screen:
- `WalletEngineScreen`

Capabilities:
- Wallet balance view
- Points account view
- Cashback execution form
- Points redemption form
- Ledger stream view

States handled:
- Loading
- Error
- Empty
- Success feedback (SnackBars)

Navigation entry:
- Added in `SettingsScreen` as "المحفظة والدفتر المحاسبي".

## Error Handling
- Input validation before service calls.
- Firestore transaction exceptions surfaced to UI with explicit error messages.
- No silent failures.

## Tests
- `test/accounting_rules_test.dart`
- `test/accounting_models_test.dart`

Coverage includes:
- Amount normalization
- Cashback/points calculations
- Redemption validation
- Model mapping roundtrip checks
