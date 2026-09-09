#!/usr/bin/env python3
"""One-shot batch 2: keys for previously hardcoded merchant dashboard/coalition strings."""
import json

AR = {
    "merchant_browse_customer_offers": "🛒 تصفح عروض الزبائن",
    "merchant_product_add_title": "إضافة منتج للمتجر",
    "merchant_product_edit_title": "تعديل المنتج",
    "merchant_product_name_label": "اسم المنتج *",
    "merchant_product_price_label": "السعر (اختياري)",
    "merchant_product_desc_label": "وصف المنتج (اختياري)",
    "merchant_product_active": "المنتج نشط",
    "merchant_product_active_hint": "سيظهر للعملاء في التطبيق عند تفعيله",
    "merchant_product_name_required": "اسم المنتج مطلوب",
    "merchant_store_products": "منتجات المتجر",
    "merchant_product_add_new": "إضافة منتج جديد",
    "merchant_products_empty": "لا توجد منتجات مضافة لهذا المتجر حاليًا.",
    "currency_lyd": "د.ل",
    "merchant_quick_actions": "إجراءات سريعة للمحل",
    "merchant_pos_scan_qr": "📸 مسح QR كاشير",
    "merchant_pos_preview": "📸 تجربة كاشير (معاينة)",
    "merchant_reward_add": "إضافة جائزة",
    "merchant_pos_status_active": "حالة POS مفعلة وجاهزة للاستخدام",
    "merchant_pos_status_inactive": "حالة نظام الكاشير (POS) غير مفعلة",
    "merchant_pos_subtitle_active": "يمكنك إجراء عمليات المسح واستبدال النقاط مباشرة",
    "merchant_pos_subtitle_inactive": "قم بتفعيل ربط كاشير المحل للبدء في استقبال واستبدال نقاط العملاء",
    "merchant_pos_open": "فتح POS",
    "merchant_pos_activate": "🔗 تفعيل POS",
    "merchant_pos_dialog_title": "تفعيل ربط كاشير POS",
    "merchant_pos_dialog_intro": "لتفعيل حاسب الكاشير الخاص بالفرع:",
    "merchant_pos_dialog_step_1": "1. اختر الفرع المراد ربطه.",
    "merchant_pos_dialog_step_2": "2. أدخل معرف المستخدم الخاص بالكاشير.",
    "merchant_pos_cashier_id_label": "معرف مستخدم الكاشير",
    "merchant_pos_cashier_id_hint": "مثال: user-cashier-101",
    "merchant_pos_confirm_activation": "تأكيد التفعيل",
    "merchant_analytics_banner_title": "التحليلات التفصيلية للعملاء والأداء",
    "merchant_analytics_banner_subtitle": "معدلات الاستدامة، التوزيع الجغرافي والديموغرافي مع خيارات التصدير",
    "merchant_analytics_open": "فتح التحليلات",
    "merchant_chart_7day_title": "أداء المبيعات والاستبدال (آخر 7 أيام)",
    "merchant_chart_legend_sales": "مبيعات",
    "merchant_chart_legend_points": "نقاط",
    "merchant_day_sun": "أحد",
    "merchant_day_mon": "إثنين",
    "merchant_day_tue": "ثلاثاء",
    "merchant_day_wed": "أربعاء",
    "merchant_day_thu": "خميس",
    "merchant_day_fri": "جمعة",
    "merchant_day_sat": "سبت",
    "merchant_kpi_sales_today": "مبيعات اليوم (LYD)",
    "merchant_kpi_scans_redemptions": "عمليات المسح/الاستبدال",
    "merchant_kpi_points_granted": "النقاط الممنوحة",
    "merchant_kpi_active_customers": "العملاء النشطون اليوم",
    "select": "اختيار",
    "no_data": "لا توجد بيانات",
}

EN = {
    "merchant_browse_customer_offers": "🛒 Browse customer offers",
    "merchant_product_add_title": "Add store product",
    "merchant_product_edit_title": "Edit product",
    "merchant_product_name_label": "Product name *",
    "merchant_product_price_label": "Price (optional)",
    "merchant_product_desc_label": "Product description (optional)",
    "merchant_product_active": "Product active",
    "merchant_product_active_hint": "Visible to customers in the app when enabled",
    "merchant_product_name_required": "Product name is required",
    "merchant_store_products": "Store products",
    "merchant_product_add_new": "Add new product",
    "merchant_products_empty": "No products added to this store yet.",
    "currency_lyd": "LYD",
    "merchant_quick_actions": "Quick store actions",
    "merchant_pos_scan_qr": "📸 Cashier QR scan",
    "merchant_pos_preview": "📸 Cashier trial (preview)",
    "merchant_reward_add": "Add reward",
    "merchant_pos_status_active": "POS is active and ready to use",
    "merchant_pos_status_inactive": "Cashier system (POS) is not activated",
    "merchant_pos_subtitle_active": "You can scan and redeem points directly",
    "merchant_pos_subtitle_inactive": "Activate cashier linking to start accepting and redeeming customer points",
    "merchant_pos_open": "Open POS",
    "merchant_pos_activate": "🔗 Activate POS",
    "merchant_pos_dialog_title": "Activate POS cashier linking",
    "merchant_pos_dialog_intro": "To activate the branch cashier account:",
    "merchant_pos_dialog_step_1": "1. Select the branch to link.",
    "merchant_pos_dialog_step_2": "2. Enter the cashier user ID.",
    "merchant_pos_cashier_id_label": "Cashier user ID",
    "merchant_pos_cashier_id_hint": "e.g. user-cashier-101",
    "merchant_pos_confirm_activation": "Confirm activation",
    "merchant_analytics_banner_title": "Detailed customer & performance analytics",
    "merchant_analytics_banner_subtitle": "Retention rates, geographic & demographic distribution with export options",
    "merchant_analytics_open": "Open analytics",
    "merchant_chart_7day_title": "Sales & redemption performance (last 7 days)",
    "merchant_chart_legend_sales": "Sales",
    "merchant_chart_legend_points": "Points",
    "merchant_day_sun": "Sun",
    "merchant_day_mon": "Mon",
    "merchant_day_tue": "Tue",
    "merchant_day_wed": "Wed",
    "merchant_day_thu": "Thu",
    "merchant_day_fri": "Fri",
    "merchant_day_sat": "Sat",
    "merchant_kpi_sales_today": "Today's sales (LYD)",
    "merchant_kpi_scans_redemptions": "Scans/redemptions",
    "merchant_kpi_points_granted": "Points granted",
    "merchant_kpi_active_customers": "Active customers today",
    "select": "Select",
    "no_data": "No data",
}

def append_keys(path, new):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    data = json.loads(text)
    added = {k: v for k, v in new.items() if k not in data}
    if not added:
        print(f"{path}: nothing to add")
        return
    stripped = text.rstrip()
    assert stripped.endswith("}"), path
    body = stripped[:-1].rstrip()
    assert not body.endswith(","), path
    lines = [","]
    items = list(added.items())
    for i, (k, v) in enumerate(items):
        suffix = "," if i < len(items) - 1 else ""
        lines.append(f"  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}{suffix}")
    out = body + "\n".join(lines) + "\n}\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(out)
    json.loads(out)
    print(f"{path}: added {len(added)} keys (total {len(data) + len(added)})")

append_keys("assets/lang/ar.json", AR)
append_keys("assets/lang/en.json", EN)
