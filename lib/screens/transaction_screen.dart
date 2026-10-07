import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _filterType = 'ALL'; // ALL, INCOME, EXPENSE
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final txs = await DatabaseHelper.instance.getTransactions();
    
    double income = 0;
    double expense = 0;
    for (var tx in txs) {
      if (tx.type == 'INCOME') {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }

    setState(() {
      _transactions = txs;
      _totalIncome = income;
      _totalExpense = expense;
      _isLoading = false;
    });
  }

  List<TransactionModel> get _filteredTransactions {
    if (_filterType == 'INCOME') {
      return _transactions.where((t) => t.type == 'INCOME').toList();
    } else if (_filterType == 'EXPENSE') {
      return _transactions.where((t) => t.type == 'EXPENSE').toList();
    }
    return _transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Chart Card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thống kê Thu / Chi',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: _totalIncome == 0 && _totalExpense == 0
                                  ? const Center(child: Text('Chưa có dữ liệu giao dịch để vẽ biểu đồ'))
                                  : BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        maxY: (_totalIncome > _totalExpense ? _totalIncome : _totalExpense) * 1.2 + 1000,
                                        barTouchData: BarTouchData(enabled: true),
                                        titlesData: FlTitlesData(
                                          show: true,
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              getTitlesWidget: (value, meta) {
                                                switch (value.toInt()) {
                                                  case 0:
                                                    return const Text('Thu nhập', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green));
                                                  case 1:
                                                    return const Text('Chi tiêu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red));
                                                  default:
                                                    return const Text('');
                                                }
                                              },
                                            ),
                                          ),
                                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        gridData: const FlGridData(show: false),
                                        borderData: FlBorderData(show: false),
                                        barGroups: [
                                          BarChartGroupData(
                                            x: 0,
                                            barRods: [
                                              BarChartRodData(
                                                toY: _totalIncome,
                                                color: Colors.green,
                                                width: 32,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ],
                                          ),
                                          BarChartGroupData(
                                            x: 1,
                                            barRods: [
                                              BarChartRodData(
                                                toY: _totalExpense,
                                                color: Colors.red,
                                                width: 32,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('Thu: ${_currencyFormat.format(_totalIncome)} đ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                Text('Chi: ${_currencyFormat.format(_totalExpense)} đ', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Filter chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lịch sử giao dịch',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ToggleButtons(
                          isSelected: [
                            _filterType == 'ALL',
                            _filterType == 'INCOME',
                            _filterType == 'EXPENSE',
                          ],
                          onPressed: (index) {
                            setState(() {
                              if (index == 0) _filterType = 'ALL';
                              else if (index == 1) _filterType = 'INCOME';
                              else if (index == 2) _filterType = 'EXPENSE';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(minHeight: 32, minWidth: 64),
                          children: const [
                            Text('Tất cả', style: TextStyle(fontSize: 12)),
                            Text('Thu', style: TextStyle(fontSize: 12)),
                            Text('Chi', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Transactions list
                    _filteredTransactions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('Không có giao dịch nào phù hợp.'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final tx = _filteredTransactions[index];
                              final isIncome = tx.type == 'INCOME';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                                    child: Icon(
                                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isIncome ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(
                                    tx.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${tx.transactionTime} • ${tx.source == 'notification' ? 'Tự động từ TB' : 'Thủ công'}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  trailing: Text(
                                    '${isIncome ? '+' : '-'} ${_currencyFormat.format(tx.amount)} đ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isIncome ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
