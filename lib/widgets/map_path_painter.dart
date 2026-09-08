import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Custom painter for the vertical winding path connecting milestone centers on the full map.
class MapPathPainter extends CustomPainter {
  final List<Offset> centers;

  const MapPathPainter({required this.centers});

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;

    // 1. Outer soft glow background track
    final shadowPaint = Paint()
      ..color = kTeal.withValues(alpha: 0.15)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 2. Main branded winding path line
    final pathPaint = Paint()
      ..color = kTeal.withValues(alpha: 0.6)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 3. Highlighted active path line
    final activePaint = Paint()
      ..color = kGold
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fullPath = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final prev = centers[i - 1];
      final curr = centers[i];
      final controlY = (prev.dy + curr.dy) / 2;
      fullPath.cubicTo(prev.dx, controlY, curr.dx, controlY, curr.dx, curr.dy);
    }

    canvas.drawPath(fullPath, shadowPaint);
    canvas.drawPath(fullPath, pathPaint);

    // Draw active segment for initial nodes
    if (centers.length >= 2) {
      final activePath = Path()..moveTo(centers.first.dx, centers.first.dy);
      final prev = centers[0];
      final curr = centers[1];
      final controlY = (prev.dy + curr.dy) / 2;
      activePath.cubicTo(prev.dx, controlY, curr.dx, controlY, curr.dx, curr.dy);
      canvas.drawPath(activePath, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MapPathPainter oldDelegate) =>
      oldDelegate.centers != centers;
}

/// Custom painter for the horizontal winding preview path on the home screen card.
class HomePathPainter extends CustomPainter {
  final List<Offset> centers;

  const HomePathPainter({required this.centers});

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;

    final shadowPaint = Paint()
      ..color = kTeal.withValues(alpha: 0.12)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathPaint = Paint()
      ..color = kTeal.withValues(alpha: 0.5)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final prev = centers[i - 1];
      final curr = centers[i];
      final controlX = (prev.dx + curr.dx) / 2;
      path.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant HomePathPainter oldDelegate) =>
      oldDelegate.centers != centers;
}
