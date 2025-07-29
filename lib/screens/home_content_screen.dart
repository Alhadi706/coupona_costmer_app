import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/category_bar.dart'; // استيراد صحيح حسب هيكل المشروع
import '../widgets/map_bar.dart'; // استيراد صحيح حسب هيكل المشروع
import 'category_offers_screen.dart';
import 'offer_detail_screen.dart';

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
  final List<String> imgList = [
    'https://via.placeholder.com/600x250/8BC34A/FFFFFF?Text=Offer+1',
    'https://via.placeholder.com/600x250/FFC107/FFFFFF?Text=Offer+2',
    'https://via.placeholder.com/600x250/03A9F4/FFFFFF?Text=Offer+3',
    'https://via.placeholder.com/600x250/E91E63/FFFFFF?Text=Offer+4',
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
    final snapshot = await FirebaseFirestore.instance.collection('offers').orderBy('createdAt', descending: true).get();
    setState(() {
      offers = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      isLoadingOffers = false;
    });
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
                if (imgList.isNotEmpty)
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
                            items: imgList.map((item) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5.0),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                                child: Image.network(item, fit: BoxFit.cover, width: 1000.0),
                              ),
                            )).toList(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: imgList.asMap().entries.map((entry) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _currentCarouselIndex == entry.key ? 16.0 : 8.0,
                                height: 8.0,
                                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: _currentCarouselIndex == entry.key
                                      ? Colors.blue.shade700
                                      : Colors.blue.shade200.withOpacity(0.5),
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
                  ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: offers.length,
                    separatorBuilder: (context, i) => const Divider(),
                    itemBuilder: (context, i) {
                      final offer = offers[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.black,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (offer['imageUrl'] != null && offer['imageUrl'] != '')
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    offer['imageUrl'],
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 140,
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (offer['endDate'] != null && offer['endDate'] != '')
                                    Text(_getEndDateText(offer['endDate']), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  if (offer['offerType'] != null && offer['offerType'] != '')
                                    Chip(
                                      label: Text(
                                        (offer['offerType']?.toString().trim() ?? '').tr(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.deepPurple,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(offer['description'] ?? 'بدون وصف', style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // انتقل إلى التفاصيل
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => OfferDetailScreen(offer: offer),
                                      ),
                                    );
                                  },
                                  child: Text('عرض التفاصيل'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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

  // أضف دالة لحساب صلاحية العرض
  String _getEndDateText(String? endDate) {
    if (endDate == null || endDate.isEmpty) return '';
    try {
      String dateStr = endDate;
      if (dateStr.contains('T')) {
        dateStr = dateStr.split('T').first;
      }
      dateStr = dateStr.replaceAll(RegExp(r'[^0-9\-]'), '');
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff < 0) return 'offer_expired'.tr();
      if (diff == 0) return 'offer_expires_today'.tr();
      if (diff == 1) return 'offer_expires_tomorrow'.tr();
      if (diff < 7) return 'offer_expires_in_days'.tr(namedArgs: {'days': diff.toString()});
      if (diff < 30) return 'offer_expires_in_days'.tr(namedArgs: {'days': diff.toString()});
      if (diff < 365) return 'offer_expires_in_months'.tr(namedArgs: {'months': (diff ~/ 30).toString()});
      return 'offer_expires_in_years'.tr(namedArgs: {'years': (diff ~/ 365).toString()});
    } catch (e) {
      return '';
    }
  }
}