import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../services/database_helper.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final accounts = await DatabaseHelper.instance.getAccounts();
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  void _showAddAccountDialog() {
    final bankController = TextEditingController(text: 'Vietcombank');
    final nameController = TextEditingController(text: 'Tài khoản chính');
    final numberController = TextEditingController();
    final balanceController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thêm tài khoản ngân hàng / Ví'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bankController,
                  decoration: const InputDecoration(labelText: 'Tên Ngân hàng / Ví (VD: MB Bank, Momo)'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên gợi nhớ (VD: Tài khoản cá nhân)'),
                ),
                TextField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'Số tài khoản / Số điện thoại'),
                ),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số dư ban đầu (VNĐ)'),
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
                final bank = bankController.text.trim();
                final name = nameController.text.trim();
                final number = numberController.text.trim();
                final balance = double.tryParse(balanceController.text.trim()) ?? 0.0;

                if (bank.isNotEmpty && number.isNotEmpty) {
                  final currentTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
                  final newAcc = Account(
                    bankName: bank,
                    accountName: name.isEmpty ? bank : name,
                    accountNumber: number,
                    balance: balance,
                    createdAt: currentTime,
                  );
                  await DatabaseHelper.instance.insertAccount(newAcc);
                  Navigator.pop(context);
                  _loadAccounts();
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(int id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc chắn muốn xóa tài khoản này và tất cả giao dịch liên quan?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await DatabaseHelper.instance.deleteAccount(id);
      _loadAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAccounts,
              child: _accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Chưa có tài khoản nào được lưu.'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAddAccountDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm tài khoản thủ công'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _accounts.length,
                      itemBuilder: (context, index) {
                        final acc = _accounts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.indigo.shade50,
                                  child: const Icon(Icons.account_balance, color: Colors.indigo),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        acc.bankName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${acc.accountName} (${acc.accountNumber})',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_currencyFormat.format(acc.balance)} đ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteAccount(acc.id!),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
