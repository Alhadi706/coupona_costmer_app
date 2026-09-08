import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Renders subtle 3D floating background illustrations (coins, gifts, coupons, charts)
/// scattered across the rewards map canvas with low opacity for visual depth.
class MapBackgroundDecorations extends StatelessWidget {
  final double totalHeight;

  const MapBackgroundDecorations({
    super.key,
    required this.totalHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Generate scattered floating 3D icons along vertical height
    final double step = 180.0;
    final int count = (totalHeight / step).ceil().clamp(3, 30);

    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: Stack(
        children: [
          for (int i = 0; i < count; i++) ...[
            // Left floating decoration
            Positioned(
              top: 40.0 + i * step + (i.isEven ? 0 : 35),
              left: 16.0 + (i * 23) % 45,
              child: _Floating3DDecorationItem(
                index: i,
                isLeft: true,
              ),
            ),
            // Right floating decoration
            Positioned(
              top: 90.0 + i * step + (i.isOdd ? 0 : 30),
              right: 18.0 + (i * 31) % 50,
              child: _Floating3DDecorationItem(
                index: i + 1,
                isLeft: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Floating3DDecorationItem extends StatelessWidget {
  final int index;
  final bool isLeft;

  const _Floating3DDecorationItem({
    required this.index,
    required this.isLeft,
  });

  IconData get _icon {
    final mod = index % 5;
    if (mod == 0) return Icons.monetization_on_rounded; // 3D Coin
    if (mod == 1) return Icons.card_giftcard_rounded; // Mystery Gift Box
    if (mod == 2) return Icons.confirmation_num_rounded; // 3D Coupon
    if (mod == 3) return Icons.trending_up_rounded; // Growth / Chart Element
    return Icons.stars_rounded; // Gold Star
  }

  Color get _baseColor {
    final mod = index % 5;
    if (mod == 0 || mod == 4) return kGold;
    if (mod == 1) return kTeal;
    if (mod == 2) return kIndigo;
    return kMint;
  }

  @override
  Widget build(BuildContext context) {
    final angle = ((index % 4) - 1.5) * 0.25;
    final scale = 0.85 + (index % 3) * 0.15;
    final color = _baseColor;

    return Transform.rotate(
      angle: angle,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: 0.18, // Low opacity for subtle non-distracting background depth
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.6),
                  color.withValues(alpha: 0.1),
                ],
                radius: 0.85,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Icon(
              _icon,
              size: 32,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
