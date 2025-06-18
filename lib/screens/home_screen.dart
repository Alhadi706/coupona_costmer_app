import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:badges/badges.dart' as badges;
import 'profile_screen.dart';
import 'offers_screen.dart';
import 'community_screen.dart';
import 'settings_screen.dart';
import 'points_screen.dart';
import '../widgets/report_icon.dart';
import '../widgets/scan_invoice_icon.dart';
import '../widgets/add_invoice_icon.dart';
import '../widgets/menu_icon.dart';
import '../widgets/map_bar.dart';
import 'ads_banner_slider.dart';
import 'full_map_screen.dart'; // تأكد من استيراد الشاشة الجديدة
import '../widgets/category_bar.dart';
import 'report_screen.dart' show ReportScreen; // استورد فقط ReportScreen
import 'scan_invoice_screen.dart'; // استيراد شاشة ScanInvoiceScreen
import 'add_coupon_screen.dart'; // استيراد شاشة AddCouponScreen
import 'category_offers_screen.dart'; // استيراد شاشة عروض الفئة
import 'home_content_screen.dart'; // استيراد الشاشة الجديدة
import 'my_rewards_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/badge_helper.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeScreen extends StatefulWidget {
  final String phone;
  final String age;
  final String gender;

  // أضف متغير لتبديل نمط شريط الفئات
  final int categoryBarType; // 1: ListView صف واحد، 2: GridView صفين

  const HomeScreen({
    super.key,
    required this.phone,
    required this.age,
    required this.gender,
    this.categoryBarType = 2, // الافتراضي GridView صفين
  });

  // قائمة الفئات (لإعادة الاستخدام)
  static final List<Map<String, dynamic>> categoriesStatic = [
    {
      'icon': Icons.restaurant,
      'label': 'مطاعم',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'مطعم الذواقة',
          'offerType': 'تخفيض',
          'percent': 'خصم 20%',
          'endDate': '2025-06-10',
          'description': 'تخفيض 20% على جميع الوجبات.',
          'conditions': 'يسري العرض على الطلبات الداخلية فقط.',
          'location': 'الرياض - حي العليا',
          'phone': '0500000001',
        },
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'مطعم البيت الشامي',
          'offerType': 'هدية',
          'percent': '',
          'endDate': '2025-06-15',
          'description': 'هدية مجانية مع كل وجبة عائلية.',
          'conditions': 'يسري العرض على الطلبات الداخلية فقط.',
          'location': 'جدة - شارع فلسطين',
          'phone': '0500000002',
        },
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'مطعم برجر تايم',
          'offerType': 'نقاط مضاعفة',
          'percent': '',
          'endDate': '2025-06-20',
          'description': 'نقاط مضاعفة على كل طلب برجر.',
          'conditions': 'يسري العرض على الطلبات الخارجية فقط.',
          'location': 'الدمام - حي الشاطئ',
          'phone': '0500000003',
        },
      ]
    },
    {
      'icon': Icons.directions_car,
      'label': 'سيارات',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'مغسلة سيارات النخبة',
          'offerType': 'نقاط مضاعفة',
          'percent': '',
          'endDate': '2025-06-15',
          'description': 'احصل على نقاط مضاعفة عند كل غسيل.',
          'conditions': 'يسري العرض على غسيل السيارات الصغيرة فقط.',
          'location': 'جدة - شارع التحلية',
          'phone': '0500000004',
        },
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'تبديل زيوت السريع',
          'offerType': 'تخفيض',
          'percent': 'خصم 10%',
          'endDate': '2025-06-18',
          'description': 'خصم 10% على جميع أنواع الزيوت.',
          'conditions': 'يسري العرض على الزيوت المستوردة فقط.',
          'location': 'الرياض - حي المروج',
          'phone': '0500000005',
        },
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'قطع غيار الخليج',
          'offerType': 'هدية',
          'percent': '',
          'endDate': '2025-06-25',
          'description': 'هدية مجانية مع كل عملية شراء فوق 500 ريال.',
          'conditions': 'حتى نفاد الكمية.',
          'location': 'الدمام - طريق الخليج',
          'phone': '0500000006',
        },
      ]
    },
    {
      'icon': Icons.diamond,
      'label': 'مجوهرات',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'مجوهرات الألماس',
          'offerType': 'هدية',
          'percent': '',
          'endDate': 'دائم',
          'description': 'هدية مجانية مع كل عملية شراء فوق 1000 ريال.',
          'conditions': 'حتى نفاد الكمية.',
          'location': 'الدمام - طريق الخليج',
          'phone': '0500000007',
        },
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'مجوهرات الفخامة',
          'offerType': 'تخفيض',
          'percent': 'خصم 25%',
          'endDate': '2025-06-30',
          'description': 'خصم 25% على أطقم الذهب.',
          'conditions': 'يسري العرض على الأطقم الكاملة فقط.',
          'location': 'الرياض - حي العليا',
          'phone': '0500000008',
        },
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'ساعات النخبة',
          'offerType': 'نقاط مضاعفة',
          'percent': '',
          'endDate': '2025-07-01',
          'description': 'نقاط مضاعفة على جميع الساعات.',
          'conditions': 'يسري العرض على الساعات السويسرية فقط.',
          'location': 'جدة - شارع الأمير سلطان',
          'phone': '0500000009',
        },
      ]
    },
    {
      'icon': Icons.hotel,
      'label': 'إقامة',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'فندق الراحة',
          'offerType': 'تخفيض',
          'percent': 'خصم 15%',
          'endDate': '2025-06-20',
          'description': 'خصم 15% على جميع الغرف.',
          'conditions': 'يشترط الحجز المسبق.',
          'location': 'مكة - العزيزية',
          'phone': '0500000010',
        },
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'شقق النور',
          'offerType': 'تخفيض',
          'percent': 'خصم 10%',
          'endDate': '2025-07-05',
          'description': 'خصم 10% على الشقق الفندقية.',
          'conditions': 'يسري العرض على الإقامة لأسبوع أو أكثر.',
          'location': 'الرياض - حي النرجس',
          'phone': '0500000011',
        },
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'منتجع الشاطئ',
          'offerType': 'هدية',
          'percent': '',
          'endDate': '2025-07-10',
          'description': 'هدية مجانية مع كل حجز فيلا.',
          'conditions': 'حتى نفاد الكمية.',
          'location': 'جدة - حي الشاطئ',
          'phone': '0500000012',
        },
      ]
    },
    {
      'icon': Icons.apartment,
      'label': 'عقارات',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'مكتب عقار الشرق',
          'offerType': 'بيع',
          'percent': '',
          'endDate': '2025-07-01',
          'description': 'شقة للبيع بسعر مميز.',
          'conditions': 'السعر قابل للتفاوض.',
          'location': 'الرياض - حي النرجس',
          'phone': '0500000013',
        },
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'مكتب عقارات الخليج',
          'offerType': 'تخفيض',
          'percent': 'خصم 5%',
          'endDate': '2025-07-15',
          'description': 'خصم 5% على عمولات البيع.',
          'conditions': 'يسري العرض على العقارات السكنية فقط.',
          'location': 'جدة - حي الروضة',
          'phone': '0500000014',
        },
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'مكتب إيجار الشرق',
          'offerType': 'إيجار',
          'percent': '',
          'endDate': '2025-07-20',
          'description': 'عروض إيجار شقق بأسعار منافسة.',
          'conditions': 'يشترط عقد سنوي.',
          'location': 'الدمام - حي الفيصلية',
          'phone': '0500000015',
        },
      ]
    },
    {
      'icon': Icons.self_improvement,
      'label': 'أنشطة',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'نادي اللياقة',
          'offerType': 'تخفيض',
          'percent': 'خصم 10%',
          'endDate': '2025-06-30',
          'description': 'خصم 10% على الاشتراكات السنوية.',
          'conditions': 'يسري العرض على الاشتراك الجديد فقط.',
          'location': 'جدة - حي الروضة',
          'phone': '0500000016',
        },
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'مركز الأنشطة الصيفية',
          'offerType': 'هدية',
          'percent': '',
          'endDate': '2025-07-10',
          'description': 'هدية مجانية لكل مشترك جديد.',
          'conditions': 'حتى نفاد الكمية.',
          'location': 'الرياض - حي الربيع',
          'phone': '0500000017',
        },
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'مخيم المغامرات',
          'offerType': 'نقاط مضاعفة',
          'percent': '',
          'endDate': '2025-07-15',
          'description': 'نقاط مضاعفة على كل اشتراك.',
          'conditions': 'يسري العرض على المخيمات الصيفية فقط.',
          'location': 'مكة - حي الشوقية',
          'phone': '0500000018',
        },
      ]
    },
    {
      'icon': Icons.local_hospital,
      'label': 'صحة',
      'width': 80.0,
      'offers': [
        {
          'image': 'assets/ads/ad1.png',
          'storeName': 'صيدلية الشفاء',
          'offerType': 'نقاط مضاعفة',
          'percent': '',
          'endDate': '2025-06-12',
          'description': 'نقاط مضاعفة على جميع المشتريات.',
          'conditions': 'يسري العرض على المنتجات غير المخفضة.',
          'location': 'الرياض - حي الملك فهد',
          'phone': '0500000019',
        },
        {
          'image': 'assets/ads/ad2.png',
          'storeName': 'مركز الصحة الشاملة',
          'offerType': 'تخفيض',
          'percent': 'خصم 8%',
          'endDate': '2025-07-05',
          'description': 'خصم 8% على جميع الخدمات الطبية.',
          'conditions': 'يسري العرض على الخدمات غير التأمينية.',
          'location': 'جدة - حي الصفا',
          'phone': '0500000020',
        },
        {
          'image': 'assets/ads/ad3.png',
          'storeName': 'مركز العلاج الطبيعي',
          'offerType': 'هدية',
          'percent': '',
          'endDate': '2025-07-15',
          'description': 'هدية مجانية مع كل جلسة علاجية.',
          'conditions': 'حتى نفاد الكمية.',
          'location': 'مكة - حي العزيزية',
          'phone': '0500000021',
        },
      ]
    },
    {
      'icon': Icons.category,
      'label': 'جميع الفئات',
      'width': 90.0,
      'offers': [],
    },
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int offersUnread = 0;
  int communityUnread = 0;
  int rewardsUnread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCounts();
  }

  Future<void> _loadUnreadCounts() async {
    final offersLast = await BadgeHelper.getLastCount(BadgeHelper.offersKey);
    final communityLast = await BadgeHelper.getLastCount(BadgeHelper.communityKey);
    final rewardsLast = await BadgeHelper.getLastCount(BadgeHelper.rewardsKey);
    setState(() {
      offersUnread = offersLast;
      communityUnread = communityLast;
      rewardsUnread = rewardsLast;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // تصفير العداد عند فتح الشاشة
    if (index == 1) {
      BadgeHelper.setLastCount(BadgeHelper.offersKey, 0);
      setState(() => offersUnread = 0);
    } else if (index == 2) {
      BadgeHelper.setLastCount(BadgeHelper.communityKey, 0);
      setState(() => communityUnread = 0);
    } else if (index == 4) {
      BadgeHelper.setLastCount(BadgeHelper.rewardsKey, 0);
      setState(() => rewardsUnread = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      HomeContentScreen(
        categories: HomeScreen.categoriesStatic,
        onCategoryTap: (category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryOffersScreen(
                categoryName: category['label'],
              ),
            ),
          );
        },
        onMapTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FullMapScreen()),
          );
        },
      ),
      OffersScreen(),
      CommunityScreen(),
      SettingsScreen(),
      MyRewardsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('كوبونا', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple.shade700,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // يمكنك إضافة أيقونات أخرى هنا إذا أردت
        ],
      ),
      drawer: AppDrawer(),
      body: widgetOptions[_selectedIndex],
      bottomNavigationBar: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('offers').snapshots(),
        builder: (context, offersSnapshot) {
          int offersBadgeCount = 0;
          if (offersSnapshot.hasData) {
            offersBadgeCount = offersSnapshot.data!.docs.length;
            // تحديث عداد العروض غير المقروءة
            if (offersBadgeCount > offersUnread) {
              BadgeHelper.setLastCount(BadgeHelper.offersKey, offersBadgeCount);
              setState(() => offersUnread = offersBadgeCount);
            }
          }
          return StreamBuilder(
            stream: FirebaseFirestore.instance.collection('groups').snapshots(),
            builder: (context, groupsSnapshot) {
              int communityBadgeCount = 0;
              if (groupsSnapshot.hasData) {
                communityBadgeCount = groupsSnapshot.data!.docs.length;
                if (communityBadgeCount > communityUnread) {
                  BadgeHelper.setLastCount(BadgeHelper.communityKey, communityBadgeCount);
                  setState(() => communityUnread = communityBadgeCount);
                }
              }
              return StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('user_rewards')
                    .where('userPhone', isEqualTo: widget.phone)
                    .snapshots(),
                builder: (context, rewardsSnapshot) {
                  int rewardsBadgeCount = 0;
                  if (rewardsSnapshot.hasData) {
                    rewardsBadgeCount = rewardsSnapshot.data!.docs.length;
                    if (rewardsBadgeCount > rewardsUnread) {
                      BadgeHelper.setLastCount(BadgeHelper.rewardsKey, rewardsBadgeCount);
                      setState(() => rewardsUnread = rewardsBadgeCount);
                    }
                  }
                  return BottomNavigationBar(
                    items: [
                      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
                      BottomNavigationBarItem(
                        icon: badges.Badge(
                          showBadge: offersUnread > 0,
                          badgeContent: Text('$offersUnread', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                          child: const Icon(Icons.card_giftcard),
                        ),
                        label: 'العروض',
                      ),
                      BottomNavigationBarItem(
                        icon: badges.Badge(
                          showBadge: communityUnread > 0,
                          badgeContent: Text('$communityUnread', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                          child: const Icon(Icons.groups),
                        ),
                        label: 'المجتمع',
                      ),
                      // تم حذف أيقونة الضبط من البار السفلي
                      BottomNavigationBarItem(
                        icon: badges.Badge(
                          showBadge: rewardsUnread > 0,
                          badgeContent: Text('$rewardsUnread', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                          child: const Icon(Icons.emoji_events),
                        ),
                        label: 'جوائزي',
                      ),
                    ],
                    currentIndex: _selectedIndex > 2 ? _selectedIndex - 1 : _selectedIndex,
                    onTap: (index) {
                      // إذا ضغط المستخدم على العنصر الأخير (جوائزي) أو قبله، عدل الفهرس
                      if (index == 3) {
                        _onItemTapped(4);
                      } else {
                        _onItemTapped(index);
                      }
                    },
                    selectedItemColor: Colors.deepPurple,
                    unselectedItemColor: Colors.grey,
                    backgroundColor: Colors.white,
                    type: BottomNavigationBarType.fixed,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? _buildSpeedDial()
          : null,
      floatingActionButtonLocation: context.locale.languageCode == 'ar' ? FloatingActionButtonLocation.startFloat : FloatingActionButtonLocation.endFloat,
    );
  }

  SpeedDial _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.add,
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      activeBackgroundColor: Colors.deepPurple.shade700,
      activeForegroundColor: Colors.white,
      spacing: 12,
      children: [
        SpeedDialChild(
          label: 'scan_invoice'.tr(),
          child: Icon(Icons.camera_alt),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ScanInvoiceScreen()),
            );
          },
        ),
        SpeedDialChild(
          label: 'add_offer'.tr(),
          child: Icon(Icons.local_offer),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddCouponScreen()),
            );
          },
        ),
        SpeedDialChild(
          label: 'report'.tr(),
          child: Icon(Icons.report),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReportScreen()),
            );
          },
        ),
      ],
    );
  }
}

class CategoryShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final double fontSize;
  final double width;

  const CategoryShortcut({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 24.0,
    this.fontSize = 14.0,
    this.width = 64
  });

  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: Colors.deepPurple),
          SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize, color: Colors.deepPurple),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

