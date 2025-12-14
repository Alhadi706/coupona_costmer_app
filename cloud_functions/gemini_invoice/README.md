# Gemini Invoice OCR Cloud Function

This lightweight HTTP Cloud Function proxies invoice images to Google Vertex AI (Gemini) and returns rich structured data (raw OCR text, merchant code, invoice metadata, line items, etc.).

## Prerequisites

1. **APIs enabled**: Vertex AI API + Generative Language API (already done).
2. **Service account**: `coupona-gemini-service` with `Vertex AI User` (and optionally `Storage Object Viewer`).
3. **Authentication**: Deploy the function with the above service account or set `GOOGLE_APPLICATION_CREDENTIALS` locally when running `npm start`.
4. **gcloud CLI**: version >= 460.0.0.

## Local development

```bash
cd cloud_functions/gemini_invoice
npm install
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/coupona-gemini.json"
export PROJECT_ID="coupona-6b050" # or your project id
npm start
```

The dev server listens on `http://localhost:8080/`. You can test with:

```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"imageUrl":"https://firebasestorage.googleapis.com/..."}'
```

## Deploying (Cloud Functions 2nd Gen)

```bash
cd cloud_functions/gemini_invoice
npm install
export GOOGLE_CLOUD_PROJECT="coupona-6b050"
export SERVICE_ACCOUNT="coupona-gemini-service@coupona-6b050.iam.gserviceaccount.com"

gcloud functions deploy analyzeInvoice \
  --gen2 \
  --runtime=nodejs20 \
  --region=us-central1 \
  --entry-point=analyzeInvoice \
  --source=. \
  --trigger-http \
  --allow-unauthenticated \
  --service-account="$SERVICE_ACCOUNT" \
  --set-env-vars=VERTEX_LOCATION=us-central1,VERTEX_MODEL=gemini-1.5-pro
```

Deployment output includes the public URL (e.g. `https://us-central1-your-project.cloudfunctions.net/analyzeInvoice`). Copy it and pass it to the Flutter app via `--dart-define=GEMINI_OCR_ENDPOINT=...`.

## Request payload

```json
{
  "imageUrl": "https://firebasestorage.googleapis.com/v0/b/...",
  "extraInstructions": "If you see ضريبة القيمة المضافة include it in raw_text"
}
```

Alternatively, supply `imageBase64` using a `data:` URI. The response format contains analytics-friendly fields:

```json
{
  "rawText": "Arabic/English OCR text ...",
  "rawTextHash": "7c6c0d...",           // SHA-256 hash for deduping
  "merchantCode": "ABCD1234",
  "merchantName": "Store Name",
  "invoiceNumber": "INV-5541",
  "invoiceDate": "2025-05-14",
  "invoiceTime": "21:33",
  "currency": "SAR",
  "subtotalAmount": 110.00,
  "taxAmount": 15.40,
  "totalAmount": 125.40,
  "lineItems": [
    {"description": "Pepsi", "quantity": 2, "unitPrice": 4.5, "lineTotal": 9},
    {"description": "Pizza", "quantity": 1, "unitPrice": 32, "lineTotal": 32}
  ],
  "model": "gemini-1.5-pro",
  "location": "us-central1"
}
```

Handle HTTP `4xx/5xx` by falling back to the legacy OCR provider if desired.
