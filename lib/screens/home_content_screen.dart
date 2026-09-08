import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/customer_campaign_coupons_section.dart';
import 'home_content_screen_banner.dart';
import 'home_content_screen_offers.dart';
import 'home_quick_shortcuts.dart';
import 'home_content_screen_summary.dart';
import 'home_store_discovery_section.dart';

class HomeContentScreen extends StatefulWidget {
  final VoidCallback onOpenOffersTab;
  final VoidCallback onOpenPeerAdsTab;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenCoalitions;
  final VoidCallback? onOpenCommunity;
  final VoidCallback? onOpenCustomerOffers;
  final VoidCallback? onScanReceipt;
  final Future<List<Map<String, dynamic>>> Function()? billboardAdsLoader;

  const HomeContentScreen({
    super.key,
    required this.onOpenOffersTab,
    required this.onOpenPeerAdsTab,
    this.onOpenMap,
    this.onOpenRewards,
    this.onOpenCoalitions,
    this.onOpenCommunity,
    this.onOpenCustomerOffers,
    this.onScanReceipt,
    this.billboardAdsLoader,
  });

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  static const LatLng _tripoliDefaultCenter = LatLng(32.8872, 13.1913);

  bool _discoverMapMode = false;
  String _selectedDiscoverCategory = '';
  double? _customerLat;
  double? _customerLng;
  late Future<List<Map<String, dynamic>>> _storesFuture;
  late Future<List<Map<String, dynamic>>> _billboardAdsFuture;
  late Future<List<Map<String, dynamic>>> _customerBannersFuture;
  late Future<Map<String, dynamic>> _pointsFuture;
  late Future<Map<String, dynamic>> _tiersFuture;
  late Future<Map<String, dynamic>> _pendingFuture;
  late Future<Map<String, dynamic>> _sourcesFuture;
  late Future<List<Map<String, dynamic>>> _rewardsFuture;

  // Getters for external split-off views to utilize cleanly
  Future<List<Map<String, dynamic>>> get storesFuture => _storesFuture;
  Future<Map<String, dynamic>> get pointsFuture => _pointsFuture;
  Future<List<Map<String, dynamic>>> get rewardsFuture => _rewardsFuture;
  Future<Map<String, dynamic>> get tiersFuture => _tiersFuture;
  Future<Map<String, dynamic>> get pendingFuture => _pendingFuture;
  Future<Map<String, dynamic>> get sourcesFuture => _sourcesFuture;
  Future<List<Map<String, dynamic>>> get billboardAdsFuture =>
      _billboardAdsFuture;
  Future<List<Map<String, dynamic>>> get customerBannersFuture =>
      _customerBannersFuture;
  bool get discoverMapMode => _discoverMapMode;
  String get selectedDiscoverCategory => _selectedDiscoverCategory;
  double? get customerLat => _customerLat;
  double? get customerLng => _customerLng;
  LatLng get tripoliDefaultCenter => _tripoliDefaultCenter;

  void handleBillboardTap(Map<String, dynamic> ad) => _handleBillboardTap(ad);
  void handleCategoryChanged(String cat) =>
      setState(() => _selectedDiscoverCategory = cat);
  void handleMapModeChanged(bool val) => setState(() => _discoverMapMode = val);
  void reloadStores() => _reloadStores();

  @override
  void initState() {
    super.initState();
    _storesFuture = CompanyServerService.getStores().catchError(
      (_) => const <Map<String, dynamic>>[],
    );
    _billboardAdsFuture =
        (widget.billboardAdsLoader?.call() ??
                CompanyServerService.getBillboardAds())
            .catchError((_) => const <Map<String, dynamic>>[]);
    _customerBannersFuture = CompanyServerService.getCustomerBanners()
        .catchError((_) => const <Map<String, dynamic>>[]);
    _pointsFuture = CompanyServerService.getPointAccount().catchError(
      (_) => <String, dynamic>{},
    );
    _tiersFuture = CompanyServerService.getCustomerPointTiers().catchError(
      (_) => <String, dynamic>{},
    );
    _pendingFuture = CompanyServerService.getCustomerPendingPoints().catchError(
      (_) => <String, dynamic>{},
    );
    _sourcesFuture = CompanyServerService.getWalletPointSources().catchError(
      (_) => <String, dynamic>{},
    );
    _rewardsFuture = CompanyServerService.getRewards().catchError(
      (_) => const <Map<String, dynamic>>[],
    );
    _resolveCustomerLocation();
  }

  void _reloadStores() {
    setState(() {
      _storesFuture = CompanyServerService.getStores().catchError(
        (_) => const <Map<String, dynamic>>[],
      );
    });
  }

  Future<void> _resolveCustomerLocation() async {
    try {
      final stored = await CompanyServerService.getMyCustomerLocation();
      final storedLat = stored['latitude'] == null
          ? null
          : _toDouble(stored['latitude']);
      final storedLng = stored['longitude'] == null
          ? null
          : _toDouble(stored['longitude']);
      if (storedLat != null && storedLng != null && mounted) {
        setState(() {
          _customerLat = storedLat;
          _customerLng = storedLng;
        });
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      await CompanyServerService.updateMyCustomerLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _customerLat = position.latitude;
        _customerLng = position.longitude;
      });
    } catch (_) {
      // Fallback to default map center when location permission is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[kSand, kWhite],
        ),
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildBanner(this),
                  const SizedBox(height: 12),
                  buildWelcomeSummary(this),
                  const SizedBox(height: 12),
                  buildQuickShortcutActions(this),
                  const SizedBox(height: 12),
                  const CustomerCampaignCouponsSection(),
                  const SizedBox(height: 16),
                  Text(
                    'home_explore_title'.tr(),
                    style: kDisplayTextStyle(size: 20, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'home_explore_subtitle'.tr(),
                    style: kBodyTextStyle(
                      size: 13,
                      color: kInk.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 10),
                  buildStoreDiscoverySection(this),
                  const SizedBox(height: 12),
                  buildBrandPointsBreakdown(this),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Extracted widget views are housed in focused split-off components.

  // Billboard tap and details helpers remain inside state
  void _showBillboardDetails(Map<String, dynamic> ad) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final imageUrl = (ad['imageUrl'] ?? ad['image'] ?? '').toString();
        final assetPath = imageUrl;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.startsWith('http'))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (!imageUrl.startsWith('http') && assetPath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      assetPath,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  (ad['description'] ??
                          ad['title'] ??
                          'home_billboard_ad_default_title'.tr())
                      .toString(),
                  style: kDisplayTextStyle(size: 20, weight: FontWeight.w700),
                ),
                if ((ad['category'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    (ad['category']).toString(),
                    style: kBodyTextStyle(
                      color: kTeal,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
                if ((ad['location'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    (ad['location']).toString(),
                    style: kBodyTextStyle(color: kInk.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBillboardTap(Map<String, dynamic> ad) async {
    final id = (ad['id'] ?? '').toString();
    if (id.isNotEmpty) {
      try {
        await CompanyServerService.trackBillboardClick(id);
      } catch (_) {}
    }
    final ctaType = (ad['ctaType'] ?? 'store').toString();
    final ctaValue = (ad['ctaValue'] ?? '').toString().trim();
    if (ctaType == 'external' && ctaValue.isNotEmpty) {
      final uri = Uri.tryParse(ctaValue);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) _showBillboardDetails(ad);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}
