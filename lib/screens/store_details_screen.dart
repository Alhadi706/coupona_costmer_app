import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class StoreDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreDetailsScreen({super.key, required this.store});

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _details;
  bool _loading = false;
  Object? _error;

  String _value(String key) => (widget.store[key] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final merchantId = _value('merchantId');
    if (merchantId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await CompanyServerService.getStoreDetails(merchantId);
      if (!mounted) return;
      setState(() => _details = details);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _merchant {
    final payload = _details?['merchant'];
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{
            'name': widget.store['name'],
            'phone': widget.store['phone'],
            'location': widget.store['location'],
            'pointValue': widget.store['pointValue'],
            'pointTier': widget.store['pointTier'],
          };
  }

  List<Map<String, dynamic>> _rows(String key) {
    final value = _details?[key];
    if (value is! List) return const [];
    return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = (_merchant['name'] ?? _value('name')).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'store_details_title'.tr() : name),
        backgroundColor: kTeal,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.storefront_outlined),
              text: 'store_tab_overview'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.inventory_2_outlined),
              text: 'store_tab_products'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.local_offer_outlined),
              text: 'store_tab_offers'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.card_giftcard_outlined),
              text: 'store_tab_rewards'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.hub_outlined),
              text: 'store_tab_coalitions'.tr(),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            MaterialBanner(
              content: Text('store_details_load_error'.tr()),
              actions: [
                TextButton(onPressed: _loadDetails, child: Text('retry'.tr())),
              ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildProducts(),
                _buildOffers(),
                _buildRewards(),
                _buildCoalitions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final merchant = _merchant;
    final branches = _rows('branches');
    final category = _value('category');
    final pointValue =
        merchant['pointValue'] ?? widget.store['pointValue'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kTealDark,
            borderRadius: BorderRadius.circular(kRadiusCardLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront, size: 52, color: kMint),
              const SizedBox(height: 10),
              Text(
                (merchant['name'] ?? _value('name')).toString(),
                style: kDisplayTextStyle(size: 24, color: kWhite),
              ),
              if (category.isNotEmpty)
                Text(
                  category,
                  style: kBodyTextStyle(color: kWhite.withValues(alpha: 0.75)),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _factChip(
                    Icons.loyalty_outlined,
                    _pointTierLabel(merchant['pointTier']),
                    kGold,
                  ),
                  _factChip(
                    Icons.payments_outlined,
                    'store_points_rate'.tr(namedArgs: {'value': '$pointValue'}),
                    kMint,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _summaryCounts(),
        if ((merchant['phone'] ?? '').toString().isNotEmpty)
          _infoTile(Icons.phone_outlined, merchant['phone'].toString()),
        if ((merchant['commercialRegistration'] ?? _value('description'))
            .toString()
            .isNotEmpty)
          _infoTile(
            Icons.badge_outlined,
            (merchant['commercialRegistration'] ?? _value('description'))
                .toString(),
          ),
        const SizedBox(height: 16),
        Text('store_branches_title'.tr(), style: kDisplayTextStyle(size: 18)),
        const SizedBox(height: 8),
        if (branches.isEmpty)
          _branchCard(<String, dynamic>{
            'name': _value('branchName').isEmpty
                ? _value('name')
                : _value('branchName'),
            'address': merchant['location'] ?? _value('location'),
            'lat': widget.store['lat'],
            'lng': widget.store['lng'],
          })
        else
          ...branches.map(_branchCard),
      ],
    );
  }

  Widget _summaryCounts() {
    final counts = [
      (
        Icons.inventory_2_outlined,
        _rows('products').length,
        'store_tab_products'.tr(),
      ),
      (
        Icons.local_offer_outlined,
        _rows('offers').length,
        'store_tab_offers'.tr(),
      ),
      (
        Icons.card_giftcard_outlined,
        _rows('rewards').length,
        'store_tab_rewards'.tr(),
      ),
    ];
    return Row(
      children: counts.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(kRadiusCardCompact),
              border: Border.all(color: kLine),
            ),
            child: Column(
              children: [
                Icon(item.$1, color: kTeal),
                Text(
                  '${item.$2}',
                  style: kPointsNumberStyle(size: 20, color: kInk),
                ),
                Text(
                  item.$3,
                  style: kBodyTextStyle(size: 11, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProducts() {
    final products = _rows('products');
    if (products.isEmpty) {
      return _empty('store_products_empty'.tr(), Icons.inventory_2_outlined);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 190,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _image(product['imageUrl'], Icons.inventory_2_outlined, 110),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if ((product['brandName'] ?? '').toString().isNotEmpty)
                      Text(
                        product['brandName'].toString(),
                        style: kBodyTextStyle(size: 12, color: kTeal),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOffers() {
    final offers = _rows('offers');
    if (offers.isEmpty) {
      return _empty('store_offers_empty'.tr(), Icons.local_offer_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 56,
              child: _image(offer['imageUrl'], Icons.local_offer_outlined, 56),
            ),
            title: Text(
              offer['title']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(_offerSubtitle(offer)),
          ),
        );
      },
    );
  }

  Widget _buildRewards() {
    final rewards = _rows('rewards');
    if (rewards.isEmpty) {
      return _empty('store_rewards_empty'.tr(), Icons.card_giftcard_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rewards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final reward = rewards[index];
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 56,
              child: _image(
                reward['imageUrl'],
                Icons.card_giftcard_outlined,
                56,
              ),
            ),
            title: Text(
              reward['name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(reward['description']?.toString() ?? ''),
            trailing: Chip(
              label: Text(
                'points_value'.tr(
                  namedArgs: {'points': '${reward['points'] ?? 0}'},
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoalitions() {
    final coalitions = _rows('coalitions');
    if (coalitions.isEmpty) {
      return _empty('store_coalitions_empty'.tr(), Icons.hub_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: coalitions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final coalition = coalitions[index];
        final isPublic = coalition['type'] == 'public';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (isPublic ? kGold : kTeal).withValues(
                alpha: 0.12,
              ),
              child: Icon(
                isPublic ? Icons.public : Icons.groups_outlined,
                color: isPublic ? kGold : kTeal,
              ),
            ),
            title: Text(
              coalition['name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              isPublic
                  ? 'store_coalition_public'.tr()
                  : 'store_coalition_private'.tr(),
            ),
          ),
        );
      },
    );
  }

  Widget _branchCard(Map<String, dynamic> branch) {
    final address = (branch['address'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined, color: kTeal),
        title: Text(
          branch['name']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: address.isEmpty ? null : Text(address),
        trailing: IconButton(
          tooltip: 'store_directions'.tr(),
          onPressed: () => _openDirections(branch),
          icon: const Icon(Icons.directions_outlined),
        ),
      ),
    );
  }

  Widget _factChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label, style: TextStyle(color: color)),
      backgroundColor: kWhite.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }

  Widget _infoTile(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kTealDark),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _empty(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: kTeal.withValues(alpha: 0.65)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _image(dynamic rawUrl, IconData fallback, double height) {
    final url = (rawUrl ?? '').toString();
    if (url.isEmpty) {
      return Container(
        height: height,
        color: kTeal.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: Icon(fallback, color: kTeal),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: kTeal.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: Icon(fallback, color: kTeal),
        ),
      ),
    );
  }

  String _pointTierLabel(dynamic tier) {
    return switch (tier?.toString()) {
      'gold' => 'store_points_gold'.tr(),
      'silver' => 'store_points_silver'.tr(),
      _ => 'store_points_bronze'.tr(),
    };
  }

  String _offerSubtitle(Map<String, dynamic> offer) {
    final parts = [
      offer['category']?.toString(),
      offer['discountValue']?.toString(),
      offer['price']?.toString(),
    ].whereType<String>().where((value) => value.isNotEmpty);
    return parts.join(' • ');
  }

  Future<void> _openDirections(Map<String, dynamic> location) async {
    final lat = _toDouble(location['lat']);
    final lng = _toDouble(location['lng']);
    final address =
        (location['address'] ?? location['location'] ?? _merchant['name'] ?? '')
            .toString();
    final destination = lat != 0 && lng != 0
        ? '$lat,$lng'
        : Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
