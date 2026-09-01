# 🏷️ Brand + Merchant Dual Point Engine — Final E2E Test Report

**Date**: August 26, 2026
**Status**: ✅ **100% PASS (16/16 checks)**

---

## Executive Summary

Implemented and validated the **Co-Op Brand Loyalty Engine**: customers earn *dual points* — Merchant Store Points (from total spend) **plus** Brand Product Points (funded independently by the brand, not the merchant) — with atomic wallet deductions, an automatic **pending queue** when a brand's budget is exhausted, and an itemized Arabic congratulations message breaking down every point source.

---

## What Was Built (New Backend Features)

The dual-brand wallet/pending mechanism did not exist before this task — brand points were previously awarded unconditionally with no budget check. Added:

1. **`brand_token_wallets`** + **`brand_token_ledger`** tables — mirrors `merchant_token_wallets`, gives every brand its own spendable point budget.
2. **`customer_pending_brand_points`** table — holds brand points that couldn't be funded immediately.
3. **`applyInvoiceApprovalRewards`** ([services-matching.js](../backend/src/services-matching.js)) updated: for each matched brand line item, the brand wallet is checked `FOR UPDATE`; if insufficient, points go to the pending table instead of blocking merchant points (which are deducted from an entirely separate merchant wallet).
4. **Itemized notification message**: `"تهانينا! حصلت على [X] نقطة من [التاجر]، و [Y] نقطة من علامة [البراند]."` — built dynamically from merchant + brand names.
5. **`/api/brand/tokens/recharge`** endpoint ([brand-token-wallet.js](../backend/src/routes/brand-token-wallet.js)) — funds the brand wallet and automatically clears its pending queue via new `clearPendingBrandPointsQueue` in [pending-points-service.js](../backend/src/pending-points-service.js).

---

## Test Scenario & Results

| Entity | Config |
|---|---|
| Merchant A | point_value = 5 (LYD/point) |
| Brand Tory (توري) | point_value = 1, wallet funded = 1000 |
| Brand Pepsi (ببسي) | point_value = 1, wallet = **0 (forces pending)** |

| Invoice | Customer | Store Amount | Brand Items | Merchant Pts | Tory Pts | Pepsi Pts |
|---|---|---|---|---|---|---|
| 1 | Alpha | 100 | 1×Tory + 2×Pepsi | 20 ✅ | 5 ✅ (active) | 4 → **pending** ✅ |
| 2 | Beta | 50 | 3×Pepsi | 10 ✅ | — | 6 → **pending** ✅ |
| 3 | Gamma | 25 | 2×Tory | 5 ✅ | 10 ✅ (active) | — |

### Key Validations (all passed)
- ✅ Merchant wallet deducted independently: `10000 → 9965` (−35 total merchant points)
- ✅ Tory wallet deducted: `1000 → 985` (−15, funded normally)
- ✅ **Pepsi wallet stayed at 0** — merchant/Tory points were *not blocked* by Pepsi's empty budget (atomicity confirmed)
- ✅ Pepsi's 10 points (4+6) sat in `customer_pending_brand_points` until recharge
- ✅ After `/api/brand/tokens/recharge` (Pepsi +100), all pending Pepsi points cleared to active ledger automatically
- ✅ Itemized notification generated correctly, e.g.:
  > "تهانينا! حصلت على 20 نقطة من Merchant A (Dual)، و5 نقطة من علامة توري (Tory)."

---

## Files Changed / Added
- [backend/src/schema-extra.js](../backend/src/schema-extra.js) — new tables
- [backend/src/services-matching.js](../backend/src/services-matching.js) — dual-wallet brand point logic + itemized message
- [backend/src/pending-points-service.js](../backend/src/pending-points-service.js) — `clearPendingBrandPointsQueue`
- [backend/src/routes/brand-token-wallet.js](../backend/src/routes/brand-token-wallet.js) — new route (recharge, balance, pending summary)
- [backend/server.js](../backend/server.js) — registered new route
- [backend/live_brand_merchant_dual_scenario.js](../backend/live_brand_merchant_dual_scenario.js) — full E2E test script (16 assertions)

## Result
✅ **APPROVED** — Dual brand/merchant point engine works exactly as specified: brands fund their own product-level loyalty independently, merchants are never charged for brand points, and insufficient brand budgets gracefully queue instead of blocking the transaction.
