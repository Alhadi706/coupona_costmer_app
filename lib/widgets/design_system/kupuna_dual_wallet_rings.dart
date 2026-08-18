import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class KupunaDualWalletRings extends StatelessWidget {
  final double merchantPoints;
  final double brandPoints;

  const KupunaDualWalletRings({
    super.key,
    required this.merchantPoints,
    required this.brandPoints,
  });

  @override
  Widget build(BuildContext context) {
    final double total = merchantPoints + brandPoints;
    final double outerProgress = total <= 0 ? 0 : merchantPoints / total;
    final double innerProgress = total <= 0 ? 0 : brandPoints / total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 190,
          height: 190,
          child: CustomPaint(
            painter: _DualRingPainter(
              outerProgress: outerProgress,
              innerProgress: innerProgress,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toStringAsFixed(0),
                    style: kPointsNumberStyle(
                      size: kWalletCenterNumberSize,
                      color: kInk,
                    ),
                  ),
                  Text(
                    'نقطة',
                    style: kBodyTextStyle(
                      size: kWalletCenterCaptionSize,
                      weight: FontWeight.w500,
                      color: kInk.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: kGapTight),
        Wrap(
          spacing: kGapList,
          runSpacing: kGapTight,
          alignment: WrapAlignment.center,
          children: [
            _LegendItem(color: kGold, label: 'تجار ${merchantPoints.toStringAsFixed(0)}'),
            _LegendItem(color: kMint, label: 'علامات ${brandPoints.toStringAsFixed(0)}'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: kWalletLegendDotSize,
          height: kWalletLegendDotSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: kBodyTextStyle(size: 12, weight: FontWeight.w500, color: kInk),
        ),
      ],
    );
  }
}

class _DualRingPainter extends CustomPainter {
  final double outerProgress;
  final double innerProgress;

  const _DualRingPainter({
    required this.outerProgress,
    required this.innerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double outerRadius = size.shortestSide / 2 - kWalletRingStrokeWidth;
    final double innerRadius = outerRadius - kWalletInnerInset;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kWalletRingStrokeWidth
      ..color = kLine;

    final Paint outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kWalletRingStrokeWidth
      ..color = kGold;

    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kWalletRingStrokeWidth
      ..color = kMint;

    canvas.drawCircle(center, outerRadius, track);
    canvas.drawCircle(center, innerRadius, track);

    final Rect outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final Rect innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    canvas.drawArc(outerRect, -math.pi / 2, outerProgress * math.pi * 2, false, outer);
    canvas.drawArc(innerRect, -math.pi / 2, innerProgress * math.pi * 2, false, inner);
  }

  @override
  bool shouldRepaint(covariant _DualRingPainter oldDelegate) {
    return oldDelegate.outerProgress != outerProgress ||
        oldDelegate.innerProgress != innerProgress;
  }
}
