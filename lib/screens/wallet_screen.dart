import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'wallet_detail_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<Account> _accounts = [];
  List<TransactionModel> _allTransactions = [];
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final accounts = await ApiService.getAccounts();
    final txs = await ApiService.getTransactions();
    setState(() {
      _accounts = accounts;
      _allTransactions = txs;
      _isLoading = false;
    });
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '••••${number.substring(number.length - 4)}';
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
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên gợi nhớ (VD: Tài khoản cá nhân)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'Số tài khoản / Số điện thoại'),
                ),
                const SizedBox(height: 12),
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
              child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.white),
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
                  await ApiService.insertAccount(newAcc);
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

  void _showEditAccountDialog(Account account) {
    final bankController = TextEditingController(text: account.bankName);
    final nameController = TextEditingController(text: account.accountName);
    final numberController = TextEditingController(text: account.accountNumber);
    final balanceController = TextEditingController(text: account.balance.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chỉnh sửa tài khoản / Ví'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bankController,
                  decoration: const InputDecoration(labelText: 'Tên Ngân hàng / Ví'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên gợi nhớ'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'Số tài khoản / Số điện thoại'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số dư (VNĐ)'),
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
                final bank = bankController.text.trim();
                final name = nameController.text.trim();
                final number = numberController.text.trim();
                final balance = double.tryParse(balanceController.text.trim()) ?? account.balance;

                if (bank.isNotEmpty && number.isNotEmpty) {
                  final updatedAcc = Account(
                    id: account.id,
                    bankName: bank,
                    accountName: name.isEmpty ? bank : name,
                    accountNumber: number,
                    balance: balance,
                    createdAt: account.createdAt,
                  );
                  await ApiService.updateAccount(updatedAcc);
                  if (context.mounted) Navigator.pop(context);
                  _loadAccounts();
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(dynamic id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc chắn muốn xóa tài khoản này và tất cả giao dịch liên quan?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: AppTheme.errorRed))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.deleteAccount(id);
      _loadAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : RefreshIndicator(
              onRefresh: _loadAccounts,
              color: AppTheme.primaryCyan,
              child: _accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Chưa có tài khoản nào được lưu.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.white),
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
                        bool isNotifAccount = _allTransactions.any((tx) => tx.accountId.toString() == acc.id.toString() && tx.source == 'notification');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: AppTheme.borderLight),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WalletDetailScreen(account: acc),
                                ),
                              ).then((_) => _loadAccounts());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppTheme.primaryCyan.withOpacity(0.15),
                                    child: const Icon(Icons.account_balance, color: AppTheme.primaryCyanDark),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              acc.bankName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                            ),
                                            if (isNotifAccount) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.blue.shade200),
                                                ),
                                                child: const Text('Tự động', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${acc.accountName} (${_maskAccountNumber(acc.accountNumber)})',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_currencyFormat.format(acc.balance)} VNĐ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppTheme.primaryCyanDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isNotifAccount)
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyanDark),
                                          onPressed: () => _showEditAccountDialog(acc),
                                          tooltip: 'Sửa tài khoản',
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                                        onPressed: () => _deleteAccount(acc.id!),
                                        tooltip: 'Xóa tài khoản',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
