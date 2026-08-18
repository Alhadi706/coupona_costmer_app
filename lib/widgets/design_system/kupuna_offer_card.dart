import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

enum OfferSourceBadge {
  none,
  brand,
  peer,
}

class KupunaOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback? onTap;

  const KupunaOfferCard({
    super.key,
    required this.offer,
    this.onTap,
  });

  OfferSourceBadge _sourceFromOffer(Map<String, dynamic> data) {
    final String sourceType = (data['sourceType'] ?? data['ownerType'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase();
    final bool isPeer = sourceType.contains('peer') || sourceType.contains('individual') || sourceType.contains('فرد');
    final bool isBrand = sourceType.contains('brand') || sourceType.contains('علامة');
    if (isPeer) return OfferSourceBadge.peer;
    if (isBrand) return OfferSourceBadge.brand;
    return OfferSourceBadge.none;
  }

  @override
  Widget build(BuildContext context) {
    final OfferSourceBadge source = _sourceFromOffer(offer);
    final String title = (offer['title'] ?? offer['description'] ?? 'Offer').toString();
    final String subtitle = (offer['subtitle'] ?? offer['category'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: Container(
        padding: const EdgeInsets.all(kPaddingCardCompact),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(kRadiusCard),
          border: Border.all(color: kLine, width: kBorderWidth),
        ),
        child: Row(
          children: [
            Container(
              width: kOfferImageSize,
              height: kOfferImageSize,
              decoration: BoxDecoration(
                color: kSand,
                borderRadius: BorderRadius.circular(kRadiusOfferImage),
                border: Border.all(color: kLine, width: kBorderWidth),
              ),
              child: const Icon(Icons.local_offer_outlined, color: kInk),
            ),
            const SizedBox(width: kGapTight),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kBodyTextStyle(
                      size: kOfferTitleFontSize,
                      weight: FontWeight.w500,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kBodyTextStyle(
                      size: kOfferSubtitleFontSize,
                      weight: FontWeight.w400,
                      color: kInk.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (source != OfferSourceBadge.none)
              _OfferBadge(source: source),
          ],
        ),
      ),
    );
  }
}

class _OfferBadge extends StatelessWidget {
  final OfferSourceBadge source;

  const _OfferBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color background;
    late final Color textColor;

    if (source == OfferSourceBadge.peer) {
      label = 'فرد';
      background = kGold;
      textColor = kInk;
    } else {
      label = 'علامة';
      background = kIndigo;
      textColor = kWhite;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kBadgePaddingHorizontal,
        vertical: kBadgePaddingVertical,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Text(
        label,
        style: kBodyTextStyle(
          size: kBadgeFontSize,
          weight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
