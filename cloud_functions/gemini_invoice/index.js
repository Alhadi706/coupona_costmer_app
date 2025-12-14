import fetch from 'node-fetch';
import {createHash} from 'node:crypto';
import {VertexAI} from '@google-cloud/vertexai';

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || process.env.PROJECT_ID;
const LOCATION = process.env.VERTEX_LOCATION || 'us-central1';
const MODEL = process.env.VERTEX_MODEL || 'gemini-1.5-pro';

if (!PROJECT_ID) {
  throw new Error('PROJECT_ID is not defined. Ensure the Cloud Function runs inside a Google Cloud project or set PROJECT_ID env var.');
}

const vertexAI = new VertexAI({project: PROJECT_ID, location: LOCATION});
const generativeModel = vertexAI.preview.getGenerativeModel({model: MODEL});

function buildPrompt(extraInstructions) {
  const basePrompt = `You are an expert accountant assistant.
You receive a single invoice/receipt image.
Extract *all* useful details and respond ONLY with valid JSON using the schema:
{
  "raw_text": string,
  "merchant_code": string|null,
  "merchant_name": string|null,
  "invoice_number": string|null,
  "invoice_date": "YYYY-MM-DD"|null,
  "invoice_time": "HH:MM"|null,
  "currency": string|null,
  "subtotal_amount": number|null,
  "tax_amount": number|null,
  "total_amount": number|null,
  "line_items": [
     {
       "description": string,
       "quantity": number|null,
       "unit_price": number|null,
       "line_total": number|null
     }
  ]
}
Rules:
- Keep raw_text in the language found (Arabic text must be preserved).
- Merchant codes often include the phrase "كود التاجر" or "Merchant Code" and are 4-12 alphanumeric characters.
- invoice_date must use ISO format if you can infer day/month/year.
- invoice_time must be 24h HH:MM.
- line_items array should list each distinct product/service; omit array entries only if there are zero items.
- Use null whenever a field is absent.
${extraInstructions ?? ''}`;
  return basePrompt;
}

async function downloadImage(imageUrl) {
  const response = await fetch(imageUrl);
  if (!response.ok) {
    throw new Error(`Failed to download image. Status ${response.status}`);
  }
  const arrayBuffer = await response.arrayBuffer();
  const contentType = response.headers.get('content-type') || 'image/jpeg';
  return {
    mimeType: contentType.split(';')[0],
    base64Data: Buffer.from(arrayBuffer).toString('base64'),
  };
}

function normalizeInlineData(imageBase64, fallbackMime) {
  const dataUrlMatch = /^data:(.+);base64,(.+)$/i.exec(imageBase64 || '');
  if (dataUrlMatch) {
    return {mimeType: dataUrlMatch[1], base64Data: dataUrlMatch[2]};
  }
  return {mimeType: fallbackMime, base64Data: imageBase64};
}

async function callGemini(prompt, inlineData) {
  const request = {
    contents: [
      {
        role: 'user',
        parts: [
          {text: prompt},
          {inlineData},
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      topP: 0.2,
      topK: 32,
      maxOutputTokens: 2048,
    },
  };

  const response = await generativeModel.generateContent(request);
  const candidates = response?.response?.candidates || [];
  const parts = candidates[0]?.content?.parts || [];
  const textPart = parts.find((part) => part.text);
  if (!textPart?.text) {
    throw new Error('Gemini returned an empty response.');
  }
  return textPart.text.trim();
}

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    return null;
  }
}

function numberOrNull(value) {
  if (value == null) return null;
  if (typeof value === 'number') return value;
  const parsed = Number(String(value).replace(/[,^\s]/g, ''));
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeLineItems(items) {
  if (!Array.isArray(items)) return [];
  return items
    .map((item) => ({
      description: item?.description?.toString().trim() || null,
      quantity: numberOrNull(item?.quantity),
      unitPrice: numberOrNull(item?.unit_price),
      lineTotal: numberOrNull(item?.line_total),
    }))
    .filter((item) => item.description || item.quantity || item.unitPrice || item.lineTotal);
}

export async function analyzeInvoice(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method not allowed. Use POST.'});
    return;
  }

  try {
    const {imageUrl, imageBase64, extraInstructions} = req.body || {};
    if (!imageUrl && !imageBase64) {
      res.status(400).json({error: 'Provide either imageUrl or imageBase64.'});
      return;
    }

    let inlineData;
    if (imageBase64) {
      inlineData = normalizeInlineData(imageBase64, 'image/jpeg');
    } else {
      inlineData = await downloadImage(imageUrl);
    }

    const prompt = buildPrompt(extraInstructions);
    const modelResponse = await callGemini(prompt, inlineData);
    const parsed = safeJsonParse(modelResponse);

    if (!parsed) {
      res.status(502).json({error: 'Gemini response was not valid JSON.', raw: modelResponse});
      return;
    }

    const rawText = parsed.raw_text?.toString() || '';
    const normalized = {
      rawText,
      rawTextHash: rawText ? createHash('sha256').update(rawText, 'utf8').digest('hex') : null,
      merchantCode: parsed.merchant_code?.toString() || null,
      merchantName: parsed.merchant_name?.toString() || null,
      invoiceNumber: parsed.invoice_number?.toString() || null,
      invoiceDate: parsed.invoice_date?.toString() || null,
      invoiceTime: parsed.invoice_time?.toString() || null,
      currency: parsed.currency?.toString() || null,
      subtotalAmount: numberOrNull(parsed.subtotal_amount),
      taxAmount: numberOrNull(parsed.tax_amount),
      totalAmount: numberOrNull(parsed.total_amount),
      lineItems: normalizeLineItems(parsed.line_items),
      model: MODEL,
      location: LOCATION,
    };

    res.status(200).json(normalized);
  } catch (error) {
    console.error('analyzeInvoice error', error);
    res.status(500).json({error: error.message || 'Unexpected error'});
  }
}
