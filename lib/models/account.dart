class Account {
  final int? id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final double balance;
  final String createdAt;

  Account({
    this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.balance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bankName': bankName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'balance': balance,
      'createdAt': createdAt,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      bankName: map['bankName'] ?? '',
      accountName: map['accountName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] ?? '',
    );
  }

  Account copyWith({
    int? id,
    String? bankName,
    String? accountName,
    String? accountNumber,
    double? balance,
    String? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
