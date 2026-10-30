import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MonthlyStat {
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;
  final int expenseCount;
  final Map<String, double> categoryExpenses;
  final bool hasData;

  MonthlyStat({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.expenseCount,
    required this.categoryExpenses,
    required this.hasData,
  });

  String get label => 'Tháng $month/$year';
  String get shortLabel => 'T$month/$year';
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _chartMode = 'MONTH'; // 'DAY', 'MONTH', 'YEAR'
  String _categoryViewType = 'EXPENSE'; // 'EXPENSE' or 'INCOME'

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final txs = await ApiService.getTransactions();
      final cats = await ApiService.getCategories();
      setState(() {
        _transactions = txs;
        _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải dữ liệu thống kê từ cơ sở dữ liệu. Vui lòng thử lại.';
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth--;
      if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth++;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      }
    });
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.isNotEmpty) {
        final dParts = parts[0].split('/');
        if (dParts.length == 3) {
          int day = int.parse(dParts[0]);
          int month = int.parse(dParts[1]);
          int year = int.parse(dParts[2]);
          int hour = 0;
          int minute = 0;
          if (parts.length > 1) {
            final tParts = parts[1].split(':');
            if (tParts.length >= 2) {
              hour = int.parse(tParts[0]);
              minute = int.parse(tParts[1]);
            }
          }
          return DateTime(year, month, day, hour, minute);
        }
      }
    } catch (_) {}
    return null;
  }

  MonthlyStat? _getStatFor(int year, int month) {
    final txs = _transactions.where((tx) {
      final dt = _parseDate(tx.transactionTime);
      return dt != null && dt.year == year && dt.month == month;
    }).toList();

    if (txs.isEmpty) {
      return null;
    }

    double totalIncome = 0;
    double totalExpense = 0;
    int expenseCount = 0;
    Map<String, double> categoryExpenses = {};

    for (var tx in txs) {
      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
      } else if (tx.type == 'EXPENSE') {
        totalExpense += tx.amount;
        expenseCount++;
        final cat = (tx.category != null && tx.category!.isNotEmpty) ? tx.category! : 'Khác';
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + tx.amount;
      }
    }

    return MonthlyStat(
      year: year,
      month: month,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      expenseCount: expenseCount,
      categoryExpenses: categoryExpenses,
      hasData: true,
    );
  }

  List<MonthlyStat> _computeAllMonthlyStats() {
    Map<String, MonthlyStat> map = {};

    for (var tx in _transactions) {
      final dt = _parseDate(tx.transactionTime);
      if (dt != null) {
        final key = '${dt.year}-${dt.month}';
        if (!map.containsKey(key)) {
          final stat = _getStatFor(dt.year, dt.month);
          if (stat != null) {
            map[key] = stat;
          }
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) {
      if (a.year != b.year) return a.year.compareTo(b.year);
      return a.month.compareTo(b.month);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final selectedStat = _getStatFor(_selectedYear, _selectedMonth);

    int prevY = _selectedYear;
    int prevM = _selectedMonth - 1;
    if (prevM < 1) {
      prevM = 12;
      prevY--;
    }
    final prevStat = _getStatFor(prevY, prevM);
    final allStats = _computeAllMonthlyStats();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primaryCyan,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Selector Header (< Tháng x/yyyy >)
                        _buildMonthHeader(),
                        const SizedBox(height: 16),

                        // Top Overview Cards (Chi tiêu & Thu nhập side-by-side for selected month with explicit month label)
                        _buildTopOverviewCards(selectedStat, prevStat, _selectedMonth, _selectedYear),
                        const SizedBox(height: 24),

                        // Expense & Income Bar Chart Section with Day/Month/Year Switcher
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Biểu đồ thu chi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            _buildChartModeSelector(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildIncomeExpenseBarChart(_selectedYear, _selectedMonth, allStats),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Category Breakdown & Donut Chart Section with explicit month label
                        Text('Thống kê danh mục (Tháng $_selectedMonth/$_selectedYear)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildCategoryBreakdownSection(_selectedYear, _selectedMonth, selectedStat),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Amount & Percentage Difference Section
                        Text('So sánh chi tiêu tháng trước & hiện tại (Tháng $_selectedMonth/$_selectedYear)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildComparisonDetailsCard(prevY, prevM, prevStat, _selectedYear, _selectedMonth, selectedStat),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Automated Insights Section
                        const Text('Nhận xét chi tiêu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        _buildInsightsCard(prevStat, selectedStat),
                        const SizedBox(height: 24),

                        // All Months History Summary
                        const Text('Lịch sử tổng hợp theo tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        allStats.isEmpty
                            ? const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Chưa có dữ liệu giao dịch.', style: TextStyle(color: AppTheme.textSecondary)))))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: allStats.length,
                                itemBuilder: (context, index) {
                                  final stat = allStats[allStats.length - 1 - index]; // newest first
                                  double net = stat.totalIncome - stat.totalExpense;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(stat.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text('${stat.expenseCount} GD chi', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('Chi: −${_currencyFormat.format(stat.totalExpense)} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed, fontSize: 12)),
                                              const SizedBox(height: 2),
                                              Text('Thu: +${_currencyFormat.format(stat.totalIncome)} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successGreen, fontSize: 12)),
                                              const SizedBox(height: 2),
                                              Text('Dư: ${net >= 0 ? '+' : ''}${_currencyFormat.format(net)} đ', style: TextStyle(fontSize: 11, color: net >= 0 ? AppTheme.successGreen : AppTheme.errorRed)),
                                            ],
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
                ),
    );
  }

  Widget _buildMonthHeader() {
    final now = DateTime.now();
    bool isCurrentMonth = _selectedYear == now.year && _selectedMonth == now.month;
    String monthText = isCurrentMonth ? 'Tháng này (T$_selectedMonth/$_selectedYear)' : 'Tháng $_selectedMonth/$_selectedYear';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
            onPressed: _previousMonth,
            tooltip: 'Tháng trước',
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                monthText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
            onPressed: _nextMonth,
            tooltip: 'Tháng sau',
          ),
        ],
      ),
    );
  }

  Widget _buildTopOverviewCards(MonthlyStat? stat, MonthlyStat? prevStat, int month, int year) {
    double expense = stat?.totalExpense ?? 0.0;
    double income = stat?.totalIncome ?? 0.0;

    double prevExpense = prevStat?.totalExpense ?? 0.0;
    double expenseDiff = expense - prevExpense;
    String expenseDiffStr = '';
    if (prevExpense > 0) {
      double pct = (expenseDiff / prevExpense) * 100;
      expenseDiffStr = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tổng quan thu chi (Tháng $month/$year)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_upward, color: AppTheme.errorRed, size: 14),
                        ),
                        const SizedBox(width: 6),
                        const Text('Chi tiêu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_currencyFormat.format(expense)}đ',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      expenseDiff >= 0 ? 'Tăng ${expenseDiffStr.isNotEmpty ? expenseDiffStr : '${_currencyFormat.format(expenseDiff)}đ'}' : 'Giảm',
                      style: TextStyle(fontSize: 11, color: expenseDiff > 0 ? AppTheme.errorRed : AppTheme.successGreen, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_downward, color: AppTheme.successGreen, size: 14),
                        ),
                        const SizedBox(width: 6),
                        const Text('Thu nhập', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_currencyFormat.format(income)}đ',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thực tế T$month/$year',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip('Ngày', 'DAY'),
          _buildModeChip('Tháng', 'MONTH'),
          _buildModeChip('Năm', 'YEAR'),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, String mode) {
    bool isSelected = _chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _chartMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseBarChart(int currY, int currM, List<MonthlyStat> allStats) {
    if (_chartMode == 'DAY') {
      final daysInMonth = DateTime(currY, currM + 1, 0).day;
      Map<int, double> dailyIncome = {};
      Map<int, double> dailyExpense = {};

      for (var tx in _transactions) {
        final dt = _parseDate(tx.transactionTime);
        if (dt != null && dt.year == currY && dt.month == currM) {
          if (tx.type == 'INCOME') {
            dailyIncome[dt.day] = (dailyIncome[dt.day] ?? 0) + tx.amount;
          } else if (tx.type == 'EXPENSE') {
            dailyExpense[dt.day] = (dailyExpense[dt.day] ?? 0) + tx.amount;
          }
        }
      }

      List<int> activeDays = [];
      for (int d = 1; d <= daysInMonth; d++) {
        if ((dailyIncome[d] ?? 0) > 0 || (dailyExpense[d] ?? 0) > 0) {
          activeDays.add(d);
        }
      }

      if (activeDays.isEmpty) {
        return _buildEmptyChartBox('Chưa có dữ liệu giao dịch trong tháng $currM/$currY.');
      }

      double maxVal = 0.0;
      for (var d in activeDays) {
        double inc = dailyIncome[d] ?? 0;
        double exp = dailyExpense[d] ?? 0;
        if (inc > maxVal) maxVal = inc;
        if (exp > maxVal) maxVal = exp;
      }
      if (maxVal == 0) maxVal = 100000;

      return Column(
        children: [
          _buildChartLegend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (activeDays.length * 75.0).clamp(320.0, 1400.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.25,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx >= 0 && idx < activeDays.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('N.${activeDays[idx]}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: activeDays.asMap().entries.map((entry) {
                      int i = entry.key;
                      int day = entry.value;
                      double inc = dailyIncome[day] ?? 0;
                      double exp = dailyExpense[day] ?? 0;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(toY: inc, color: AppTheme.successGreen, width: 12, borderRadius: BorderRadius.circular(4)),
                          BarChartRodData(toY: exp, color: AppTheme.errorRed, width: 12, borderRadius: BorderRadius.circular(4)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_chartMode == 'YEAR') {
      Map<int, double> yearlyIncome = {};
      Map<int, double> yearlyExpense = {};

      for (var tx in _transactions) {
        final dt = _parseDate(tx.transactionTime);
        if (dt != null) {
          if (tx.type == 'INCOME') {
            yearlyIncome[dt.year] = (yearlyIncome[dt.year] ?? 0) + tx.amount;
          } else if (tx.type == 'EXPENSE') {
            yearlyExpense[dt.year] = (yearlyExpense[dt.year] ?? 0) + tx.amount;
          }
        }
      }

      List<int> years = yearlyIncome.keys.toSet().union(yearlyExpense.keys.toSet()).toList()..sort();
      if (years.isEmpty) {
        return _buildEmptyChartBox('Chưa có dữ liệu theo năm.');
      }

      if (years.length > 8) {
        years = years.sublist(years.length - 8);
      }

      double maxVal = 0.0;
      for (var yr in years) {
        double inc = yearlyIncome[yr] ?? 0;
        double exp = yearlyExpense[yr] ?? 0;
        if (inc > maxVal) maxVal = inc;
        if (exp > maxVal) maxVal = exp;
      }
      if (maxVal == 0) maxVal = 100000;

      return Column(
        children: [
          _buildChartLegend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.25,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < years.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('${years[idx]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: years.asMap().entries.map((entry) {
                  int i = entry.key;
                  int yr = entry.value;
                  double inc = yearlyIncome[yr] ?? 0;
                  double exp = yearlyExpense[yr] ?? 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: inc, color: AppTheme.successGreen, width: 14, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: exp, color: AppTheme.errorRed, width: 14, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    } else {
      // MONTH mode: show up to 7-8 recent months with both income and expense bars
      if (allStats.isEmpty) {
        return _buildEmptyChartBox('Chưa có dữ liệu thống kê theo tháng.');
      }

      final recentStats = allStats.length > 8 ? allStats.sublist(allStats.length - 8) : allStats;

      double maxVal = 0.0;
      for (var stat in recentStats) {
        if (stat.totalIncome > maxVal) maxVal = stat.totalIncome;
        if (stat.totalExpense > maxVal) maxVal = stat.totalExpense;
      }
      if (maxVal == 0) maxVal = 100000;

      return Column(
        children: [
          _buildChartLegend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (recentStats.length * 85.0).clamp(320.0, 1100.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.25,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx >= 0 && idx < recentStats.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(recentStats[idx].shortLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: recentStats.asMap().entries.map((entry) {
                      int i = entry.key;
                      MonthlyStat stat = entry.value;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(toY: stat.totalIncome, color: AppTheme.successGreen, width: 14, borderRadius: BorderRadius.circular(4)),
                          BarChartRodData(toY: stat.totalExpense, color: AppTheme.errorRed, width: 14, borderRadius: BorderRadius.circular(4)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.successGreen, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        const Text('Thu nhập', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.errorRed, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        const Text('Chi tiêu', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCategoryBreakdownSection(int currY, int currM, MonthlyStat? currentStat) {
    if (currentStat == null || currentStat.hasData == false) {
      return Column(
        children: [
          _buildCategoryTypeTabs(),
          const SizedBox(height: 16),
          _buildEmptyChartBox('Chưa có dữ liệu giao dịch trong tháng $currM/$currY.'),
        ],
      );
    }

    Map<String, double> catAmounts = {};
    double totalTypeAmount = 0;

    for (var tx in _transactions) {
      final dt = _parseDate(tx.transactionTime);
      if (dt != null && dt.year == currY && dt.month == currM && tx.type == _categoryViewType) {
        final cat = (tx.category != null && tx.category!.isNotEmpty) ? tx.category! : 'Khác';
        catAmounts[cat] = (catAmounts[cat] ?? 0) + tx.amount;
        totalTypeAmount += tx.amount;
      }
    }

    if (catAmounts.isEmpty || totalTypeAmount == 0) {
      return Column(
        children: [
          _buildCategoryTypeTabs(),
          const SizedBox(height: 16),
          _buildEmptyChartBox('Chưa có dữ liệu ${_categoryViewType == 'EXPENSE' ? 'chi tiêu' : 'thu nhập'} theo danh mục trong tháng $currM/$currY.'),
        ],
      );
    }

    var sortedCats = catAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    final List<Color> fallbackColors = [
      const Color(0xFF08C7E8),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF6B7280),
    ];

    for (var entry in sortedCats) {
      String catName = entry.key;
      double amount = entry.value;
      double pct = (amount / totalTypeAmount) * 100;

      CategoryModel? catModel;
      try {
        catModel = _categories.firstWhere((c) => c.name.toLowerCase() == catName.toLowerCase() && c.type == _categoryViewType);
      } catch (_) {}

      Color catColor = catModel != null ? _parseColor(catModel.color) : fallbackColors[colorIndex % fallbackColors.length];
      colorIndex++;

      sections.add(
        PieChartSectionData(
          color: catColor,
          value: amount,
          title: '${pct >= 5 ? '${pct.toStringAsFixed(0)}%' : ''}',
          radius: 52,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        _buildCategoryTypeTabs(),
        const SizedBox(height: 20),

        // Donut Chart
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 58,
                  sectionsSpace: 3,
                  pieTouchData: PieTouchData(enabled: true),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _categoryViewType == 'EXPENSE' ? 'Tổng chi' : 'Tổng thu',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(totalTypeAmount),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category Details List
        ...sortedCats.map((entry) {
          String catName = entry.key;
          double amount = entry.value;
          double pct = (amount / totalTypeAmount) * 100;

          CategoryModel? catModel;
          try {
            catModel = _categories.firstWhere((c) => c.name.toLowerCase() == catName.toLowerCase() && c.type == _categoryViewType);
          } catch (_) {}

          Color catColor = catModel != null ? _parseColor(catModel.color) : AppTheme.primaryCyan;
          IconData catIcon = catModel != null ? _getCategoryIconData(catModel.icon) : Icons.category;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(catName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${pct.toStringAsFixed(1)}% tổng ${_categoryViewType == 'EXPENSE' ? 'chi' : 'thu'} (T$currM/$currY)', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_categoryViewType == 'EXPENSE' ? '−' : '+'}${_currencyFormat.format(amount)} đ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _categoryViewType == 'EXPENSE' ? AppTheme.errorRed : AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCategoryTypeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _categoryViewType = 'EXPENSE'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _categoryViewType == 'EXPENSE' ? AppTheme.primaryCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Chi tiêu',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _categoryViewType == 'EXPENSE' ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _categoryViewType = 'INCOME'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _categoryViewType == 'INCOME' ? AppTheme.primaryCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Thu nhập',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _categoryViewType == 'INCOME' ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'restaurant': return Icons.restaurant;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'directions_car': return Icons.directions_car;
      case 'receipt': return Icons.receipt;
      case 'sports_esports': return Icons.sports_esports;
      case 'favorite': return Icons.favorite;
      case 'school': return Icons.school;
      case 'work': return Icons.work;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'attach_money': return Icons.attach_money;
      case 'category': return Icons.category;
      default: return Icons.more_horiz;
    }
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryCyan;
    }
  }

  Widget _buildEmptyChartBox(String message) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart, size: 36, color: AppTheme.textSecondary),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonDetailsCard(int prevY, int prevM, MonthlyStat? prevStat, int currY, int currM, MonthlyStat? currentStat) {
    if (prevStat == null || currentStat == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            children: const [
              Icon(Icons.info_outline, size: 32, color: AppTheme.textSecondary),
              SizedBox(height: 8),
              Text('Chưa có dữ liệu để so sánh', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15)),
              SizedBox(height: 4),
              Text('Dữ liệu sẽ xuất hiện khi ứng dụng ghi nhận giao dịch ở cả hai tháng.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    double expPrev = prevStat.totalExpense;
    double expCurr = currentStat.totalExpense;
    double diff = expCurr - expPrev;

    String percentageText = '';
    bool canCalculatePercentage = true;
    if (expPrev > 0) {
      double pct = (diff / expPrev) * 100;
      percentageText = ' (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)';
    } else {
      canCalculatePercentage = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Tháng $prevM/$prevY:\n${_currencyFormat.format(expPrev)} đ', style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textSecondary, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('Tháng $currM/$currY:\n${_currencyFormat.format(expCurr)} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13), textAlign: TextAlign.right),
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        Text(
          'Chênh lệch: ${diff >= 0 ? '+' : ''}${_currencyFormat.format(diff)} đ${canCalculatePercentage ? percentageText : ''}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: diff > 0 ? AppTheme.errorRed : (diff < 0 ? AppTheme.successGreen : AppTheme.textPrimary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          !canCalculatePercentage
              ? 'Không thể tính tỷ lệ thay đổi vì chi tiêu tháng trước bằng 0.'
              : 'Chi tiêu tháng $currM/$currY ${diff > 0 ? 'tăng' : (diff < 0 ? 'giảm' : 'không thay đổi')} so với tháng $prevM/$prevY.',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildInsightsCard(MonthlyStat? prevStat, MonthlyStat? currentStat) {
    String comment = 'Chưa có dữ liệu để so sánh chi tiêu giữa tháng trước và tháng hiện tại.';
    if (prevStat != null && currentStat != null) {
      double diff = currentStat.totalExpense - prevStat.totalExpense;
      if (prevStat.totalExpense == 0) {
        comment = 'Chi tiêu tháng này là ${_currencyFormat.format(currentStat.totalExpense)} đ. Không thể tính tỷ lệ thay đổi vì chi tiêu tháng trước bằng 0.';
      } else {
        double pct = (diff / prevStat.totalExpense) * 100;
        if (diff > 0) {
          comment = 'Chi tiêu tháng này tăng ${pct.toStringAsFixed(1)}% (${_currencyFormat.format(diff)} đ) so với tháng trước.';
        } else if (diff < 0) {
          comment = 'Chi tiêu tháng này giảm ${pct.abs().toStringAsFixed(1)}% (${_currencyFormat.format(diff.abs())} đ) so với tháng trước.';
        } else {
          comment = 'Chi tiêu hai tháng không thay đổi.';
        }
      }

      if (currentStat.categoryExpenses.isNotEmpty) {
        var topCat = currentStat.categoryExpenses.entries.reduce((a, b) => a.value > b.value ? a : b);
        comment += ' Danh mục "${topCat.key}" chiếm tỷ trọng chi tiêu lớn nhất trong tháng này.';
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE0F7FA),
              child: Icon(Icons.insights, color: AppTheme.primaryCyanDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nhận xét chi tiêu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(comment, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
