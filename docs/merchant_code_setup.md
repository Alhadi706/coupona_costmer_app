# Merchant Code & Auto-Linking

This note explains how the new merchant-code workflow operates so external billing systems can embed the right data on invoices.

## 1. Code assignment
- Every merchant receives a 6-character alphanumeric code automatically during signup (`MerchantCodeService`).
- Codes are stored in Firestore under `merchants/{merchantId}` (`merchantCode`, `merchantCodeAssignedAt`) and in the lookup collection `merchantCodes/{code}`.
- The dashboard now shows the code with quick copy/QR actions (`MerchantCodeBanner`).

## 2. Printing guidelines
- Embed both the text code and the QR payload (simple uppercase string) on every invoice that leaves the external billing platform.
- The Arabic copy instructs merchants to place the QR next to the printed code so the OCR flow can capture either format.
- You can export/print the QR directly inside the dashboard (Share/Copy buttons).

## 3. OCR & parsing
- `InvoiceParser` now looks for patterns such as `كود التاجر`/`Merchant Code` and normalizes them to `merchant_code` inside the parsed payload.
- If the OCR layer cannot find a code, the scan screen prompts the user to type the value manually (`invoice_link_missing_code`).

## 4. Linking logic
- `UserMerchantLinkService.sendDataToLinkAgent` accepts the merchant code, resolves it to a merchant id, and creates a structured invoice through `InvoiceRepository.createInvoice`.
- Each stored invoice now contains `merchantCode`, `merchantId`, `customerId`, `ocrText`, and the usual monetary totals.
- We also log the raw OCR payload to `invoiceLinks/{invoiceId}` for auditing and analytics.
- After a successful link, the service ensures there is a `merchantCustomerRooms/{merchantId}_{customerId}` document so chat/notifications can target the right audience.

## 5. External platform checklist
1. Surface the merchant code inside your POS/invoicing UI so cashiers can stamp it on every printed receipt.
2. Optionally embed the QR string (same code) for faster scanning.
3. Ensure fonts keep the code legible (avoid stylized glyphs that can confuse OCR).
4. Educate staff/customers to keep the code unobstructed when taking invoice photos.

With these steps, any invoice generated outside Coupona can still be tied back to the correct merchant and customer automatically.