import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'bill_scan_screen.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<TransactionModel> _allTransactions = [];
  List<Account> _accounts = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'ALL'; // ALL, INCOME, EXPENSE
  dynamic _filterAccountId;
  String? _filterCategory;
  DateTimeRange? _filterDateRange;

  // Multi-select state
  bool _isSelecting = false;
  final Set<dynamic> _selectedIds = {};

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final txs = await ApiService.getTransactions();
      final accs = await ApiService.getAccounts();
      final cats = await ApiService.getCategories();

      setState(() {
        _allTransactions = txs;
        _accounts = accs;
        _categories = cats;
        _isLoading = false;
        // Clean up selected IDs that no longer exist
        final validIds = txs.map((t) => t.id).toSet();
        _selectedIds.removeWhere((id) => !validIds.contains(id));
        if (_selectedIds.isEmpty) {
          _isSelecting = false;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể tải dữ liệu: $e';
        _isLoading = false;
      });
    }
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

  DateTime? _parseDateTime(String rawTime) {
    try {
      if (rawTime.contains('T') || (rawTime.contains('-') && !rawTime.contains('/'))) {
        return DateTime.parse(rawTime);
      }
      final parts = rawTime.split(' ');
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

  List<TransactionModel> get _filteredTransactions {
    final list = _allTransactions.where((tx) {
      // 1. Type filter
      if (_filterType == 'INCOME' && tx.type != 'INCOME') return false;
      if (_filterType == 'EXPENSE' && tx.type != 'EXPENSE') return false;

      // 2. Account filter
      if (_filterAccountId != null && tx.accountId.toString() != _filterAccountId.toString()) return false;

      // 3. Category filter
      if (_filterCategory != null && _filterCategory!.isNotEmpty && tx.category != _filterCategory) return false;

      // 4. Date range filter
      if (_filterDateRange != null) {
        try {
          final dt = _parseDateTime(tx.transactionTime);
          if (dt != null) {
            final txDate = DateTime(dt.year, dt.month, dt.day);
            final startDate = DateTime(_filterDateRange!.start.year, _filterDateRange!.start.month, _filterDateRange!.start.day);
            final endDate = DateTime(_filterDateRange!.end.year, _filterDateRange!.end.month, _filterDateRange!.end.day);

            if (txDate.isBefore(startDate) || txDate.isAfter(endDate)) {
              return false;
            }
          }
        } catch (_) {}
      }

      // 5. Search query (description, bank name, account number, category)
      if (_searchQuery.isNotEmpty) {
        final acc = _getAccountForTx(tx.accountId);
        final bankName = acc?.bankName.toLowerCase() ?? '';
        final accNum = acc?.accountNumber.toLowerCase() ?? '';
        final desc = tx.description.toLowerCase();
        final cat = (tx.category ?? '').toLowerCase();

        final matches = desc.contains(_searchQuery) ||
            bankName.contains(_searchQuery) ||
            accNum.contains(_searchQuery) ||
            cat.contains(_searchQuery);

        if (!matches) return false;
      }

      return true;
    }).toList();

    // Sort from closest to furthest (newest first / từ gần đến xa)
    list.sort((a, b) {
      DateTime? dtA = _parseDateTime(a.transactionTime);
      DateTime? dtB = _parseDateTime(b.transactionTime);
      if (dtA != null && dtB != null) {
        return dtB.compareTo(dtA);
      }
      return 0;
    });

    return list;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filterType = 'ALL';
      _filterAccountId = null;
      _filterCategory = null;
      _filterDateRange = null;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final filtered = _filteredTransactions;
      final allFilteredIds = filtered.map((t) => t.id!).toList();
      
      bool allSelected = allFilteredIds.isNotEmpty && allFilteredIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(allFilteredIds);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.addAll(allFilteredIds);
        _isSelecting = true;
      }
    });
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
    final accounts = await ApiService.getAccounts();
    if (accounts.isEmpty) {
      final currentTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      await ApiService.insertAccount(
        Account(
          bankName: 'Tiền mặt',
          accountName: 'Ví tiền mặt',
          accountNumber: 'CASH',
          balance: 0,
          createdAt: currentTime,
        ),
      );
    }
    final refreshedAccounts = await ApiService.getAccounts();
    final categories = await ApiService.getCategories();

    dynamic selectedAccountId = refreshedAccounts.isNotEmpty ? refreshedAccounts.first.id : null;
    String selectedType = 'EXPENSE';
    String selectedCategory = categories.isNotEmpty ? categories.first.name : 'Khác';
    String selectedTransactionTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
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
                    DropdownButtonFormField<dynamic>(
                      value: selectedAccountId,
                      decoration: const InputDecoration(labelText: 'Tài khoản / Ví*'),
                      items: refreshedAccounts.map((acc) {
                        return DropdownMenuItem<dynamic>(
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
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        DateTime initialDate = DateTime.now();
                        try {
                          final parts = selectedTransactionTime.split(' ');
                          if (parts.isNotEmpty) {
                            final dParts = parts[0].split('/');
                            if (dParts.length == 3) {
                              initialDate = DateTime(int.parse(dParts[2]), int.parse(dParts[1]), int.parse(dParts[0]));
                            }
                          }
                        } catch (_) {}

                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );

                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(initialDate),
                          );

                          if (pickedTime != null) {
                            final finalDt = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setDialogState(() {
                              selectedTransactionTime = DateFormat('dd/MM/yyyy HH:mm').format(finalDt);
                            });
                          }
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Thời gian giao dịch*'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedTransactionTime, style: const TextStyle(fontSize: 14)),
                            const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryCyan),
                          ],
                        ),
                      ),
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
                      final tx = TransactionModel(
                        accountId: selectedAccountId!,
                        type: selectedType,
                        amount: amount,
                        balanceAfter: 0,
                        description: noteController.text.trim().isEmpty
                            ? (selectedType == 'INCOME' ? 'Thu nhập tiền mặt' : 'Chi tiêu tiền mặt')
                            : noteController.text.trim(),
                        transactionTime: selectedTransactionTime,
                        source: 'manual',
                        category: selectedCategory,
                      );
                      await ApiService.insertTransaction(tx);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
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

  void _showBatchCategoryDialog() {
    if (_selectedIds.isEmpty) return;
    String selectedCategory = _categories.isNotEmpty ? _categories.first.name : 'Khác';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Đổi danh mục (${_selectedIds.length} giao dịch)'),
              content: DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: _categories.map((c) => c.name).toSet().toList().map((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() => selectedCategory = val!);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    for (var id in _selectedIds) {
                      await ApiService.updateTransactionCategory(id, selectedCategory);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {
                        _isSelecting = false;
                        _selectedIds.clear();
                      });
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật danh mục hàng loạt thành công!')),
                      );
                    }
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa hàng loạt'),
            content: Text('Bạn có chắc chắn muốn xóa ${_selectedIds.length} giao dịch đã chọn? Số dư tài khoản sẽ được hoàn tác tương ứng.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      for (var id in _selectedIds) {
        await ApiService.deleteTransaction(id);
      }
      if (mounted) {
        setState(() {
          _isSelecting = false;
          _selectedIds.clear();
        });
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa các giao dịch đã chọn thành công!')),
        );
      }
    }
  }

  void _showAdvancedFilterModal() {
    String tempType = _filterType;
    dynamic tempAccountId = _filterAccountId;
    String? tempCategory = _filterCategory;
    DateTimeRange? tempDateRange = _filterDateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Bộ lọc nâng cao', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempType = 'ALL';
                                tempAccountId = null;
                                tempCategory = null;
                                tempDateRange = null;
                              });
                            },
                            child: const Text('Đặt lại'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Loại giao dịch', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Tất cả'),
                                  selected: tempType == 'ALL',
                                  onSelected: (val) => setModalState(() => tempType = 'ALL'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Thu nhập'),
                                  selected: tempType == 'INCOME',
                                  onSelected: (val) => setModalState(() => tempType = 'INCOME'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Chi tiêu'),
                                  selected: tempType == 'EXPENSE',
                                  onSelected: (val) => setModalState(() => tempType = 'EXPENSE'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Tài khoản / Ngân hàng', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<dynamic>(
                              value: tempAccountId,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              items: [
                                const DropdownMenuItem<dynamic>(value: null, child: Text('Tất cả tài khoản')),
                                ..._accounts.map((acc) => DropdownMenuItem<dynamic>(
                                      value: acc.id,
                                      child: Text('${acc.bankName} (${_maskAccountNumber(acc.accountNumber)})'),
                                    )),
                              ],
                              onChanged: (val) => setModalState(() => tempAccountId = val),
                            ),
                            const SizedBox(height: 16),
                            const Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              value: tempCategory,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('Tất cả danh mục')),
                                ..._categories.map((c) => c.name).toSet().toList().map((name) => DropdownMenuItem<String?>(
                                      value: name,
                                      child: Text(name),
                                    )),
                              ],
                              onChanged: (val) => setModalState(() => tempCategory = val),
                            ),
                            const SizedBox(height: 16),
                            const Text('Khoảng thời gian', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                  initialDateRange: tempDateRange,
                                );
                                if (picked != null) {
                                  setModalState(() => tempDateRange = picked);
                                }
                              },
                              icon: const Icon(Icons.date_range),
                              label: Text(tempDateRange == null
                                  ? 'Chọn khoảng thời gian'
                                  : '${DateFormat('dd/MM/yyyy').format(tempDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(tempDateRange!.end)}'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                _filterType = tempType;
                                _filterAccountId = tempAccountId;
                                _filterCategory = tempCategory;
                                _filterDateRange = tempDateRange;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Áp dụng bộ lọc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionDetails(TransactionModel tx) {
    if (_isSelecting) {
      setState(() {
        if (tx.id != null) {
          if (_selectedIds.contains(tx.id)) {
            _selectedIds.remove(tx.id);
            if (_selectedIds.isEmpty) _isSelecting = false;
          } else {
            _selectedIds.add(tx.id!);
          }
        }
      });
      return;
    }

    final acc = _getAccountForTx(tx.accountId);
    final bankName = acc?.bankName ?? 'Chưa xác định';
    final accNum = acc != null ? _maskAccountNumber(acc.accountNumber) : 'Chưa xác định';
    String selectedCategory = tx.category ?? 'Khác';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Chi tiết giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Xác nhận xóa'),
                                      content: const Text('Bạn có chắc chắn muốn xóa giao dịch này? Số dư tài khoản sẽ được hoàn tác.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (confirm) {
                                await ApiService.deleteTransaction(tx.id!);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _loadData();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Loại giao dịch', tx.type == 'INCOME' ? 'Thu nhập (+)' : 'Chi tiêu (−)'),
                            _buildDetailRow('Số tiền', '${tx.type == 'INCOME' ? '+' : '−'} ${_currencyFormat.format(tx.amount)} VNĐ'),
                            _buildDetailRow('Ngân hàng', bankName),
                            _buildDetailRow('Tài khoản liên quan', accNum),
                            _buildDetailRow('Thời gian giao dịch', tx.transactionTime),
                            _buildDetailRow('Nguồn ghi nhận', tx.source == 'notification' ? 'Notification ngân hàng' : 'Thủ công'),
                            _buildDetailRow('Số dư sau giao dịch', tx.balanceAfter > 0 ? '${_currencyFormat.format(tx.balanceAfter)} VNĐ' : 'Chưa xác định'),
                            const SizedBox(height: 12),
                            const Text('Nội dung gốc / Notification:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(tx.description, style: const TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(height: 16),
                            const Text('Danh mục giao dịch (Có thể chỉnh sửa):', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              items: _categories.map((c) => c.name).toSet().toList().map((name) {
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setSheetState(() => selectedCategory = val!);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await ApiService.updateTransactionCategory(tx.id!, selectedCategory);
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật danh mục thành công!')));
                              }
                            },
                            child: const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTransactions;

    Map<String, List<TransactionModel>> groupedTransactions = {};
    for (var tx in filteredList) {
      String dateKey = 'Chưa xác định';
      try {
        final dt = _parseDateTime(tx.transactionTime);
        if (dt != null) {
          dateKey = 'Tháng ${dt.month}/${dt.year}';
        }
      } catch (_) {}

      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(tx);
    }

    final sortedDateKeys = groupedTransactions.keys.toList();
    sortedDateKeys.sort((a, b) {
      try {
        final partsA = a.replaceFirst('Tháng ', '').split('/');
        final partsB = b.replaceFirst('Tháng ', '').split('/');
        if (partsA.length == 2 && partsB.length == 2) {
          int mA = int.parse(partsA[0]);
          int yA = int.parse(partsA[1]);
          int mB = int.parse(partsB[0]);
          int yB = int.parse(partsB[1]);
          if (yA != yB) return yB.compareTo(yA);
          return mB.compareTo(mA);
        }
      } catch (_) {}
      return b.compareTo(a);
    });

    List<Widget> activeFilterChips = [];
    if (_filterType == 'INCOME') {
      activeFilterChips.add(_buildFilterChip('Thu nhập', () => setState(() => _filterType = 'ALL')));
    } else if (_filterType == 'EXPENSE') {
      activeFilterChips.add(_buildFilterChip('Chi tiêu', () => setState(() => _filterType = 'ALL')));
    }
    if (_filterAccountId != null) {
      final acc = _getAccountForTx(_filterAccountId!);
      if (acc != null) {
        activeFilterChips.add(_buildFilterChip('${acc.bankName}', () => setState(() => _filterAccountId = null)));
      }
    }
    if (_filterCategory != null && _filterCategory!.isNotEmpty) {
      activeFilterChips.add(_buildFilterChip(_filterCategory!, () => setState(() => _filterCategory = null)));
    }
    if (_filterDateRange != null) {
      final dateStr = '${DateFormat('dd/MM').format(_filterDateRange!.start)} - ${DateFormat('dd/MM').format(_filterDateRange!.end)}';
      activeFilterChips.add(_buildFilterChip(dateStr, () => setState(() => _filterDateRange = null)));
    }
    if (_searchQuery.isNotEmpty) {
      activeFilterChips.add(_buildFilterChip('Từ khóa: "$_searchQuery"', () => _searchController.clear()));
    }

    final allFilteredIds = filteredList.map((t) => t.id!).toList();
    bool isAllSelected = allFilteredIds.isNotEmpty && allFilteredIds.every((id) => _selectedIds.contains(id));

    return Scaffold(
      appBar: _isSelecting
          ? AppBar(
              backgroundColor: Colors.indigo.shade800,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelecting = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('Đã chọn ${_selectedIds.length}'),
              actions: [
                IconButton(
                  icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all),
                  tooltip: isAllSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                  onPressed: _toggleSelectAll,
                ),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        color: Colors.grey.shade50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Tìm nội dung, ngân hàng, danh mục...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () => _searchController.clear(),
                                            )
                                          : null,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: Color(0xFF08C7E8)),
                                  onPressed: _showAdvancedFilterModal,
                                  icon: const Icon(Icons.filter_list, color: Colors.white),
                                  tooltip: 'Bộ lọc nâng cao',
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: Color(0xFF08C7E8)),
                                  onPressed: _showAddTransactionOptions,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  tooltip: 'Thêm giao dịch',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tìm thấy ${filteredList.length} giao dịch',
                                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                                if (activeFilterChips.isNotEmpty)
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    onPressed: _resetFilters,
                                    child: const Text('Xóa bộ lọc', style: TextStyle(color: Colors.red, fontSize: 13)),
                                  ),
                              ],
                            ),
                            if (activeFilterChips.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: activeFilterChips,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Transactions List
                      Expanded(
                        child: filteredList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text('Không tìm thấy giao dịch nào phù hợp.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    TextButton(onPressed: _resetFilters, child: const Text('Xóa bộ lọc để xem tất cả')),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: sortedDateKeys.length,
                                itemBuilder: (context, dateIndex) {
                                  final dateKey = sortedDateKeys[dateIndex];
                                  final dayTxs = groupedTransactions[dateKey]!;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          dateKey,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                                        ),
                                      ),
                                      ...dayTxs.map((tx) {
                                        final isIncome = tx.type == 'INCOME';
                                        final acc = _getAccountForTx(tx.accountId);
                                        final bankName = acc?.bankName ?? 'Chưa xác định';
                                        final accNum = acc != null ? _maskAccountNumber(acc.accountNumber) : '••••';
                                        final isSelected = _selectedIds.contains(tx.id);
                                        
                                        String timeOnly = tx.transactionTime;
                                        try {
                                          final p = tx.transactionTime.split(' ');
                                          if (p.length > 1) timeOnly = p[1];
                                        } catch (_) {}

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          elevation: isSelected ? 3 : 1,
                                          color: isSelected ? Colors.indigo.shade50 : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: isSelected ? const BorderSide(color: Colors.indigo, width: 1.5) : BorderSide.none,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => _showTransactionDetails(tx),
                                            onLongPress: () {
                                              if (!_isSelecting && tx.id != null) {
                                                setState(() {
                                                  _isSelecting = true;
                                                  _selectedIds.add(tx.id!);
                                                });
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Row(
                                                children: [
                                                  if (_isSelecting) ...[
                                                    Checkbox(
                                                      value: isSelected,
                                                      onChanged: (val) {
                                                        setState(() {
                                                          if (val == true && tx.id != null) {
                                                            _selectedIds.add(tx.id!);
                                                          } else if (tx.id != null) {
                                                            _selectedIds.remove(tx.id);
                                                            if (_selectedIds.isEmpty) _isSelecting = false;
                                                          }
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  CircleAvatar(
                                                    backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                                                    child: Icon(
                                                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                                      color: isIncome ? Colors.green : Colors.red,
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
                                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Text(
                                                          '$bankName · $accNum',
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '${tx.transactionTime} · ${tx.category ?? 'Khác'}',
                                                          style: TextStyle(color: Colors.teal, fontSize: 11),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${isIncome ? '+' : '−'} ${_currencyFormat.format(tx.amount)} VNĐ',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isIncome ? Colors.green : Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _isSelecting
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedIds.isEmpty ? null : _showBatchCategoryDialog,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text('Đổi danh mục (${_selectedIds.length})'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedIds.isEmpty ? null : _confirmBatchDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Xóa (${_selectedIds.length})'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDeleted,
      backgroundColor: Colors.indigo.shade50,
      labelStyle: const TextStyle(color: Colors.indigo),
      side: BorderSide(color: Colors.indigo.shade100),
      visualDensity: VisualDensity.compact,
    );
  }
}
