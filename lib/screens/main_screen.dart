import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import 'home_screen.dart';
import 'transaction_screen.dart';
import 'wallet_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Trang chủ',
    'Lịch sử giao dịch',
    'Ví tiền & Tài khoản',
    'Cài đặt & Quyền',
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onRefreshNeeded: () => setState(() {})),
      const TransactionScreen(),
      const WalletScreen(),
      const SettingsScreen(),
    ];
  }

  void _showAddManualTransactionDialog() async {
    final accounts = await DatabaseHelper.instance.getAccounts();
    if (accounts.isEmpty) {
      final currentTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      await DatabaseHelper.instance.insertAccount(
        Account(
          bankName: 'Tiền mặt',
          accountName: 'Ví tiền mặt',
          accountNumber: 'CASH',
          balance: 0,
          createdAt: currentTime,
        ),
      );
    }
    final refreshedAccounts = await DatabaseHelper.instance.getAccounts();
    final categories = await DatabaseHelper.instance.getCategories();

    int? selectedAccountId = refreshedAccounts.isNotEmpty ? refreshedAccounts.first.id : null;
    String selectedType = 'EXPENSE'; // EXPENSE or INCOME
    String selectedCategory = categories.isNotEmpty ? categories.first.name : 'Khác';
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm giao dịch thủ công'),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)*'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedAccountId,
                      decoration: const InputDecoration(labelText: 'Tài khoản / Ví*'),
                      items: refreshedAccounts.map((acc) {
                        return DropdownMenuItem<int>(
                          value: acc.id,
                          child: Text('${acc.bankName} (${acc.accountNumber})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedAccountId = val);
                      },
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
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount > 0 && selectedAccountId != null) {
                      final currentTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
                      final tx = TransactionModel(
                        accountId: selectedAccountId!,
                        type: selectedType,
                        amount: amount,
                        balanceAfter: 0,
                        description: noteController.text.trim().isEmpty
                            ? (selectedType == 'INCOME' ? 'Thu nhập tiền mặt' : 'Chi tiêu tiền mặt')
                            : noteController.text.trim(),
                        transactionTime: currentTime,
                        source: 'manual',
                        category: selectedCategory,
                      );
                      await DatabaseHelper.instance.insertTransaction(tx);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      setState(() {});
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
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddManualTransactionDialog,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        tooltip: 'Thêm giao dịch thủ công',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Giao dịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Ví tiền',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
