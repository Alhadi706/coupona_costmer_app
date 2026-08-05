enum LedgerEntryType {
  cashbackEarned,
  pointsEarned,
  pointsRedeemed,
}

class LedgerEntry {
  LedgerEntry({
    required this.ownerId,
    required this.type,
    required this.amount,
    required this.points,
    required this.reference,
    required this.createdAt,
  });

  final String ownerId;
  final LedgerEntryType type;
  final double amount;
  final int points;
  final String reference;
  final DateTime createdAt;

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      ownerId: map['ownerId'] as String? ?? '',
      type: _parseType(map['type'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      reference: map['reference'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'type': type.name,
      'amount': amount,
      'points': points,
      'reference': reference,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static LedgerEntryType _parseType(String? type) {
    switch (type) {
      case 'cashbackEarned':
        return LedgerEntryType.cashbackEarned;
      case 'pointsEarned':
        return LedgerEntryType.pointsEarned;
      case 'pointsRedeemed':
        return LedgerEntryType.pointsRedeemed;
      default:
        return LedgerEntryType.pointsEarned;
    }
  }
}
