import 'package:intl/intl.dart';

class TransactionModel {
  final dynamic id;
  final dynamic accountId;
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
    String rawTime = map['transactionTime'] ?? map['TransactionTime'] ?? '';
    String formattedTime = rawTime;
    try {
      if (rawTime.contains('T') || (rawTime.contains('-') && !rawTime.contains('/'))) {
        final dt = DateTime.parse(rawTime).toLocal();
        formattedTime = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      }
    } catch (_) {}

    return TransactionModel(
      id: map['id'] ?? map['Id'],
      accountId: map['accountId'] ?? map['AccountId'] ?? map['account_id'] ?? 0,
      type: map['type'] ?? map['Type'] ?? 'EXPENSE',
      amount: (map['amount'] ?? map['Amount'] ?? 0.0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? map['BalanceAfter'] ?? 0.0).toDouble(),
      description: map['description'] ?? map['Description'] ?? '',
      transactionTime: formattedTime,
      source: map['source'] ?? map['Source'] ?? 'manual',
      category: map['category'] ?? map['Category'] ?? map['categoryName'] ?? map['CategoryName'] ?? 'Khác',
    );
  }
}
