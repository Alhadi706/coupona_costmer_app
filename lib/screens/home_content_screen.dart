import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_offer_card.dart';
import '../widgets/design_system/kupuna_top_tabs.dart';
import '../widgets/stream_load_error.dart';
import 'ads_banner_slider.dart';
import 'store_details_screen.dart';

class HomeContentScreen extends StatefulWidget {
  final VoidCallback onOpenOffersTab;
  final VoidCallback onOpenPeerAdsTab;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenCommunity;
  final VoidCallback? onScanReceipt;
  final Future<List<Map<String, dynamic>>> Function()? billboardAdsLoader;

  const HomeContentScreen({
    super.key,
    required this.onOpenOffersTab,
    required this.onOpenPeerAdsTab,
    this.onOpenMap,
    this.onOpenRewards,
    this.onOpenCommunity,
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
  int _bannerIndex = 0;
  bool _discoverMapMode = false;
  String _selectedDiscoverCategory = '';
  double? _customerLat;
  double? _customerLng;
  late Future<List<Map<String, dynamic>>> _storesFuture;
  late Future<List<Map<String, dynamic>>> _billboardAdsFuture;
  late Future<Map<String, dynamic>> _pointsFuture;
  late Future<List<Map<String, dynamic>>> _rewardsFuture;

  static const List<String> _bannerKeys = <String>[
    'home_banner_1',
    'home_banner_2',
    'home_banner_3',
  ];

  @override
  void initState() {
    super.initState();
    _storesFuture = CompanyServerService.getStores().timeout(
      const Duration(seconds: 10),
      onTimeout: () => const <Map<String, dynamic>>[],
    );
    _billboardAdsFuture = (widget.billboardAdsLoader?.call() ?? CompanyServerService.getBillboardAds()).timeout(
      const Duration(seconds: 8),
      onTimeout: () => const <Map<String, dynamic>>[],
    );
    _pointsFuture = CompanyServerService.getPointAccount().catchError((_) => <String, dynamic>{});
    _rewardsFuture = CompanyServerService.getRewards().catchError((_) => <Map<String, dynamic>>[]);
    _resolveCustomerLocation();
  }

  void _reloadStores() {
    setState(() {
      _storesFuture = CompanyServerService.getStores();
    });
  }

  Future<void> _resolveCustomerLocation() async {
    try {
      final stored = await CompanyServerService.getMyCustomerLocation();
      final storedLat = stored['latitude'] == null ? null : _toDouble(stored['latitude']);
      final storedLng = stored['longitude'] == null ? null : _toDouble(stored['longitude']);
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
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(),
              const SizedBox(height: 12),
              _buildWelcomeSummary(),
              const SizedBox(height: 12),
              _buildCurrentMission(),
              const SizedBox(height: 12),
              _buildNearbyPreview(),
              const SizedBox(height: 12),
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildTopTabs(),
              const SizedBox(height: 12),
              _buildTabBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSummary() {
    return FutureBuilder<dynamic>(
      future: Future.wait<dynamic>([_pointsFuture, _rewardsFuture]),
      builder: (context, snapshot) {
        final points = snapshot.hasData && snapshot.data![0] is Map
            ? Map<String, dynamic>.from(snapshot.data![0] as Map)
            : <String, dynamic>{};
        final rewards = snapshot.hasData && snapshot.data![1] is List
            ? List<Map<String, dynamic>>.from(snapshot.data![1] as List)
            : <Map<String, dynamic>>[];
        final balance = _toInt(points['availablePoints']);
        final next = rewards.where((reward) => _toInt(reward['value']) > balance).fold<Map<String, dynamic>?>(null, (current, reward) {
          if (current == null || _toInt(reward['value']) < _toInt(current['value'])) return reward;
          return current;
        });
        final target = _toInt(next?['value']);
        final remaining = target > balance ? target - balance : 0;
        final expiresAt = DateTime.tryParse('${next?['expiresAt'] ?? ''}');
        final expiryMessage = expiresAt == null
            ? ''
            : 'home_reward_expires_suffix'.tr(namedArgs: {'date': expiresAt.toLocal().toString().split(' ').first});
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kTealDark,
            borderRadius: BorderRadius.circular(20),
            boxShadow: kShadowFloating,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('home_reward_journey_title'.tr(), style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w800))),
                Text('points_value'.tr(namedArgs: {'points': '$balance'}), style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? 'home_reward_journey_all_unlocked'.tr()
                    : 'home_reward_journey_remaining'.tr(namedArgs: {
                          'remaining': '$remaining',
                          'reward': (next['reward_name'] ?? 'home_mission_next_reward_fallback'.tr()).toString(),
                        }) +
                        expiryMessage,
                style: TextStyle(color: kWhite.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: target <= 0 ? 1 : (balance / target).clamp(0.0, 1.0), minHeight: 8, color: kGold, backgroundColor: kWhite.withValues(alpha: 0.2))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _quickAction(Icons.camera_alt_outlined, 'home_quick_scan'.tr(), widget.onScanReceipt),
                _quickAction(Icons.emoji_events_outlined, 'home_quick_rewards'.tr(), widget.onOpenRewards),
                _quickAction(Icons.map_outlined, 'home_quick_map'.tr(), widget.onOpenMap),
                _quickAction(Icons.groups_outlined, 'home_quick_community'.tr(), widget.onOpenCommunity),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: kWhite.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 2), Icon(icon, color: kWhite, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700))]),
      ),
    );
  }

  Widget _buildCurrentMission() {
    return FutureBuilder<dynamic>(
      future: Future.wait<dynamic>([_pointsFuture, _rewardsFuture]),
      builder: (context, snapshot) {
        final points = snapshot.hasData && snapshot.data![0] is Map ? Map<String, dynamic>.from(snapshot.data![0] as Map) : <String, dynamic>{};
        final rewards = snapshot.hasData && snapshot.data![1] is List ? List<Map<String, dynamic>>.from(snapshot.data![1] as List) : <Map<String, dynamic>>[];
        final balance = _toInt(points['availablePoints']);
        final next = rewards.where((reward) => _toInt(reward['value']) > balance).fold<Map<String, dynamic>?>(null, (current, reward) => current == null || _toInt(reward['value']) < _toInt(current['value']) ? reward : current);
        final remaining = next == null ? 0 : _toInt(next['value']) - balance;
        return Card(
          color: const Color(0xFFFFF7E8),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFE0A3), child: Icon(Icons.flag_outlined, color: Color(0xFF9A6500))),
            title: Text('home_mission_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              next == null
                  ? 'home_mission_default'.tr()
                  : 'home_mission_progress'.tr(namedArgs: {
                      'reward': (next['reward_name'] ?? 'home_mission_next_reward_fallback'.tr()).toString(),
                      'remaining': '$remaining',
                    }),
            ),
            trailing: const Icon(Icons.arrow_back_ios_new, size: 16),
            onTap: widget.onOpenRewards,
          ),
        );
      },
    );
  }

  Widget _buildNearbyPreview() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _storesFuture,
      builder: (context, snapshot) {
        final stores = (snapshot.data ?? const <Map<String, dynamic>>[]).take(3).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Text('nearby_stores'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), TextButton.icon(onPressed: widget.onOpenMap, icon: const Icon(Icons.map_outlined, size: 17), label: Text('map'.tr()))]),
            if (stores.isEmpty) Text('nearby_stores_loading'.tr()) else
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stores.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    return SizedBox(width: 220, child: Card(child: ListTile(dense: true, leading: const Icon(Icons.storefront_outlined, color: kTeal), title: Text((store['name'] ?? '-').toString(), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text((store['category'] ?? 'store'.tr()).toString()), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreDetailsScreen(store: store))))));
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  Widget _buildBanner() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _billboardAdsFuture,
      builder: (context, snapshot) {
        final ads = snapshot.data ?? const <Map<String, dynamic>>[];
        if (ads.isNotEmpty) {
          return AdsBannerSlider(
            ads: ads,
            height: 170,
            onAdTap: _handleBillboardTap,
            onAdImpression: (ad) {
              final id = (ad['id'] ?? '').toString();
              if (id.isNotEmpty) CompanyServerService.trackBillboardImpression(id).catchError((_) {});
            },
          );
        }
        if (snapshot.hasError) {
          return _buildDefaultBanner();
        }
        if (snapshot.hasData && ads.isEmpty) {
          return _buildDefaultBanner();
        }
        return Container(
          height: 170,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kTealDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const CircularProgressIndicator(color: kGold),
        );
      },
    );
  }

  Widget _buildDefaultBanner() {
    final String bannerText = _bannerKeys[_bannerIndex].tr();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: <Color>[kTealDark, kTeal],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: kShadowFloating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'home_banner_title'.tr(),
            style: kDisplayTextStyle(size: 20, weight: FontWeight.w700, color: kWhite),
          ),
          const SizedBox(height: 8),
          Text(
            bannerText,
            style: kBodyTextStyle(size: 13, color: kWhite.withValues(alpha: 0.92), height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _bannerIndex = (_bannerIndex + 1) % _bannerKeys.length;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kWhite,
                  side: BorderSide(color: kWhite.withValues(alpha: 0.8)),
                ),
                child: Text('home_banner_next'.tr()),
              ),
              const SizedBox(width: 8),
              Text(
                '${_bannerIndex + 1}/${_bannerKeys.length}',
                style: kBodyTextStyle(size: 12, color: kWhite.withValues(alpha: 0.86)),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                    child: Image.network(imageUrl, width: double.infinity, height: 180, fit: BoxFit.cover),
                  ),
                if (!imageUrl.startsWith('http') && assetPath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(assetPath, width: double.infinity, height: 180, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 14),
                Text(
                  (ad['description'] ?? ad['title'] ?? 'home_billboard_ad_default_title'.tr()).toString(),
                  style: kDisplayTextStyle(size: 20, weight: FontWeight.w700),
                ),
                if ((ad['category'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text((ad['category']).toString(), style: kBodyTextStyle(color: kTeal, weight: FontWeight.w600)),
                ],
                if ((ad['location'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text((ad['location']).toString(), style: kBodyTextStyle(color: kInk.withValues(alpha: 0.7))),
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

  Widget _buildSearchBar() {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'home_search_hint'.tr(),
          prefixIcon: const Icon(Icons.search, color: kTeal),
          filled: true,
          fillColor: kWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return KupunaTopTabs(
      tabs: <String>[
        'home_tab_discover'.tr(),
        'home_tab_offers'.tr(),
        'home_tab_peer_ads'.tr(),
      ],
      activeIndex: _activeTab,
      onSelect: (index) {
        setState(() {
          _activeTab = index;
        });
      },
    );
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
          final categories = sourceRows
              .map((e) => (e['category'] ?? '').toString().trim())
              .where((v) => v.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          final filteredRows = sourceRows.where((store) {
            final name = (store['name'] ?? '').toString().toLowerCase();
            final category = (store['category'] ?? '').toString();
            final matchesKeyword = keyword.isEmpty || name.contains(keyword);
            final matchesCategory = _selectedDiscoverCategory.isEmpty || category == _selectedDiscoverCategory;
            return matchesKeyword && matchesCategory;
          }).toList(growable: false)
            ..sort((a, b) {
              final distanceA = _distanceKm(_customerLat, _customerLng, _toDouble(a['lat']), _toDouble(a['lng']));
              final distanceB = _distanceKm(_customerLat, _customerLng, _toDouble(b['lat']), _toDouble(b['lng']));
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
                          _selectedDiscoverCategory = _selectedDiscoverCategory == cat ? '' : cat;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, icon: const Icon(Icons.view_list), label: Text('home_discover_list'.tr())),
                  ButtonSegment<bool>(value: true, icon: const Icon(Icons.map_outlined), label: Text('home_discover_map'.tr())),
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
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
          ),
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
                      point: LatLng(_toDouble(store['lat']), _toDouble(store['lng'])),
                      child: Tooltip(
                        message: (store['name'] ?? '').toString(),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 36),
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
      children: stores.take(10).map((store) {
        final distance = _distanceKm(sourceLat, sourceLng, _toDouble(store['lat']), _toDouble(store['lng']));
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined, color: kTealDark),
            title: Text((store['name'] ?? '').toString()),
            subtitle: Text(
              'home_discover_store_distance'.tr(namedArgs: {
                'category': (store['category'] ?? '-').toString(),
                'distance': distance.toStringAsFixed(2),
              }),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StoreDetailsScreen(store: store)),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  double _distanceKm(double? fromLat, double? fromLng, double toLat, double toLng) {
    final originLat = fromLat ?? _tripoliDefaultCenter.latitude;
    final originLng = fromLng ?? _tripoliDefaultCenter.longitude;
    return Geolocator.distanceBetween(originLat, originLng, toLat, toLng) / 1000;
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
          final rows = snapshot.data!.where((row) {
            final title = (row['description'] ?? row['title'] ?? '').toString().toLowerCase();
            final category = (row['category'] ?? '').toString().toLowerCase();
            final ownerType = (row['ownerType'] ?? row['sourceType'] ?? '').toString().toLowerCase();

            if (sourceType != null && !ownerType.contains(sourceType)) {
              return false;
            }

            if (keyword.isEmpty) {
              return true;
            }
            return title.contains(keyword) || category.contains(keyword);
          }).toList(growable: false);

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyKey.tr()),
            );
          }

          return Column(
            children: rows.take(6).map((offer) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KupunaOfferCard(
                  offer: <String, dynamic>{
                    ...offer,
                    'title': (offer['description'] ?? offer['title'] ?? 'new_offer'.tr()).toString(),
                    'subtitle': (offer['category'] ?? '').toString(),
                  },
                ),
              );
            }).toList(growable: false),
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
          final rows = snapshot.data!.where((row) {
            final ownerType = (row['ownerType'] ?? row['sourceType'] ?? '').toString().toLowerCase();
            final title = (row['description'] ?? row['title'] ?? '').toString().toLowerCase();
            final category = (row['category'] ?? '').toString().toLowerCase();
            final isPeer = ownerType.contains('peer') || ownerType.contains('individual');
            if (!isPeer) {
              return false;
            }
            if (keyword.isEmpty) {
              return true;
            }
            return title.contains(keyword) || category.contains(keyword);
          }).toList(growable: false);

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('home_peer_ads_empty'.tr()),
            );
          }

          return Column(
            children: rows.take(6).map((offer) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KupunaOfferCard(
                  offer: <String, dynamic>{
                    ...offer,
                    'title': (offer['content'] ?? offer['description'] ?? 'new_offer'.tr()).toString(),
                    'subtitle': (offer['targetValue'] ?? offer['category'] ?? '').toString(),
                    'sourceType': 'peer',
                  },
                ),
              );
            }).toList(growable: false),
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
                      Text(title, style: kDisplayTextStyle(size: 16, weight: FontWeight.w700, color: kInk)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: kBodyTextStyle(color: kInk.withValues(alpha: 0.6), size: 12)),
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
