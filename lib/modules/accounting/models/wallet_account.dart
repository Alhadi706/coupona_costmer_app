class WalletAccount {
  WalletAccount({
    required this.ownerId,
    required this.balance,
    required this.currency,
    required this.updatedAt,
  });

  final String ownerId;
  final double balance;
  final String currency;
  final DateTime updatedAt;

  factory WalletAccount.fromMap(Map<String, dynamic> map) {
    return WalletAccount(
      ownerId: map['ownerId'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'SAR',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'balance': balance,
      'currency': currency,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
