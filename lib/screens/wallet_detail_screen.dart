import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'bill_scan_screen.dart';

class WalletDetailScreen extends StatefulWidget {
  final Account account;

  const WalletDetailScreen({super.key, required this.account});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  
  // Month selector for Details tab
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allTxs = await ApiService.getTransactions();
    final cats = await ApiService.getCategories();
    final walletTxs = allTxs.where((tx) => tx.accountId.toString() == widget.account.id.toString()).toList();
    setState(() {
      _transactions = walletTxs;
      _categories = cats;
      _isLoading = false;
    });
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }

  void _showAddTransactionOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Thêm giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppTheme.primaryCyan, child: Icon(Icons.edit, color: Colors.white)),
                title: const Text('1. Nhập thủ công'),
                subtitle: const Text('Tự điền thông tin thu chi'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddManualTransactionDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.document_scanner, color: Colors.white)),
                title: const Text('2. Quét Bill (Hóa đơn)'),
                subtitle: const Text('Chụp hoặc chọn ảnh để AI đọc thông tin'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BillScanScreen()),
                  );
                  if (result == true) {
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddManualTransactionDialog() async {
    final categories = _categories;
    String selectedType = 'EXPENSE';
    String selectedCategory = categories.isNotEmpty ? categories.first.name : 'Khác';
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Thêm giao dịch ví ${widget.account.bankName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Chi tiêu')),
                            selected: selectedType == 'EXPENSE',
                            selectedColor: Colors.red.shade100,
                            onSelected: (selected) {
                              setDialogState(() => selectedType = 'EXPENSE');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Thu nhập')),
                            selected: selectedType == 'INCOME',
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              setDialogState(() => selectedType = 'INCOME');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)*'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat.name,
                          child: Text(cat.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedCategory = val!);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Ghi chú / Nội dung'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.white),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount > 0) {
                      final currentTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
                      final tx = TransactionModel(
                        accountId: widget.account.id!,
                        type: selectedType,
                        amount: amount,
                        balanceAfter: 0,
                        description: noteController.text.trim().isEmpty
                            ? (selectedType == 'INCOME' ? 'Thu nhập thủ công' : 'Chi tiêu thủ công')
                            : noteController.text.trim(),
                        transactionTime: currentTime,
                        source: 'manual',
                        category: selectedCategory,
                      );
                      await ApiService.insertTransaction(tx);
                      if (context.mounted) Navigator.pop(context);
                      _loadData();
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.account.bankName),
        backgroundColor: AppTheme.surfaceWhite,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryCyanDark,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryCyan,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Phân tích'),
            Tab(text: 'Chi tiết'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAnalysisTab(),
                _buildDetailTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionOptions,
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- TAB PHÂN TÍCH ---
  Widget _buildAnalysisTab() {
    Map<String, double> dailyNet = {};
    for (var tx in _transactions) {
      try {
        final parts = tx.transactionTime.split(' ');
        if (parts.isNotEmpty) {
          final dateStr = parts[0];
          double change = tx.type == 'INCOME' ? tx.amount : -tx.amount;
          dailyNet[dateStr] = (dailyNet[dateStr] ?? 0.0) + change;
        }
      } catch (_) {}
    }

    final sortedDates = dailyNet.keys.toList()..sort((a, b) {
      try {
        final p1 = a.split('/');
        final p2 = b.split('/');
        final dt1 = DateTime(int.parse(p1[2]), int.parse(p1[1]), int.parse(p1[0]));
        final dt2 = DateTime(int.parse(p2[2]), int.parse(p2[1]), int.parse(p2[0]));
        return dt1.compareTo(dt2);
      } catch (_) {
        return 0;
      }
    });

    List<FlSpot> spots = [];
    if (sortedDates.isEmpty) {
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    } else {
      for (int i = 0; i < sortedDates.length; i++) {
        spots.add(FlSpot(i.toDouble(), dailyNet[sortedDates[i]]!));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryCyan,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderLight)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primaryCyan.withOpacity(0.15),
                      child: const Icon(Icons.account_balance_wallet, color: AppTheme.primaryCyanDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.account.accountName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text('${widget.account.bankName} (${_maskAccountNumber(widget.account.accountNumber)})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    Text(
                      '${_currencyFormat.format(widget.account.balance)}đ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryCyanDark),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Biểu đồ biến động thu chi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Container(
              height: 220,
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < sortedDates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(sortedDates[idx].substring(0, 5), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primaryCyan,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryCyan.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Danh sách biến động số dư theo ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            sortedDates.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Chưa có biến động số dư nào.', style: TextStyle(color: AppTheme.textSecondary))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final net = dailyNet[date]!;
                      final isPositive = net >= 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.borderLight)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
                                  const SizedBox(width: 10),
                                  Text('Ngày $date', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                                ],
                              ),
                              Text(
                                '${isPositive ? '+' : ''}${_currencyFormat.format(net)} VNĐ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isPositive ? AppTheme.successGreen : AppTheme.errorRed,
                                ),
                              ),
                            ],
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

  // --- TAB CHI TIẾT ---
  Widget _buildDetailTab() {
    final filteredTransactions = _transactions.where((tx) {
      try {
        final parts = tx.transactionTime.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('/');
          if (dateParts.length == 3) {
            int m = int.parse(dateParts[1]);
            int y = int.parse(dateParts[2]);
            return m == _selectedMonth.month && y == _selectedMonth.year;
          }
        }
      } catch (_) {}
      return false;
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in filteredTransactions) {
      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }

    Map<String, List<TransactionModel>> grouped = {};
    for (var tx in filteredTransactions) {
      String dateKey = 'Khác';
      try {
        final p = tx.transactionTime.split(' ');
        if (p.isNotEmpty) dateKey = p[0];
      } catch (_) {}
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(tx);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Month Selector Header & Summary Cards (consistent with statistics screen)
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceWhite,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        });
                      },
                    ),
                    Text(
                      'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_downward, color: AppTheme.successGreen, size: 14),
                              ),
                              const SizedBox(width: 6),
                              const Text('Tổng thu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('+${_currencyFormat.format(totalIncome)}đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.successGreen)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_upward, color: AppTheme.errorRed, size: 14),
                              ),
                              const SizedBox(width: 6),
                              const Text('Tổng chi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('-${_currencyFormat.format(totalExpense)}đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.errorRed)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderLight),
        Expanded(
          child: filteredTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('Không có giao dịch trong tháng này.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primaryCyan,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final dateStr = sortedDates[index];
                      final dayTxs = grouped[dateStr]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              'Ngày $dateStr',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ),
                          ...dayTxs.map((tx) {
                            final isIncome = tx.type == 'INCOME';
                            String timeOnly = tx.transactionTime;
                            try {
                              final p = tx.transactionTime.split(' ');
                              if (p.length > 1) timeOnly = p[1];
                            } catch (_) {}

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppTheme.borderLight),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isIncome ? AppTheme.successGreen.withOpacity(0.15) : AppTheme.errorRed.withOpacity(0.15),
                                      child: Icon(
                                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                        color: isIncome ? AppTheme.successGreen : AppTheme.errorRed,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$timeOnly · ${tx.category ?? 'Khác'}',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${isIncome ? '+' : '−'}${_currencyFormat.format(tx.amount)}đ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isIncome ? AppTheme.successGreen : AppTheme.errorRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
