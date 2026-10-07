class TransactionModel {
  final int? id;
  final int accountId;
  final String type; // 'INCOME' or 'EXPENSE'
  final double amount;
  final double balanceAfter;
  final String description;
  final String transactionTime;
  final String source; // 'notification' or 'manual'
  final String? category;

  TransactionModel({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.transactionTime,
    required this.source,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'type': type,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'description': description,
      'transactionTime': transactionTime,
      'source': source,
      'category': category,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      accountId: map['accountId'] ?? 0,
      type: map['type'] ?? 'EXPENSE',
      amount: (map['amount'] ?? 0.0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      transactionTime: map['transactionTime'] ?? '',
      source: map['source'] ?? 'manual',
      category: map['category'] ?? 'Khác',
    );
  }
}
