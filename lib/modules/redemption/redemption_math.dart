class RedemptionMath {
  static const int pointsPerLyD = 10;

  static int pointsRequiredForCash(double cashValueLyD) {
    if (cashValueLyD <= 0) {
      return 0;
    }
    return (cashValueLyD * pointsPerLyD).round();
  }

  static double cashValueForPoints(int points) {
    return points * 0.1;
  }

  static Map<String, List<Map<String, dynamic>>> splitGiftCatalog({
    required int availablePoints,
    required List<Map<String, dynamic>> gifts,
  }) {
    final unlocked = <Map<String, dynamic>>[];
    final locked = <Map<String, dynamic>>[];

    for (final gift in gifts) {
      final cost = (gift['pointsCost'] ?? gift['required_points'] ?? 0) as num;
      final pointsCost = cost.toInt();
      final entry = <String, dynamic>{...gift};
      entry['pointsCost'] = pointsCost;
      final remaining = (pointsCost - availablePoints).clamp(0, pointsCost);
      entry['remainingPoints'] = remaining;
      final progress = pointsCost <= 0 ? 0.0 : (availablePoints / pointsCost).clamp(0.0, 1.0);
      entry['progress'] = progress;
      if (availablePoints >= pointsCost) {
        unlocked.add(entry);
      } else {
        locked.add(entry);
      }
    }

    return {
      'unlocked': unlocked,
      'locked': locked,
    };
  }
}
