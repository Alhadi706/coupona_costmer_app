import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class CustomerCampaignCouponsSection extends StatefulWidget {
  const CustomerCampaignCouponsSection({super.key});

  @override
  State<CustomerCampaignCouponsSection> createState() => _CustomerCampaignCouponsSectionState();
}

class _CustomerCampaignCouponsSectionState extends State<CustomerCampaignCouponsSection> {
  Timer? _timer;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _coupons = const [];
  List<Map<String, dynamic>> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        CompanyServerService.getMyCampaignCoupons(),
        CompanyServerService.getMyRaffleTickets()
            .catchError((_) => const <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _coupons = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _tickets = List<Map<String, dynamic>>.from(results[1] as List<dynamic>);
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  String _countdown(Map<String, dynamic> coupon) {
    if ((coupon['status'] ?? '').toString() == 'redeemed') return 'تم استخدامه';
    final endsAt = _date(coupon['ends_at']);
    if (endsAt == null) return 'بدون تاريخ انتهاء';
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return 'انتهت الصلاحية';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    return days > 0 ? 'متبقي $days يوم و$hours ساعة' : 'متبقي $hours ساعة و$minutes دقيقة';
  }

  bool _isUsable(Map<String, dynamic> coupon) {
    final status = (coupon['status'] ?? '').toString();
    final endsAt = _date(coupon['ends_at']);
    return status == 'issued' && (endsAt == null || endsAt.isAfter(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_activity_outlined, color: kTeal),
            const SizedBox(width: 8),
            Expanded(child: Text('كوبوناتي الخاصة', style: kDisplayTextStyle(size: 18))),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث الكوبونات'),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          _MessagePanel(
            icon: Icons.error_outline,
            title: 'تعذر تحميل الكوبونات',
            subtitle: _error!,
            action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          )
        else if (_coupons.isEmpty && _tickets.isEmpty)
          const _MessagePanel(
            icon: Icons.inbox_outlined,
            title: 'لا توجد كوبونات خاصة حالياً',
            subtitle: 'ستظهر هنا العروض التي يرسلها لك المتجر أو العلامة التجارية.',
          )
        else ...[
          ..._coupons.map(_buildCouponCard),
          ..._tickets.map(_buildTicketCard),
        ],
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final title = (ticket['title'] ?? 'تذكرة سحب').toString();
    final number = (ticket['ticket_number'] ?? '').toString();
    final endsAt = _date(ticket['ends_at']);
    final remaining = endsAt == null
        ? 'بانتظار موعد السحب'
        : (endsAt.isAfter(DateTime.now()) ? 'ينتهي ${endsAt.year}-${endsAt.month.toString().padLeft(2, '0')}-${endsAt.day.toString().padLeft(2, '0')}' : 'بانتظار إعلان الفائز');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: kGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: kGold, child: Icon(Icons.confirmation_number_outlined, color: kWhite)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: kBodyTextStyle(weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('رقم التذكرة: $number', style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.76))),
                const SizedBox(height: 5),
                Text(
                  'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك المكتسبة من مشترياتك العادية.',
                  style: kBodyTextStyle(size: 11, weight: FontWeight.w700, color: kInk.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(remaining, style: kBodyTextStyle(size: 11, weight: FontWeight.w700, color: kGold)),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    final usable = _isUsable(coupon);
    final type = (coupon['campaign_type'] ?? '').toString();
    final discount = coupon['discount_percentage'];
    final title = (coupon['title'] ?? 'كوبون خاص').toString();
    final qrCode = (coupon['qr_code'] ?? '').toString();
    final startsAt = _date(coupon['starts_at']);
    final endsAt = _date(coupon['ends_at']);
    final accent = usable ? kTeal : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  type == 'free_gift' ? Icons.card_giftcard_outlined : Icons.percent,
                  color: kWhite,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: kDisplayTextStyle(size: 16, color: kWhite))),
                if (discount != null)
                  Text('${num.tryParse(discount.toString())?.toStringAsFixed(0) ?? discount}%', style: kPointsNumberStyle(size: 24, color: kWhite)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final qr = Opacity(
                  opacity: usable ? 1 : 0.38,
                  child: Container(
                    width: 190,
                    height: 190,
                    padding: const EdgeInsets.all(10),
                    color: kWhite,
                    child: QrImageView(data: qrCode, version: QrVersions.auto),
                  ),
                );
                final details = _couponDetails(
                  coupon: coupon,
                  usable: usable,
                  startsAt: startsAt,
                  endsAt: endsAt,
                  accent: accent,
                );
                if (compact) {
                  return Column(children: [qr, const SizedBox(height: 12), details]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [qr, const SizedBox(width: 16), Expanded(child: details)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponDetails({
    required Map<String, dynamic> coupon,
    required bool usable,
    required DateTime? startsAt,
    required DateTime? endsAt,
    required Color accent,
  }) {
    String date(DateTime? value) => value == null
        ? '-'
        : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final gift = (coupon['gift_description'] ?? '').toString();
    final type = (coupon['campaign_type'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(kRadiusPill)),
          child: Text(_countdown(coupon), style: kBodyTextStyle(size: 12, weight: FontWeight.w700, color: accent)),
        ),
        if (gift.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(gift, style: kBodyTextStyle(weight: FontWeight.w700)),
        ],
        const SizedBox(height: 10),
        Text('صالح من ${date(startsAt)} إلى ${date(endsAt)}', style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.72))),
        const SizedBox(height: 6),
        Text(
          usable ? 'اعرض الرمز على الكاشير عند الدفع.' : 'هذا الكوبون غير متاح للاستخدام.',
          style: kBodyTextStyle(size: 12, color: usable ? kInk : Colors.grey.shade700),
        ),
        if (type == 'raffle') ...[
          const SizedBox(height: 8),
          Text(
            'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك المكتسبة من مشترياتك العادية.',
            style: kBodyTextStyle(size: 12, weight: FontWeight.w700, color: kInk.withValues(alpha: 0.78)),
          ),
        ],
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.title, required this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: kTeal),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: kBodyTextStyle(weight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: kBodyTextStyle(size: 12))])),
          if (action != null) action!,
        ],
      ),
    );
  }
}