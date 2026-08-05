class AccountingRules {
  AccountingRules._();

  static const double cashbackRate = 0.05;
  static const int pointsPerUnit = 1;

  static double normalizeAmount(double amount) {
    if (amount.isNaN || amount.isInfinite) {
      throw const FormatException('Amount must be a finite number.');
    }
    if (amount <= 0) {
      throw const FormatException('Amount must be greater than zero.');
    }
    return double.parse(amount.toStringAsFixed(2));
  }

  static double calculateCashback(double purchaseAmount) {
    final double normalized = normalizeAmount(purchaseAmount);
    return double.parse((normalized * cashbackRate).toStringAsFixed(2));
  }

  static int calculatePoints(double purchaseAmount) {
    final double normalized = normalizeAmount(purchaseAmount);
    return (normalized * pointsPerUnit).floor();
  }

  static void validateRedemption({
    required int requestedPoints,
    required int availablePoints,
  }) {
    if (requestedPoints <= 0) {
      throw const FormatException('Requested points must be greater than zero.');
    }
    if (requestedPoints > availablePoints) {
      throw const FormatException('Requested points exceed available points.');
    }
  }
}
