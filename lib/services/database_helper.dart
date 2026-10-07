import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ql_chi_tieu.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bankName TEXT NOT NULL,
        accountName TEXT NOT NULL,
        accountNumber TEXT NOT NULL,
        balance REAL NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accountId INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        balanceAfter REAL NOT NULL,
        description TEXT NOT NULL,
        transactionTime TEXT NOT NULL,
        source TEXT NOT NULL,
        category TEXT,
        FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    // Seed default categories
    List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Ăn uống', 'icon': 'restaurant'},
      {'name': 'Mua sắm', 'icon': 'shopping_bag'},
      {'name': 'Di chuyển', 'icon': 'directions_car'},
      {'name': 'Hóa đơn', 'icon': 'receipt'},
      {'name': 'Giải trí', 'icon': 'sports_esports'},
      {'name': 'Lương', 'icon': 'work'},
      {'name': 'Chuyển tiền', 'icon': 'swap_horiz'},
      {'name': 'Khác', 'icon': 'more_horiz'},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  // ---- ACCOUNT OPERATIONS ----
  Future<int> insertAccount(Account account) async {
    final db = await database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final result = await db.query('accounts');
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future<Account?> getAccountByNumberOrBank(String bankName, String accountNumber) async {
    final db = await database;
    // Normalize or search partial match on account number
    final result = await db.query(
      'accounts',
      where: 'bankName LIKE ? AND accountNumber LIKE ?',
      whereArgs: ['%$bankName%', '%$accountNumber%'],
    );
    if (result.isNotEmpty) {
      return Account.fromMap(result.first);
    }
    // Fallback: search just by account number if bank name varies
    final result2 = await db.query(
      'accounts',
      where: 'accountNumber LIKE ?',
      whereArgs: ['%$accountNumber%'],
    );
    if (result2.isNotEmpty) {
      return Account.fromMap(result2.first);
    }
    return null;
  }

  Future<int> updateAccountBalance(int accountId, double newBalance) async {
    final db = await database;
    return await db.update(
      'accounts',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'accountId = ?', whereArgs: [id]);
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ---- TRANSACTION OPERATIONS ----
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    int id = await db.insert('transactions', transaction.toMap());
    
    // Also update account balance automatically
    final accountResult = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [transaction.accountId],
    );
    if (accountResult.isNotEmpty) {
      double currentBalance = (accountResult.first['balance'] as num).toDouble();
      double newBalance = transaction.type == 'INCOME'
          ? currentBalance + transaction.amount
          : currentBalance - transaction.amount;
      
      await updateAccountBalance(transaction.accountId, transaction.balanceAfter > 0 ? transaction.balanceAfter : newBalance);
    }
    return id;
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'id DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByAccount(int accountId) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'accountId = ?',
      whereArgs: [accountId],
      orderBy: 'id DESC',
    );
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  // ---- STATISTICS & SUMMARIES ----
  Future<Map<String, double>> getSummaryTotals() async {
    final db = await database;
    
    // Total balance across all accounts
    final accResult = await db.rawQuery('SELECT SUM(balance) as totalBalance FROM accounts');
    double totalBalance = 0.0;
    if (accResult.isNotEmpty && accResult.first['totalBalance'] != null) {
      totalBalance = (accResult.first['totalBalance'] as num).toDouble();
    }

    // Total income
    final incomeResult = await db.rawQuery("SELECT SUM(amount) as totalIncome FROM transactions WHERE type = 'INCOME'");
    double totalIncome = 0.0;
    if (incomeResult.isNotEmpty && incomeResult.first['totalIncome'] != null) {
      totalIncome = (incomeResult.first['totalIncome'] as num).toDouble();
    }

    // Total expense
    final expenseResult = await db.rawQuery("SELECT SUM(amount) as totalExpense FROM transactions WHERE type = 'EXPENSE'");
    double totalExpense = 0.0;
    if (expenseResult.isNotEmpty && expenseResult.first['totalExpense'] != null) {
      totalExpense = (expenseResult.first['totalExpense'] as num).toDouble();
    }

    return {
      'totalBalance': totalBalance,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
    };
  }

  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map((json) => CategoryModel.fromMap(json)).toList();
  }
}
