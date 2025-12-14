## Merchant Firestore Integration Plan

### Scope
- Apply to all merchant-facing screens (signup/login/dashboard, products, offers/rewards, invoices, sales analytics, community, notifications, cashiers).
- Customer, brand, and admin apps retain current behavior for now.

### Data Model Recap
Collections defined in the product brief:
1. `merchants/{merchantId}` – profile + settings (categories array, location, active flag, createdAt/updatedAt).
2. `products/{productId}` – references `merchantId`, contains price, category, brandId, `pointsPerUnit`, `isActive`.
3. `invoices/{invoiceId}` – `merchantId`, `customerId`, `invoiceNumber`, `totalAmount`, `items[]`, `status`, `ocrText`, timestamps. **No image storage**: OCR service persists text + metadata only.
4. `rewards/{rewardId}` – offers linked to merchant, with `type`, `requiredPoints`, dates, `claimedCount`.
5. `customers/{customerId}` – basic profile + `merchantPoints` map for per-merchant totals.
6. `cashiers/{cashierId}` – ties a user to a merchant with permission array.
7. `communities/{communityId}` – merchant rooms + `messages` sub-collection.
8. `notifications/{notificationId}` – targeted to `userId` (merchant or staff).

### Derived Rules/Assumptions
- Invoice OCR: upload image → serverless OCR → discard binary, persist structured fields + `ocrText` only.
- Points: computed immediately when invoice saved. Use `pointsPerUnit` per product; fallback to merchant default multiplier stored in `merchants.pointsPerCurrency` (new optional field).
- Merchants authenticate via Firebase Auth; UID equals `merchantId` for now. Cashiers will authenticate as regular users with `merchantId` custom claim or field on `cashiers` doc.
- Brand/Admin flows will read same collections later.

### Firestore Security (draft)
- `merchants/{merchantId}` readable/writable only by same UID.
- `products`, `rewards`, `invoices`, `cashiers`: allow read/write if `request.auth.uid == resource.data.merchantId` (or `request.resource.data` for creates).
- `customers`: merchants can read customers that have entries in `merchantPoints[merchantId]`; writes limited to Cloud Functions to avoid tampering.
- `communities/{communityId}`: membership enforced by `members` array; messages sub-collection inherits rules.
- `notifications`: readable by `userId` == auth UID; writes done by server/Functions.

### Services To Implement
| Service | Responsibilities |
| --- | --- |
| `FirebaseAuthService` | Sign-in/out merchants & cashiers, expose `currentMerchantId`. |
| `MerchantRepository` | CRUD for `merchants` doc + helper to update `updatedAt`. |
| `ProductRepository` | Query products by merchant, CRUD, listen for changes. |
| `RewardRepository` | Manage rewards/offers (list/add/update/archive). |
| `InvoiceRepository` | Save invoices with OCR data, update status, compute points + update customer docs. |
| `CustomerRepository` | Fetch merchant customers, update `merchantPoints`. |
| `CashierRepository` | Promote/demote cashiers referencing `customers`. |
| `CommunityRepository` | Stream community rooms + messages per merchant. |
| `NotificationRepository` | Stream/mark notifications as read. |
| `OcrService` | Receives image, returns structured map (merchant code, invoice number/date/time, line items, subtotal/tax/total, SHA-256 hash) + raw text via Gemini Cloud Function (fallback to OCR.space); discards binary post-processing. |

### Screen Wiring
1. **Merchant Signup/Login**
	- Signup: create Auth user, create `merchants/{uid}` doc with provided fields, navigate to dashboard.
	- Login: fetch merchant doc, store `merchantId` locally.

2. **Merchant Dashboard**
	- Use `MerchantRepository.watchMerchant(merchantId)` for header.
	- `InvoiceRepository.fetchRecentInvoices(merchantId, limit:10)` for cards.
	- `RewardRepository.fetchActiveRewards(merchantId)` for highlights.

3. **Products Screen**
	- List via `ProductRepository.watchMerchantProducts`.
	- Add/Edit forms writing to `products` collection + validation for `pointsPerUnit`.

4. **Rewards/Offers Screen**
	- CRUD using reward repo; enforce `startDate <= endDate`.

5. **Invoices Screen / Scanner**
	- Scanner sends image → `OcrService` → returns structured map.
	- `InvoiceRepository.createInvoice` persists invoice + `ocrText`; `CustomerRepository` increments points.
	- Update invoice status actions.

6. **Cashiers Screen**
	- Autocomplete customers from `customers` collection (filtered by `merchantPoints`).
	- Create cashier doc with permissions.

7. **Sales Analytics**
	- Aggregate invoices client-side (range queries) initially; later move heavy logic to Cloud Functions if needed.

8. **Community & Notifications**
	- Communities: stream `communities` docs for merchant, nested `messages` writes with `serverTimestamp`.
	- Notifications: stream by `userId`, mark read toggling `isRead`.

### Next Steps
1. Update `firestore.rules` per spec + optional helper functions.
2. Implement repositories/services with unit-testable APIs.
3. Wire merchant UI screens incrementally (dashboard → products → rewards → invoices → analytics → cashiers → community → notifications).
4. Provide README snippet on seeding data + emulator usage.
