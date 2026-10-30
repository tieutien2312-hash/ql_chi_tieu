import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onRefreshNeeded;

  const HomeScreen({super.key, required this.onRefreshNeeded});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _totalBalance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  List<Account> _accounts = [];
  List<TransactionModel> _recentTransactions = [];
  bool _isLoading = true;

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final accounts = await ApiService.getAccounts();
    final transactions = await ApiService.getTransactions();

    double totalBalance = 0.0;
    for (var acc in accounts) {
      totalBalance += acc.balance;
    }

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (var tx in transactions) {
      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
      } else if (tx.type == 'EXPENSE') {
        totalExpense += tx.amount;
      }
    }

    setState(() {
      _totalBalance = totalBalance;
      _totalIncome = totalIncome;
      _totalExpense = totalExpense;
      _accounts = accounts;
      _recentTransactions = transactions.take(10).toList();
      _isLoading = false;
    });
  }

  Account? _getAccountForTx(dynamic accountId) {
    try {
      return _accounts.firstWhere((acc) => acc.id.toString() == accountId.toString());
    } catch (_) {
      return null;
    }
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryCyan,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xin chào!', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    SizedBox(height: 2),
                    Text('Quản lý tài chính cá nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryCyan),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy').format(DateTime.now()),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Total Balance Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryCyan, AppTheme.primaryCyanDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng số dư tài khoản', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_currencyFormat.format(_totalBalance)} VNĐ',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Thu nhập', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('+${_currencyFormat.format(_totalIncome)} đ', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chi tiêu', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('−${_currencyFormat.format(_totalExpense)} đ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Accounts Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ví & Tài khoản ngân hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                TextButton(
                  onPressed: () {},
                  child: const Text('Xem tất cả', style: TextStyle(color: AppTheme.primaryCyanDark)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Accounts Horizontal List
            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppTheme.primaryCyan)))
                : _accounts.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text('Chưa có tài khoản nào. Hãy thêm ví hoặc tài khoản.', style: TextStyle(color: AppTheme.textSecondary))),
                        ),
                      )
                    : SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _accounts.length,
                          itemBuilder: (context, index) {
                            final acc = _accounts[index];
                            return Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.borderLight),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(acc.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                                      const Icon(Icons.account_balance, color: AppTheme.primaryCyan, size: 18),
                                    ],
                                  ),
                                  Text(_maskAccountNumber(acc.accountNumber), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  Text(
                                    '${_currencyFormat.format(acc.balance)} đ',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryCyanDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
            const SizedBox(height: 24),

            // Recent Transactions Section
            const Text('Giao dịch gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
                : _recentTransactions.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text('Chưa có giao dịch nào được ghi nhận từ API.', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = _recentTransactions[index];
                          final isIncome = tx.type == 'INCOME';
                          final acc = _getAccountForTx(tx.accountId);
                          String timeOnly = tx.transactionTime;
                          try {
                            final p = tx.transactionTime.split(' ');
                            if (p.isNotEmpty) timeOnly = p[0];
                          } catch (_) {}

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.borderLight)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                                child: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIncome ? AppTheme.successGreen : AppTheme.errorRed,
                                  size: 20,
                                ),
                              ),
                              title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${tx.transactionTime} · ${tx.category ?? 'Khác'} ${acc != null ? '(${acc.bankName})' : ''}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              trailing: Text(
                                '${isIncome ? '+' : '−'}${_currencyFormat.format(tx.amount)} đ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isIncome ? AppTheme.successGreen : AppTheme.errorRed,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
