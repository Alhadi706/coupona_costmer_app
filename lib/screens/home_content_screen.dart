import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/firebase_service.dart';
import '../widgets/category_bar.dart'; // استيراد صحيح حسب هيكل المشروع
import '../widgets/map_bar.dart'; // استيراد صحيح حسب هيكل المشروع

class HomeContentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(Map<String, dynamic> category) onCategoryTap;
  final VoidCallback onMapTap;
  const HomeContentScreen({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    required this.onMapTap,
  });

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final List<_HeroBannerConfig> _bannerConfigs = const [
    _HeroBannerConfig(
      gradient: [Color(0xFF8BC34A), Color(0xFF4CAF50)],
      icon: Icons.local_offer,
      titleKey: 'offers_title',
      subtitleKey: 'available_rewards_now',
    ),
    _HeroBannerConfig(
      gradient: [Color(0xFFFFC107), Color(0xFFFF9800)],
      icon: Icons.card_giftcard,
      titleKey: 'my_rewards_title',
      subtitleKey: 'my_rewards_points_balance',
    ),
    _HeroBannerConfig(
      gradient: [Color(0xFF03A9F4), Color(0xFF0288D1)],
      icon: Icons.receipt_long,
      titleKey: 'scan_invoice',
      subtitleKey: 'tip_scan_invoices',
    ),
    _HeroBannerConfig(
      gradient: [Color(0xFFE91E63), Color(0xFFC2185B)],
      icon: Icons.add_circle_outline,
      titleKey: 'add_offer',
      subtitleKey: 'tip_use_public_coupons',
    ),
  ];

  int _currentCarouselIndex = 0;
  List<Map<String, dynamic>> offers = [];
  bool isLoadingOffers = true;

  @override
  void initState() {
    super.initState();
    fetchOffers();
  }

  Future<void> fetchOffers() async {
    try {
      final snapshot = await FirebaseService.firestore.collection('offers').orderBy('createdAt', descending: true).get();
      final list = snapshot.docs.map((d) {
        final map = Map<String, dynamic>.from(d.data());
        map['id'] = d.id;
        if (map['createdAt'] is Timestamp) map['createdAt'] = (map['createdAt'] as Timestamp).toDate();
        return map;
      }).toList();
      setState(() {
        offers = list;
        isLoadingOffers = false;
      });
    } catch (e) {
      debugPrint('Fetch offers error: $e');
      setState(() {
        offers = [];
        isLoadingOffers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFe3f0ff), Color(0xFFb6cfff)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صندوق البحث مع ظل خفيف
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(30),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'search_hint'.tr(),
                      prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_bannerConfigs.isNotEmpty)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          cs.CarouselSlider(
                            options: cs.CarouselOptions(
                              height: 108.0, // تم تصغيره بنسبة 40%
                              autoPlay: true,
                              autoPlayInterval: const Duration(seconds: 5),
                              enlargeCenterPage: true,
                              aspectRatio: 16 / 9,
                              viewportFraction: 0.9,
                              onPageChanged: (index, reason) {
                                setState(() {
                                  _currentCarouselIndex = index;
                                });
                              },
                            ),
                            items: _bannerConfigs.map((config) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5.0),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                                child: _HeroBanner(config: config),
                              ),
                            )).toList(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _bannerConfigs.asMap().entries.map((entry) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _currentCarouselIndex == entry.key ? 16.0 : 8.0,
                                height: 8.0,
                                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                    color: _currentCarouselIndex == entry.key
                                      ? Colors.blue.shade700
                                      : Colors.blue.shade200.withValues(alpha: 0.5),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // شريط الفئات داخل Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: CategoryBar(
                      categories: widget.categories,
                      height: 96,
                      iconSize: 38,
                      fontSize: 14,
                      onCategoryTap: widget.onCategoryTap,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // خريطة مصغرة داخل Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SizedBox(
                    height: 180,
                    child: MapBar(
                      onExpand: widget.onMapTap,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // نص القائمة
                if (isLoadingOffers)
                  const Center(child: CircularProgressIndicator())
                else if (offers.isEmpty)
                  const Center(child: Text('لا توجد عروض متاحة حالياً'))
                else
                  _OffersGrid(offers: offers),
                const SizedBox(height: 24),
                // -----------------------------
                // تنبيه بانتهاء النقاط قريبًا
                Banner(
                  message: 'تنبيه: لديك نقاط ستنتهي بعد 30 يوم! استخدمها قبل انتهاء الصلاحية.',
                  location: BannerLocation.topEnd,
                  color: Colors.orange.shade400,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // شريط التقدم نحو الجائزة
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('progress_to_next_reward'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 0.6, // نسبة التقدم (مثال)
                          minHeight: 10,
                          backgroundColor: Colors.blue.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text('points_left_to_reward'.tr(), style: TextStyle(color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // اقتراح جوائز مناسبة
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('available_rewards_now'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(label: Text('reward_coupon_10'.tr()), backgroundColor: Colors.blue.shade50),
                            Chip(label: Text('reward_gift_free'.tr()), backgroundColor: Colors.blue.shade50),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // نصائح لزيادة النقاط
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('smart_ways_to_increase_points'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: Icon(Icons.receipt_long, color: Colors.blue.shade700),
                          title: Text('tip_scan_invoices'.tr()),
                        ),
                        ListTile(
                          leading: Icon(Icons.group_add, color: Colors.blue.shade700),
                          title: Text('tip_invite_friends'.tr()),
                        ),
                        ListTile(
                          leading: Icon(Icons.card_giftcard, color: Colors.blue.shade700),
                          title: Text('tip_use_public_coupons'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBannerConfig {
  final List<Color> gradient;
  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  const _HeroBannerConfig({
    required this.gradient,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });
}

class _HeroBanner extends StatelessWidget {
  final _HeroBannerConfig config;

  const _HeroBanner({required this.config});

  @override
  Widget build(BuildContext context) {
    final gradientColors = config.gradient;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.length == 1
              ? [gradientColors.first, gradientColors.first]
              : gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(config.icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  config.titleKey.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.subtitleKey.tr(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _OffersGrid extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  const _OffersGrid({required this.offers});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount = width >= 480 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, index) => _OfferCard(data: offers[index]),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OfferCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl']?.toString();
    final category = data['category']?.toString() ?? '—';
    final description = data['description']?.toString() ?? '—';
    final discountValue = data['discountValue']?.toString();
    final expiry = _formatDate(context, data['endDate'] ?? data['expiration']);

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PlaceholderImage(),
                      )
                    : const _PlaceholderImage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepPurple)),
                      ),
                      const Spacer(),
                      if (discountValue != null && discountValue.isNotEmpty)
                        Text(discountValue, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(expiry ?? '—', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {},
                    child: Text('offers_details_btn'.tr(), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _formatDate(BuildContext context, dynamic value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }
    if (date == null) return null;
    final locale = context.locale.toString();
    return DateFormat('y/MM/dd', locale).format(date);
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.photo_size_select_actual_outlined, color: Colors.grey.shade500),
    );
  }
}