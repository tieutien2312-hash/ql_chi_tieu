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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        await _ensureCategoryColumnsExist(db);
      },
    );
  }

  Future<void> _ensureCategoryColumnsExist(Database db) async {
    try {
      final tableInfo = await db.rawQuery("PRAGMA table_info(categories)");
      final columns = tableInfo.map((col) => col['name'].toString()).toList();
      
      if (!columns.contains('type')) {
        await db.execute("ALTER TABLE categories ADD COLUMN type TEXT NOT NULL DEFAULT 'EXPENSE'");
      }
      if (!columns.contains('color')) {
        await db.execute("ALTER TABLE categories ADD COLUMN color TEXT NOT NULL DEFAULT '#6366F1'");
      }
      if (!columns.contains('isActive')) {
        if (columns.contains('sActive')) {
          await db.execute("ALTER TABLE categories RENAME COLUMN sActive TO isActive");
        } else {
          await db.execute("ALTER TABLE categories ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1");
        }
      }
    } catch (e) {
      try {
        await db.execute("DROP TABLE IF EXISTS categories");
        await _createCategoriesTable(db);
      } catch (_) {}
    }
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

    await _createCategoriesTable(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _ensureCategoryColumnsExist(db);
    }
  }

  Future _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'EXPENSE',
        color TEXT NOT NULL DEFAULT '#6366F1',
        icon TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM categories');
    int count = 0;
    if (countResult.isNotEmpty && countResult.first['count'] != null) {
      count = (countResult.first['count'] as num).toInt();
    }

    if (count == 0) {
      List<Map<String, dynamic>> defaultCategories = [
        {'name': 'Ăn uống', 'type': 'EXPENSE', 'color': '#F97316', 'icon': 'restaurant', 'isActive': 1},
        {'name': 'Mua sắm', 'type': 'EXPENSE', 'color': '#EC4899', 'icon': 'shopping_bag', 'isActive': 1},
        {'name': 'Di chuyển', 'type': 'EXPENSE', 'color': '#3B82F6', 'icon': 'directions_car', 'isActive': 1},
        {'name': 'Hóa đơn', 'type': 'EXPENSE', 'color': '#8B5CF6', 'icon': 'receipt', 'isActive': 1},
        {'name': 'Giải trí', 'type': 'EXPENSE', 'color': '#10B981', 'icon': 'sports_esports', 'isActive': 1},
        {'name': 'Sức khỏe', 'type': 'EXPENSE', 'color': '#EF4444', 'icon': 'favorite', 'isActive': 1},
        {'name': 'Học tập', 'type': 'EXPENSE', 'icon': 'school', 'color': '#0EA5E9', 'isActive': 1},
        {'name': 'Lương', 'type': 'INCOME', 'color': '#10B981', 'icon': 'work', 'isActive': 1},
        {'name': 'Tiền thưởng', 'type': 'INCOME', 'color': '#F59E0B', 'icon': 'card_giftcard', 'isActive': 1},
        {'name': 'Thu nhập khác', 'type': 'INCOME', 'color': '#6366F1', 'icon': 'attach_money', 'isActive': 1},
        {'name': 'Khác', 'type': 'EXPENSE', 'color': '#6B7280', 'icon': 'more_horiz', 'isActive': 1},
      ];

      for (var cat in defaultCategories) {
        await db.insert('categories', cat);
      }
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
    final result = await db.query(
      'accounts',
      where: 'bankName LIKE ? AND accountNumber LIKE ?',
      whereArgs: ['%$bankName%', '%$accountNumber%'],
    );
    if (result.isNotEmpty) {
      return Account.fromMap(result.first);
    }
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

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
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

  Future<int> deleteTransaction(int transactionId) async {
    final db = await database;
    final txResult = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
    if (txResult.isNotEmpty) {
      final tx = TransactionModel.fromMap(txResult.first);
      final accResult = await db.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
      if (accResult.isNotEmpty) {
        double currentBalance = (accResult.first['balance'] as num).toDouble();
        double restoredBalance = tx.type == 'INCOME'
            ? currentBalance - tx.amount
            : currentBalance + tx.amount;
        await updateAccountBalance(tx.accountId, restoredBalance);
      }
      return await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
    }
    return 0;
  }

  Future<int> updateTransactionCategory(int transactionId, String category) async {
    final db = await database;
    return await db.update(
      'transactions',
      {'category': category},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  // ---- CATEGORY OPERATIONS ----
  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    try {
      final result = await db.query('categories', where: 'isActive = 1');
      return result.map((json) => CategoryModel.fromMap(json)).toList();
    } catch (_) {
      // Fallback if isActive column is missing
      final result = await db.query('categories');
      return result.map((json) => CategoryModel.fromMap(json)).toList();
    }
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategorySafe(int categoryId, String targetCategoryName) async {
    final db = await database;
    final catResult = await db.query('categories', where: 'id = ?', whereArgs: [categoryId]);
    if (catResult.isNotEmpty) {
      final catName = catResult.first['name'] as String;
      await db.update(
        'transactions',
        {'category': targetCategoryName},
        where: 'category = ?',
        whereArgs: [catName],
      );
      return await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    }
    return 0;
  }

  Future<int> countTransactionsWithCategory(String categoryName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE category = ?',
      [categoryName],
    );
    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as num).toInt();
    }
    return 0;
  }

  // ---- STATISTICS & SUMMARIES ----
  Future<Map<String, double>> getSummaryTotals() async {
    final db = await database;
    
    final accResult = await db.rawQuery('SELECT SUM(balance) as totalBalance FROM accounts');
    double totalBalance = 0.0;
    if (accResult.isNotEmpty && accResult.first['totalBalance'] != null) {
      totalBalance = (accResult.first['totalBalance'] as num).toDouble();
    }

    final incomeResult = await db.rawQuery("SELECT SUM(amount) as totalIncome FROM transactions WHERE type = 'INCOME'");
    double totalIncome = 0.0;
    if (incomeResult.isNotEmpty && incomeResult.first['totalIncome'] != null) {
      totalIncome = (incomeResult.first['totalIncome'] as num).toDouble();
    }

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
}
