import 'dart:ui' as ui;
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
import '../services/firebase_service.dart';
import '../services/badge_helper.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeScreen extends StatefulWidget {
  final String phone;
  final String? age;
  final String? gender;

  // أضف متغير لتبديل نمط شريط الفئات
  final int categoryBarType; // 1: ListView صف واحد، 2: GridView صفين

  const HomeScreen({
    super.key,
    required this.phone,
    this.age,
    this.gender,
    this.categoryBarType = 2, // الافتراضي GridView صفين
  });

  // قائمة الفئات (لإعادة الاستخدام)
  static final List<Map<String, dynamic>> categoriesStatic = [
    {'icon': Icons.restaurant, 'label': 'restaurants', 'width': 80.0},
    {'icon': Icons.directions_car, 'label': 'cars', 'width': 80.0},
    {'icon': Icons.diamond, 'label': 'jewelry', 'width': 80.0},
    {'icon': Icons.hotel, 'label': 'hotels', 'width': 80.0},
    {'icon': Icons.apartment, 'label': 'real_estate', 'width': 80.0},
    {'icon': Icons.cottage, 'label': 'resthouses', 'width': 80.0},
    {'icon': Icons.checkroom, 'label': 'clothing', 'width': 80.0},
    {'icon': Icons.local_hospital, 'label': 'clinics', 'width': 80.0},
    {'icon': Icons.electrical_services, 'label': 'electronics', 'width': 80.0},
    {'icon': Icons.sports_soccer, 'label': 'activities', 'width': 80.0},
    {'icon': Icons.category, 'label': 'other', 'width': 80.0},
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

  void _onItemTapped(int index, {int? offersCount}) async {
    setState(() {
      _selectedIndex = index;
    });
    // تصفير العداد عند فتح الشاشة
    if (index == 1 && offersCount != null) {
      await BadgeHelper.setLastCount(BadgeHelper.offersKey, offersCount);
      setState(() => offersUnread = offersCount);
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
    final langKey = ValueKey(context.locale.languageCode);
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

    return Directionality(
      textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        key: langKey,
        appBar: AppBar(
          title: Text('app_title'.tr(), style: TextStyle(color: Colors.white)),
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
        bottomNavigationBar: FutureBuilder<int>(
          future: () async {
            try {
              final snapshot = await FirebaseService.firestore.collection('offers').get();
              return snapshot.docs.length;
            } catch (e) {
              return 0;
            }
          }(),
          builder: (context, offersSnapshot) {
            final offersBadgeCount = offersSnapshot.data ?? 0;
            return StreamBuilder(
              stream: FirebaseFirestore.instance.collection('groups').snapshots(),
              builder: (context, groupsSnapshot) {
                int communityBadgeCount = 0;
                if (groupsSnapshot.hasData) {
                  communityBadgeCount = groupsSnapshot.data!.docs.length;
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
                    }
                    return BottomNavigationBar(
                      items: [
                        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home_nav'.tr()),
                        BottomNavigationBarItem(
                          icon: badges.Badge(
                            showBadge: offersBadgeCount - offersUnread > 0,
                            badgeContent: Text('${offersBadgeCount - offersUnread}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                            child: const Icon(Icons.card_giftcard),
                          ),
                          label: 'offers_nav'.tr(),
                        ),
                        BottomNavigationBarItem(
                          icon: badges.Badge(
                            showBadge: communityBadgeCount > 0,
                            badgeContent: Text('$communityBadgeCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                            child: const Icon(Icons.groups),
                          ),
                          label: 'community_nav'.tr(),
                        ),
                        BottomNavigationBarItem(
                          icon: badges.Badge(
                            showBadge: rewardsBadgeCount > 0,
                            badgeContent: Text('$rewardsBadgeCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                            child: const Icon(Icons.emoji_events),
                          ),
                          label: 'rewards_nav'.tr(),
                        ),
                      ],
                      currentIndex: _selectedIndex > 2 ? _selectedIndex - 1 : _selectedIndex,
                      onTap: (index) {
                        if (index == 1) {
                          _onItemTapped(1, offersCount: offersBadgeCount);
                        } else if (index == 3) {
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
      ),
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

  @override
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