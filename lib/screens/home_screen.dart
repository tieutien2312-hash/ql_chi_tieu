import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_header.dart';
import 'transaction_screen.dart';

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
  bool _isBalanceVisible = true;

  DateTime _selectedDate = DateTime.now();

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Tạm thời giữ logic cũ nhưng tối ưu hóa tính toán
    final transactions = await ApiService.getTransactions();
    
    // Lọc và tính toán trên một luồng riêng nếu cần thiết, 
    // nhưng trước hết tối ưu hóa vòng lặp
    final filtered = transactions.where((tx) {
      try {
        final p = tx.transactionTime.split(' ')[0].split('/');
        final txDate = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        return txDate.month == _selectedDate.month && txDate.year == _selectedDate.year;
      } catch (_) {
        return false;
      }
    }).toList();

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    
    for (var tx in filtered) {
      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
      } else if (tx.type == 'EXPENSE') {
        totalExpense += tx.amount;
      }
    }

    final accounts = await ApiService.getAccounts();
    double totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);

    setState(() {
      _totalBalance = totalBalance;
      _totalIncome = totalIncome;
      _totalExpense = totalExpense;
      _accounts = accounts;
      _recentTransactions = filtered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryCyan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeHeader(
                  userName: 'Người dùng',
                  onNotificationTap: () {},
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
                        _loadData();
                      }),
                    ),
                    Text(DateFormat('MM/yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
                        _loadData();
                      }),
                    ),
                  ],
                ),
                _buildOverviewCard(),
                const SizedBox(height: 24),
                _buildRecentTransactionsSection(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Điều hướng trực tiếp tới TransactionScreen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TransactionScreen()),
          ).then((_) {
            // Load lại dữ liệu khi quay về từ màn hình thêm giao dịch
            _loadData();
          });
        },
        backgroundColor: AppTheme.primaryCyan,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173F49).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Tổng quan tài chính', style: TextStyle(color: Color(0xFF142F38), fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Thu nhập và chi tiêu', style: TextStyle(color: Color(0xFF75868D), fontSize: 12)),
                ],
              ),
              IconButton(
                icon: Icon(_isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF75868D), size: 20),
                onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        const Text('Thu nhập', style: TextStyle(color: Color(0xFF75868D), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_isBalanceVisible ? '${_currencyFormat.format(_totalIncome)} ₫' : '•••••••• ₫', style: const TextStyle(color: Color(0xFF142F38), fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(width: 1, height: 42, color: const Color(0xFFE8EFF2)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, color: AppTheme.primaryCyan, size: 16),
                          const SizedBox(width: 8),
                          const Text('Chi tiêu', style: TextStyle(color: Color(0xFF75868D), fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_isBalanceVisible ? '${_currencyFormat.format(_totalExpense)} ₫' : '•••••••• ₫', style: const TextStyle(color: Color(0xFF142F38), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giao dịch gần đây', style: TextStyle(color: Color(0xFF142F38), fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
            : _recentTransactions.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EFF2)),
                    ),
                    child: const Text(
                      'Hiện chưa ghi nhận chi thu tháng này',
                      style: TextStyle(color: Color(0xFF75868D), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = _recentTransactions[index];
                      final isIncome = tx.type == 'INCOME';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8EFF2))),
                        child: ListTile(
                          title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(tx.transactionTime, style: const TextStyle(fontSize: 12)),
                          trailing: Text('${isIncome ? '+' : '−'}${_currencyFormat.format(tx.amount)} ₫', style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red)),
                        ),
                      );
                    },
                  ),
      ],
    );
  }
}
