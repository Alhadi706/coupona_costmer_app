import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'marketplace_categories.dart';

class CustomerOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Future<void> Function(Map<String, dynamic> offer, String status) onStatusChanged;

  const CustomerOfferCard({
    super.key,
    required this.offer,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = (offer['title'] ?? '').toString();
    final description = (offer['description'] ?? '').toString();
    final category = (offer['category'] ?? '').toString();
    final sellerRaw = (offer['seller_name'] ?? '').toString();
    final seller = sellerRaw.isEmpty ? 'marketplace_seller_fallback'.tr() : sellerRaw;
    final price = (offer['price_lyd'] as num?)?.toDouble() ?? 0;
    final points = (offer['points_required'] as num?)?.toInt() ?? 0;
    final status = (offer['status'] ?? 'ACTIVE').toString();
    final isOwner = offer['is_owner'] == true;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: kTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: kBodyTextStyle(size: 16, weight: FontWeight.w800)),
                ),
                CustomerOfferStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: kBodyTextStyle(size: 14, color: kInk.withValues(alpha: 0.75))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text(marketplaceCategoryLabel(category))),
                Chip(label: Text('${price.toStringAsFixed(2)} ${'currency_lyd'.tr()}')),
                if (offer['accepts_points_trade'] == true)
                  Chip(
                    avatar: const Icon(Icons.stars, size: 16, color: kGold),
                    label: Text('$points ${'points'.tr()}'),
                  ),
                if (!isOwner) Chip(avatar: const Icon(Icons.person_outline, size: 16), label: Text(seller)),
              ],
            ),
            if (isOwner && status == 'ACTIVE') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onStatusChanged(offer, 'ARCHIVED'),
                    child: Text('archive'.tr()),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => onStatusChanged(offer, 'SOLD'),
                    child: Text('offer_status_sold'.tr()),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CustomerOfferStatusChip extends StatelessWidget {
  final String status;

  const CustomerOfferStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'SOLD' => ('offer_status_sold'.tr(), Colors.green),
      'ARCHIVED' => ('offer_status_archived'.tr(), Colors.grey),
      _ => ('offer_status_active'.tr(), kTeal),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}
