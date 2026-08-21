import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/design_tokens.dart';

class StoreDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> store;

  const StoreDetailsScreen({super.key, required this.store});

  String _value(String key) => (store[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final name = _value('name');
    final category = _value('category');
    final description = _value('description');
    final branchName = _value('branchName');
    final phone = _value('phone');
    final location = _value('location');
    final distance = store['distanceKm'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'store_details_title'.tr() : name),
        backgroundColor: kTeal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.storefront, size: 72, color: kTeal),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          if (category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(
                avatar: const Icon(Icons.category_outlined, size: 18),
                label: Text(category),
              ),
            ),
          ],
          if (branchName.isNotEmpty) _infoTile(Icons.location_city, branchName),
          if (description.isNotEmpty) _infoTile(Icons.info_outline, description),
          if (location.isNotEmpty) _infoTile(Icons.location_on_outlined, location),
          if (phone.isNotEmpty) _infoTile(Icons.phone_outlined, phone),
          if (distance is num)
            _infoTile(
              Icons.near_me_outlined,
              '${distance.toStringAsFixed(2)} ${'home_discover_distance_unit'.tr()}',
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.map_outlined),
            label: Text('store_details_back_to_map'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kTealDark),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
