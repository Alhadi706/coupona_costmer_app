# Coupona Customer App

Cross-platform Flutter application that helps customers discover merchants, redeem offers, and now keep track of scanned invoices linked to Supabase.

---

## Invoice Linking Overview

Each scanned invoice is persisted to the Supabase `invoices` table via `SupabaseInvoiceService.addInvoice`. The record acts as the shared contract between merchant and customer using the following keys:

| Column        | Purpose                                             |
| ------------- | --------------------------------------------------- |
| `merchant_id` | Auth identifier of the merchant that owns the store |
| `user_id`     | Auth identifier of the customer who scanned         |
| `invoice_number`, `unique_hash`, `date`, `total`, `products` | Additional metadata captured from OCR |

### Supabase query helpers

`lib/services/supabase_invoice_service.dart` now includes utilities to explore the link graph:

- `fetchInvoicesForUser(userId)` – full invoice history for a customer.
- `fetchInvoicesForMerchant(merchantId)` – invoices captured for a merchant.
- `fetchDistinctMerchantIdsForUser(userId)` – discover merchants a customer interacted with.
- `fetchDistinctCustomerIdsForMerchant(merchantId)` – list customers who submitted invoices to a merchant.

Example SQL equivalents (for reference or onboarding another platform):

```sql
-- Merchant app: who scanned my invoices?
SELECT DISTINCT user_id
FROM invoices
WHERE merchant_id = :currentMerchantId;

-- Customer app: which merchants have my invoices?
SELECT DISTINCT merchant_id
FROM invoices
WHERE user_id = :currentUserId;
```

> Use the resulting identifiers to hydrate UI cards from `profiles`, `customers`, or `merchants` tables as needed in each app.

---

## OCR & Image Capture Stack

Invoice scanning is powered by on-device Google ML Kit OCR and the Flutter image picker. Key packages in `pubspec.yaml`:

- `google_mlkit_text_recognition` – extracts text from captured receipts.
- `image_picker` – launches the device camera for invoice capture.

`lib/screens/scan_invoice_screen.dart` demonstrates auto-launching the camera, processing the image, and presenting raw OCR text for subsequent parsing.

---

## Local Development

1. Install Flutter 3.8.0 or newer.
2. Run the analyzers and fetch dependencies:

	```powershell
	flutter pub get
	flutter analyze
	```

3. Launch on your preferred platform:

	```powershell
	flutter run -d chrome
	```

4. Provide Supabase credentials via `SupabaseService` (already configured for the shared project). Update the anon key if rotating credentials.

---

## Next Steps

- Use `InvoiceParser.parseInvoiceData` to transform OCR output into structured invoice fields (merchant ID + total) before inserting into Supabase; adjust regexes as you encounter new invoice formats.
- Enrich merchant and customer views with profile lookups based on the helper methods above.
