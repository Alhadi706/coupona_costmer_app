part of 'package:coupona_app/screens/merchant_dashboard_screen.dart';

extension _MerchantKpiCardsExt on _MerchantDashboardScreenState {
  Widget _buildTodayOperationalKpis(Map<String, dynamic> sales, Map<String, dynamic> customers) {
    final salesTotal = _money(sales['total'] ?? sales['todaySales']);
    final redemptions = _intValue(sales['redemptions']);
    final pointsSpent = _intValue(sales['pointsSpent'] ?? sales['pointsAwarded']);
    final activeCustomers = _intValue(customers['activeToday'] ?? customers['unique']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpiMetricCard(
              width: itemWidth,
              title: 'مبيعات اليوم (LYD)',
              value: salesTotal,
              icon: Icons.payments_outlined,
              iconColor: kMerchantBrandGreen,
              bgColor: const Color(0xFFECFDF5),
            ),
            _kpiMetricCard(
              width: itemWidth,
              title: 'عمليات المسح/الاستبدال',
              value: '$redemptions',
              icon: Icons.qr_code_2_outlined,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
            ),
            _kpiMetricCard(
              width: itemWidth,
              title: 'النقاط الممنوحة',
              value: '$pointsSpent',
              icon: Icons.stars_outlined,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
            ),
            _kpiMetricCard(
              width: itemWidth,
              title: 'العملاء النشطون اليوم',
              value: '$activeCustomers',
              icon: Icons.people_alt_outlined,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiMetricCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: kBodyTextStyle(size: 11, weight: FontWeight.w600, color: kMerchantMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: kDisplayTextStyle(size: 17, weight: FontWeight.w800, color: kMerchantDarkCharcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
