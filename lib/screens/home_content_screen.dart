import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/category_bar.dart'; // استيراد صحيح حسب هيكل المشروع
import '../widgets/map_bar.dart'; // استيراد صحيح حسب هيكل المشروع
import '../services/company_server_service.dart';

class HomeContentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(Map<String, dynamic> category) onCategoryTap;
  final VoidCallback onMapTap;
  final VoidCallback onViewAllOffers;
  const HomeContentScreen({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    required this.onMapTap,
    required this.onViewAllOffers,
  });

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final TextEditingController _searchController = TextEditingController();

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
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFf4fbff), Color(0xFFdbeeff)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 14),
              _buildSearchBar(),
              const SizedBox(height: 14),
              _buildQuickStats(),
              const SizedBox(height: 14),
              _buildCategorySection(),
              const SizedBox(height: 14),
              _buildFeaturedOffersSection(),
              const SizedBox(height: 14),
              _buildMapSection(),
              const SizedBox(height: 14),
              _buildPointsSummary(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D5C8D), Color(0xFF2A8FBF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'home_hero_title'.tr(),
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'home_hero_subtitle'.tr(),
            style: TextStyle(color: Color(0xFFE5F6FF), height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.onMapTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D5C8D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.near_me),
                label: Text('nearby_stores'.tr()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'home_last_updated_now'.tr(),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 1.5,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'home_search_hint'.tr(),
          prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: Stream.periodic(const Duration(seconds: 6))
          .asyncMap((_) => CompanyServerService.getCounts())
          .startWithFuture(CompanyServerService.getCounts()),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final offersCount = _toInt(data['offers']);
        final rewardsCount = _toInt(data['rewards']);

        return Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.local_offer,
                title: 'active_offers'.tr(),
                value: offersCount > 0 ? '$offersCount' : '--',
                color: const Color(0xFF0A7C9E),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                icon: Icons.emoji_events,
                title: 'available_points'.tr(),
                value: rewardsCount > 0 ? '$rewardsCount' : '--',
                color: const Color(0xFF1E8A63),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySection() {
    return _SectionCard(
      title: 'categories'.tr(),
      subtitle: 'choose_category_interest'.tr(),
      child: CategoryBar(
        categories: widget.categories,
        height: 96,
        iconSize: 34,
        fontSize: 13,
        onCategoryTap: widget.onCategoryTap,
      ),
    );
  }

  Widget _buildFeaturedOffersSection() {
    return _SectionCard(
      title: 'featured_offers'.tr(),
      subtitle: 'best_three_offers_now'.tr(),
      action: TextButton(
        onPressed: widget.onViewAllOffers,
        child: Text('view_all_offers'.tr()),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 6))
            .asyncMap((_) => CompanyServerService.getOffers())
            .startWithFuture(CompanyServerService.getOffers()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final offers = snapshot.data!;
          if (offers.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('no_offers_available_now'.tr()),
            );
          }

          final keyword = _searchController.text.trim().toLowerCase();
          final filtered = offers.where((offer) {
            if (keyword.isEmpty) return true;
            final description = (offer['description'] ?? '').toString().toLowerCase();
            final category = (offer['category'] ?? '').toString().toLowerCase();
            final storeName = (offer['storeName'] ?? '').toString().toLowerCase();
            return description.contains(keyword) || category.contains(keyword) || storeName.contains(keyword);
          }).toList();

          if (filtered.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('no_search_results_current'.tr()),
            );
          }

          return Column(
            children: filtered.take(3).map((offer) {
              final discount = (offer['discountValue'] ?? offer['percent'] ?? '').toString();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE6F5FF),
                  child: Icon(Icons.local_offer, color: Colors.blue.shade700),
                ),
                title: Text((offer['description'] ?? 'new_offer'.tr()).toString()),
                subtitle: Text(
                  'offer_category_value'.tr(namedArgs: {
                    'category': ((offer['category'] ?? 'other').toString()).tr(),
                  }),
                ),
                trailing: discount.isEmpty
                    ? const Icon(Icons.arrow_forward_ios, size: 16)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2D6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildMapSection() {
    return _SectionCard(
      title: 'map'.tr(),
      subtitle: 'nearest_stores_around_you'.tr(),
      action: TextButton(
        onPressed: widget.onMapTap,
        child: Text('expand'.tr()),
      ),
      child: SizedBox(
        height: 170,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: MapBar(onExpand: widget.onMapTap),
        ),
      ),
    );
  }

  Widget _buildPointsSummary() {
    return _SectionCard(
      title: 'points_summary'.tr(),
      subtitle: 'take_action_faster'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('points_remaining_reward'.tr(namedArgs: {'points': '12', 'reward': '30'})),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: 0.6,
              backgroundColor: const Color(0xFFDCEBFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E8A63)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                backgroundColor: const Color(0xFFEAF7EF),
                label: Text('coupon_value_label'.tr(namedArgs: {'value': '10'})),
                avatar: const Icon(Icons.card_giftcard, size: 18),
              ),
              Chip(
                backgroundColor: const Color(0xFFFFF4E3),
                label: Text('free_gift'.tr()),
                avatar: const Icon(Icons.redeem, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
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