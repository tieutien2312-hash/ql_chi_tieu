import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class TestSeeder {
  static Future<void> insertSampleData() async {
    final now = DateTime.now();

    // 1. Current month dates
    final currDate0 = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final currDate1 = DateFormat('dd/MM/yyyy HH:mm').format(now.subtract(const Duration(days: 2)));
    final currDate2 = DateFormat('dd/MM/yyyy HH:mm').format(now.subtract(const Duration(days: 5)));

    // 2. Previous month (month - 1)
    final prevMonthDate = DateTime(now.year, now.month - 1, 15);
    final prevDate0 = DateFormat('dd/MM/yyyy HH:mm').format(prevMonthDate);
    final prevDate1 = DateFormat('dd/MM/yyyy HH:mm').format(prevMonthDate.add(const Duration(days: 3)));
    final prevDate2 = DateFormat('dd/MM/yyyy HH:mm').format(prevMonthDate.add(const Duration(days: 7)));

    // 3. 2 months ago (month - 2)
    final twoMonthsAgoDate = DateTime(now.year, now.month - 2, 12);
    final twoAgoDate0 = DateFormat('dd/MM/yyyy HH:mm').format(twoMonthsAgoDate);
    final twoAgoDate1 = DateFormat('dd/MM/yyyy HH:mm').format(twoMonthsAgoDate.add(const Duration(days: 4)));

    // 4. 3 months ago (month - 3)
    final threeMonthsAgoDate = DateTime(now.year, now.month - 3, 10);
    final threeAgoDate0 = DateFormat('dd/MM/yyyy HH:mm').format(threeMonthsAgoDate);
    final threeAgoDate1 = DateFormat('dd/MM/yyyy HH:mm').format(threeMonthsAgoDate.add(const Duration(days: 5)));

    // 5. December of previous year (Year transition test dataset)
    final yearTransitionDate = DateTime(now.year - 1, 12, 20);
    final yearTransDate0 = DateFormat('dd/MM/yyyy HH:mm').format(yearTransitionDate);
    final yearTransDate1 = DateFormat('dd/MM/yyyy HH:mm').format(yearTransitionDate.add(const Duration(days: 5)));

    // 1. Insert sample accounts
    final accVCB = Account(
      bankName: 'Vietcombank',
      accountName: 'TK Cá nhân VCB',
      accountNumber: '****6789',
      balance: 28500000,
      createdAt: yearTransDate0,
    );
    await ApiService.insertAccount(accVCB);

    final accMB = Account(
      bankName: 'MB Bank',
      accountName: 'TK Lương MB',
      accountNumber: '****9999',
      balance: 21200000,
      createdAt: yearTransDate0,
    );
    await ApiService.insertAccount(accMB);

    final accMomo = Account(
      bankName: 'Ví Momo',
      accountName: 'Ví điện tử Momo',
      accountNumber: '0987654321',
      balance: 3250000,
      createdAt: yearTransDate0,
    );
    await ApiService.insertAccount(accMomo);

    final accounts = await ApiService.getAccounts();
    dynamic vcbId = accounts.firstWhere((a) => a.bankName == 'Vietcombank', orElse: () => accounts.first).id;
    dynamic mbId = accounts.firstWhere((a) => a.bankName == 'MB Bank', orElse: () => accounts.first).id;
    dynamic momoId = accounts.firstWhere((a) => a.bankName == 'Ví Momo', orElse: () => accounts.first).id;

    // ---- DATASET 1: December of Previous Year (Tháng 12 năm trước - Year Transition Test) ----
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: vcbId,
        type: 'INCOME',
        amount: 20000000,
        balanceAfter: 48500000,
        description: 'LUONG THANG 12 NAM TRUOC',
        transactionTime: yearTransDate0,
        source: 'notification',
        category: 'Lương',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: vcbId,
        type: 'EXPENSE',
        amount: 3500000,
        balanceAfter: 45000000,
        description: 'Mua sam tet & an uong cuoi nam',
        transactionTime: yearTransDate1,
        source: 'notification',
        category: 'Mua sắm',
      ),
    );

    // ---- DATASET 2: 3 Months Ago ----
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: mbId,
        type: 'INCOME',
        amount: 16000000,
        balanceAfter: 37200000,
        description: 'THU NHAP THANG -3',
        transactionTime: threeAgoDate0,
        source: 'notification',
        category: 'Lương',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: mbId,
        type: 'EXPENSE',
        amount: 1800000,
        balanceAfter: 35400000,
        description: 'Chi phi an uong & hoa don thang -3',
        transactionTime: threeAgoDate1,
        source: 'notification',
        category: 'Ăn uống',
      ),
    );

    // ---- DATASET 3: 2 Months Ago ----
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: mbId,
        type: 'INCOME',
        amount: 17000000,
        balanceAfter: 52400000,
        description: 'THU NHAP THANG -2',
        transactionTime: twoAgoDate0,
        source: 'notification',
        category: 'Lương',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: mbId,
        type: 'EXPENSE',
        amount: 2200000,
        balanceAfter: 50200000,
        description: 'Chi phi di chuyen & mua sam thang -2',
        transactionTime: twoAgoDate1,
        source: 'notification',
        category: 'Di chuyển',
      ),
    );

    // ---- DATASET 4: Previous Month (Tháng trước) ----
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: vcbId,
        type: 'INCOME',
        amount: 15000000,
        balanceAfter: 65200000,
        description: 'CONG TY ABC TRA LUONG THANG TRUOC',
        transactionTime: prevDate0,
        source: 'notification',
        category: 'Lương',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: vcbId,
        type: 'EXPENSE',
        amount: 1200000,
        balanceAfter: 64000000,
        description: 'Tien sieu thi & an uong thang truoc',
        transactionTime: prevDate1,
        source: 'notification',
        category: 'Ăn uống',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: mbId,
        type: 'EXPENSE',
        amount: 2000000,
        balanceAfter: 62000000,
        description: 'Mua sam quan ao va do dung gia dinh',
        transactionTime: prevDate2,
        source: 'notification',
        category: 'Mua sắm',
      ),
    );

    // ---- DATASET 5: Current Month (Tháng hiện tại) ----
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: vcbId,
        type: 'INCOME',
        amount: 18000000,
        balanceAfter: 80000000,
        description: 'CONG TY ABC TRA LUONG THANG NAY',
        transactionTime: currDate2,
        source: 'notification',
        category: 'Lương',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: vcbId,
        type: 'EXPENSE',
        amount: 1500000,
        balanceAfter: 78500000,
        description: 'An uong & tiec tung dau thang',
        transactionTime: currDate1,
        source: 'notification',
        category: 'Ăn uống',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: mbId,
        type: 'EXPENSE',
        amount: 2800000,
        balanceAfter: 75700000,
        description: 'Mua thiet bi dien tu va quan ao',
        transactionTime: currDate1,
        source: 'notification',
        category: 'Mua sắm',
      ),
    );
    await ApiService.insertTransaction(
      TransactionModel(
        accountId: momoId,
        type: 'EXPENSE',
        amount: 250000,
        balanceAfter: 75450000,
        description: 'Thanh toan hoa don dien nuoc',
        transactionTime: currDate0,
        source: 'notification',
        category: 'Hóa đơn',
      ),
    );
  }

  static Future<void> clearTestData() async {
    final accounts = await ApiService.getAccounts();
    for (var acc in accounts) {
      await ApiService.deleteAccount(acc.id);
    }
  }
}
