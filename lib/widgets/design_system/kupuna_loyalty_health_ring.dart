import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class KupunaLoyaltyHealthRing extends StatelessWidget {
  final double scorePercent;

  const KupunaLoyaltyHealthRing({
    super.key,
    required this.scorePercent,
  });

  @override
  Widget build(BuildContext context) {
    final double clamped = scorePercent.clamp(0, 100);
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: _LoyaltyRingPainter(progress: clamped / 100),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double inner = constraints.maxWidth * kLoyaltyInnerSizeFactor;
              return Container(
                width: inner,
                height: inner,
                decoration: const BoxDecoration(
                  color: kIndigo,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    clamped.toStringAsFixed(0),
                    style: kPointsNumberStyle(
                      size: kLoyaltyNumberFontSize,
                      color: kWhite,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoyaltyRingPainter extends CustomPainter {
  final double progress;

  const _LoyaltyRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - kLoyaltyRingStrokeWidth;
    final Rect ringRect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kLoyaltyRingStrokeWidth
      ..strokeCap = StrokeCap.round
      ..color = kWhite.withValues(alpha: 0.2);

    final Paint done = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kLoyaltyRingStrokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: const [kGold, kGold],
      ).createShader(ringRect);

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(ringRect, -math.pi / 2, progress * math.pi * 2, false, done);
  }

  @override
  bool shouldRepaint(covariant _LoyaltyRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
