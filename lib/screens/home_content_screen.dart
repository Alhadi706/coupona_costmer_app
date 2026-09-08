import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/customer_campaign_coupons_section.dart';
import '../widgets/design_system/kupuna_offer_card.dart';
import '../widgets/stream_load_error.dart';
import 'home_content_screen_banner.dart';
import 'home_content_screen_summary.dart';
import 'store_details_screen.dart';

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

  final TextEditingController _searchController = TextEditingController();
  int _activeTab = 0;
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
  Future<List<Map<String, dynamic>>> get billboardAdsFuture => _billboardAdsFuture;
  Future<List<Map<String, dynamic>>> get customerBannersFuture => _customerBannersFuture;
  TextEditingController get searchController => _searchController;
  int get activeTab => _activeTab;
  bool get discoverMapMode => _discoverMapMode;
  String get selectedDiscoverCategory => _selectedDiscoverCategory;
  double? get customerLat => _customerLat;
  double? get customerLng => _customerLng;
  LatLng get tripoliDefaultCenter => _tripoliDefaultCenter;

  void handleBillboardTap(Map<String, dynamic> ad) => _handleBillboardTap(ad);
  void handleTabChanged(int index) => setState(() => _activeTab = index);
  void handleCategoryChanged(String cat) => setState(() => _selectedDiscoverCategory = cat);
  void handleMapModeChanged(bool val) => setState(() => _discoverMapMode = val);
  void handleSearchChanged(String _) => setState(() {});
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
    _customerBannersFuture = CompanyServerService.getCustomerBanners().catchError(
      (_) => const <Map<String, dynamic>>[],
    );
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  buildSearchBar(this),
                  const SizedBox(height: 12),
                  buildTopTabs(this),
                  const SizedBox(height: 12),
                  buildTabBody(this),
                  const SizedBox(height: 12),
                  _buildBrandPointsBreakdown(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // (Extracted Widget views buildWelcomeSummary, buildQuickShortcutActions, buildSearchBar, buildTopTabs, buildTabBody are now housed in separate modern split-off components)

  Widget _buildBrandPointsBreakdown() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _sourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final raw = snapshot.data;
        final payload = raw ?? const <String, dynamic>{};
        final rawBrands = payload['brandSources'];
        final brands = rawBrands is List
            ? rawBrands
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
        if (brands.isEmpty) {
          return const SizedBox.shrink();
        }
        return _SectionCard(
          title: 'نقاط العلامات التجارية',
          subtitle: 'تفكيك مصدر النقاط من البراندات المشتركة.',
          child: Column(
            children: brands.map((brand) {
              final active = _toInt(brand['activePoints']);
              final lifetime = _toInt(brand['lifetimePoints']);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: kMint,
                  child: Icon(Icons.verified_outlined, color: kTeal),
                ),
                title: Text(
                  (brand['sourceName'] ?? 'Brand').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('إجمالي مكتسب: $lifetime نقطة'),
                trailing: Text(
                  '$active نقطة',
                  style: const TextStyle(
                    color: kTeal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

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

  Widget _buildTabBody() {
    switch (_activeTab) {
      case 1:
        return _buildOffersList(
          heading: 'home_offers_section_title'.tr(),
          sourceType: 'brand',
          emptyKey: 'home_offers_empty',
          onHeaderAction: widget.onOpenOffersTab,
        );
      case 2:
        return _buildPeerAdsList();
      default:
        return _buildDiscoverTab();
    }
  }

  Widget _buildDiscoverTab() {
    return _SectionCard(
      title: 'home_discover_section_title'.tr(),
      subtitle: 'home_list_live_subtitle'.tr(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StreamLoadError(),
                  TextButton(
                    onPressed: _reloadStores,
                    child: Text('retry'.tr()),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final keyword = _searchController.text.trim().toLowerCase();
          final sourceRows = List<Map<String, dynamic>>.from(snapshot.data!);
          final categories =
              sourceRows
                  .map((e) => (e['category'] ?? '').toString().trim())
                  .where((v) => v.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

          final seenNames = <String>{};
          final filteredRows = <Map<String, dynamic>>[];
          for (final store in sourceRows) {
            final name = (store['name'] ?? '').toString().trim();
            final category = (store['category'] ?? '').toString();
            final matchesKeyword = keyword.isEmpty || name.toLowerCase().contains(keyword);
            final matchesCategory = _selectedDiscoverCategory.isEmpty || category == _selectedDiscoverCategory;
            if (matchesKeyword && matchesCategory) {
              final normalized = name.toLowerCase();
              if (normalized.isNotEmpty && seenNames.contains(normalized)) {
                continue;
              }
              seenNames.add(normalized);
              filteredRows.add(store);
            }
          }
          filteredRows.sort((a, b) {
            final distanceA = _distanceKm(
              _customerLat,
              _customerLng,
              _toDouble(a['lat']),
              _toDouble(a['lng']),
            );
            final distanceB = _distanceKm(
              _customerLat,
              _customerLng,
              _toDouble(b['lat']),
              _toDouble(b['lng']),
            );
            return distanceA.compareTo(distanceB);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('home_discover_all_categories'.tr()),
                    selected: _selectedDiscoverCategory.isEmpty,
                    onSelected: (_) {
                      setState(() {
                        _selectedDiscoverCategory = '';
                      });
                    },
                  ),
                  ...categories.map(
                    (cat) => ChoiceChip(
                      label: Text(cat),
                      selected: _selectedDiscoverCategory == cat,
                      onSelected: (_) {
                        setState(() {
                          _selectedDiscoverCategory =
                              _selectedDiscoverCategory == cat ? '' : cat;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.view_list),
                    label: Text('home_discover_list'.tr()),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.map_outlined),
                    label: Text('home_discover_map'.tr()),
                  ),
                ],
                selected: <bool>{_discoverMapMode},
                onSelectionChanged: (value) {
                  setState(() {
                    _discoverMapMode = value.first;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (filteredRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('home_discover_empty'.tr()),
                )
              else if (_discoverMapMode)
                _buildDiscoverMap(filteredRows)
              else
                _buildDiscoverList(filteredRows),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiscoverMap(List<Map<String, dynamic>> stores) {
    final center = stores.isNotEmpty
        ? LatLng(_toDouble(stores.first['lat']), _toDouble(stores.first['lng']))
        : (_customerLat == null || _customerLng == null)
        ? _tripoliDefaultCenter
        : LatLng(_customerLat!, _customerLng!);

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.coupona_app',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: stores
                  .map(
                    (store) => Marker(
                      width: 42,
                      height: 42,
                      point: LatLng(
                        _toDouble(store['lat']),
                        _toDouble(store['lng']),
                      ),
                      child: Tooltip(
                        message: (store['name'] ?? '').toString(),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverList(List<Map<String, dynamic>> stores) {
    final sourceLat = _customerLat;
    final sourceLng = _customerLng;
    return Column(
      children: stores
          .take(10)
          .map((store) {
            final distance = _distanceKm(
              sourceLat,
              sourceLng,
              _toDouble(store['lat']),
              _toDouble(store['lng']),
            );
            final coalitions = (store['coalitions'] as List?) ?? const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadiusCard),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoreDetailsScreen(store: store),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: kMint,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: kTealDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (store['name'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'home_discover_store_distance'.tr(
                                    namedArgs: {
                                      'category': (store['category'] ?? '-')
                                          .toString(),
                                      'distance': distance.toStringAsFixed(2),
                                    },
                                  ),
                                  style: kBodyTextStyle(
                                    size: 12,
                                    color: kInk.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: kTeal,
                          ),
                        ],
                      ),
                      if (store['merchantId'] != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _storeMetaChip(
                              Icons.loyalty_outlined,
                              _storePointTierLabel(store['pointTier']),
                              kGold,
                            ),
                            _storeMetaChip(
                              Icons.add_circle_outline,
                              "⚡ كاشباك ${store['pointValue'] ?? store['cashbackRate'] ?? 5}%",
                              kTeal,
                            ),
                            _storeMetaChip(
                              Icons.inventory_2_outlined,
                              "خدمات المتجر",
                              kIndigo,
                            ),
                          ],
                        ),
                        if (coalitions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'store_coalitions_value'.tr(
                              namedArgs: {
                                'value': coalitions
                                    .map(
                                      (item) =>
                                          (item as Map)['name']?.toString() ??
                                          '',
                                    )
                                    .where((name) => name.isNotEmpty)
                                    .join(' • '),
                              },
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: kBodyTextStyle(
                              size: 12,
                              weight: FontWeight.w600,
                              color: kTealDark,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _storeMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: kBodyTextStyle(
              size: 11,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _storePointTierLabel(dynamic tier) {
    return switch (tier?.toString()) {
      'gold' => 'store_points_gold'.tr(),
      'silver' => 'store_points_silver'.tr(),
      _ => 'store_points_bronze'.tr(),
    };
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  double _distanceKm(
    double? fromLat,
    double? fromLng,
    double toLat,
    double toLng,
  ) {
    final originLat = fromLat ?? _tripoliDefaultCenter.latitude;
    final originLng = fromLng ?? _tripoliDefaultCenter.longitude;
    return Geolocator.distanceBetween(originLat, originLng, toLat, toLng) /
        1000;
  }

  Widget _buildOffersList({
    required String heading,
    required String emptyKey,
    required String? sourceType,
    required VoidCallback? onHeaderAction,
  }) {
    return _SectionCard(
      title: heading,
      subtitle: 'home_list_live_subtitle'.tr(),
      action: onHeaderAction == null
          ? null
          : TextButton(
              onPressed: onHeaderAction,
              child: Text('home_open_tab'.tr()),
            ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 8))
            .asyncMap((_) => CompanyServerService.getOffers())
            .startWithFuture(CompanyServerService.getOffers()),
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return const StreamLoadError();
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final keyword = _searchController.text.trim().toLowerCase();
          final rows = snapshot.data!
              .where((row) {
                final title = (row['description'] ?? row['title'] ?? '')
                    .toString()
                    .toLowerCase();
                final category = (row['category'] ?? '')
                    .toString()
                    .toLowerCase();
                final ownerType = (row['ownerType'] ?? row['sourceType'] ?? '')
                    .toString()
                    .toLowerCase();

                if (sourceType != null && !ownerType.contains(sourceType)) {
                  return false;
                }

                if (keyword.isEmpty) {
                  return true;
                }
                return title.contains(keyword) || category.contains(keyword);
              })
              .toList(growable: false);

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyKey.tr()),
            );
          }

          return Column(
            children: rows
                .take(6)
                .map((offer) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KupunaOfferCard(
                      offer: <String, dynamic>{
                        ...offer,
                        'title':
                            (offer['description'] ??
                                    offer['title'] ??
                                    'new_offer'.tr())
                                .toString(),
                        'subtitle': (offer['category'] ?? '').toString(),
                      },
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _buildPeerAdsList() {
    return _SectionCard(
      title: 'home_peer_ads_section_title'.tr(),
      subtitle: 'home_peer_ads_section_subtitle'.tr(),
      action: TextButton(
        onPressed: widget.onOpenPeerAdsTab,
        child: Text('home_open_tab'.tr()),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 8))
            .asyncMap((_) => CompanyServerService.getOffers())
            .startWithFuture(CompanyServerService.getOffers()),
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return const StreamLoadError();
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final keyword = _searchController.text.trim().toLowerCase();
          final rows = snapshot.data!
              .where((row) {
                final ownerType = (row['ownerType'] ?? row['sourceType'] ?? '')
                    .toString()
                    .toLowerCase();
                final title = (row['description'] ?? row['title'] ?? '')
                    .toString()
                    .toLowerCase();
                final category = (row['category'] ?? '')
                    .toString()
                    .toLowerCase();
                final isPeer =
                    ownerType.contains('peer') ||
                    ownerType.contains('individual');
                if (!isPeer) {
                  return false;
                }
                if (keyword.isEmpty) {
                  return true;
                }
                return title.contains(keyword) || category.contains(keyword);
              })
              .toList(growable: false);

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('home_peer_ads_empty'.tr()),
            );
          }

          return Column(
            children: rows
                .take(6)
                .map((offer) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KupunaOfferCard(
                      offer: <String, dynamic>{
                        ...offer,
                        'title':
                            (offer['content'] ??
                                    offer['description'] ??
                                    'new_offer'.tr())
                                .toString(),
                        'subtitle':
                            (offer['targetValue'] ?? offer['category'] ?? '')
                                .toString(),
                        'sourceType': 'peer',
                      },
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kWhite,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: kDisplayTextStyle(
                          size: 16,
                          weight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: kBodyTextStyle(
                          color: kInk.withValues(alpha: 0.6),
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
