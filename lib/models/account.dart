class Account {
  final dynamic id;
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
      id: map['id'] ?? map['Id'],
      bankName: map['bankName'] ?? map['BankName'] ?? '',
      accountName: map['accountName'] ?? map['AccountName'] ?? '',
      accountNumber: map['accountNumber'] ?? map['AccountNumber'] ?? '',
      balance: (map['balance'] ?? map['Balance'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] ?? map['CreatedAt'] ?? '',
    );
  }

  Account copyWith({
    dynamic id,
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
