import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';
import 'database_helper.dart';

class ApiService {
  static const String baseUrl = 'https://plnznpq1-7126.asse.devtunnels.ms/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'User';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
  }

  static Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ---- AUTH ----
  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['accessToken'] ?? data['jwt'];
        final user = data['user'];
        if (token != null) {
          await saveToken(token);
          String role = 'User';
          if (user != null) {
            role = user['role']?.toString() ?? 'User';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_role', role);
            await prefs.setString('user_email', user['email'] ?? email);
          }
          return role;
        }
      }
    } catch (e) {
      print('Login error: $e');
    }
    return null;
  }

  static Future<bool> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'email': email, 'password': password, 'role': 'User'}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Register error: $e');
    }
    return false;
  }

  // ---- ACCOUNTS (API First + SQLite Local Merge) ----
  static Future<List<Account>> getAccounts() async {
    List<Account> apiAccounts = [];
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/accounts'), headers: _headers(token)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        List<dynamic> list = jsonDecode(response.body);
        apiAccounts = list.map((json) => Account.fromMap(json)).toList();
      }
    } catch (e) {
      print('API GetAccounts failed: $e');
    }

    final localAccounts = await DatabaseHelper.instance.getAccounts();
    return _mergeAccounts(apiAccounts, localAccounts);
  }

  static List<Account> _mergeAccounts(List<Account> apiList, List<Account> localList) {
    final Map<String, Account> map = {};
    for (var acc in apiList) {
      final key = 'api_${acc.id}_${acc.accountNumber}';
      map[key] = acc;
    }
    for (var acc in localList) {
      final key = 'local_${acc.id}_${acc.accountNumber}';
      map[key] = acc;
    }
    return map.values.toList();
  }

  static Future<bool> insertAccount(Account account) async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('$baseUrl/accounts'),
        headers: _headers(token),
        body: jsonEncode({
          'bankName': account.bankName,
          'accountName': account.accountName,
          'accountNumber': account.accountNumber,
          'balance': account.balance,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API InsertAccount failed: $e');
    }
    await DatabaseHelper.instance.insertAccount(account);
    return true;
  }

  static Future<bool> updateAccount(Account account) async {
    try {
      final token = await getToken();
      if (account.id != null) {
        await http.put(
          Uri.parse('$baseUrl/accounts/${account.id}'),
          headers: _headers(token),
          body: jsonEncode({
            'bankName': account.bankName,
            'accountName': account.accountName,
            'accountNumber': account.accountNumber,
            'balance': account.balance,
          }),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      print('API UpdateAccount failed: $e');
    }
    if (account.id is int) {
      await DatabaseHelper.instance.updateAccountBalance(account.id, account.balance);
    }
    return true;
  }

  static Future<bool> deleteAccount(dynamic id) async {
    try {
      final token = await getToken();
      await http.delete(Uri.parse('$baseUrl/accounts/$id'), headers: _headers(token)).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API DeleteAccount failed: $e');
    }
    if (id is int) {
      await DatabaseHelper.instance.deleteAccount(id);
    }
    return true;
  }

  // ---- TRANSACTIONS (API First + SQLite Local Merge for Notifications) ----
  static Future<List<TransactionModel>> getTransactions() async {
    List<TransactionModel> apiTxs = [];
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/transactions'), headers: _headers(token)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        List<dynamic> list = jsonDecode(response.body);
        apiTxs = list.map((json) => TransactionModel.fromMap(json)).toList();
      }
    } catch (e) {
      print('API GetTransactions failed: $e');
    }

    final localTxs = await DatabaseHelper.instance.getTransactions();
    _syncNotificationTxsToApi(localTxs, apiTxs);

    return _mergeTransactions(apiTxs, localTxs);
  }

  static Map<String, dynamic> _buildApiTransactionBody(
    TransactionModel tx,
    List<CategoryModel> categories,
    List<Account> accounts,
  ) {
    dynamic apiAccountId = tx.accountId;
    if (accounts.isNotEmpty) {
      final matchingAcc = accounts.firstWhere(
        (a) => a.id.toString() == tx.accountId.toString() || a.accountNumber == tx.accountId.toString(),
        orElse: () => accounts.first,
      );
      if (matchingAcc.id != null) {
        apiAccountId = matchingAcc.id;
      }
    }

    dynamic apiCategoryId;
    final catName = tx.category ?? 'Khác';
    if (categories.isNotEmpty) {
      final matchingCat = categories.firstWhere(
        (c) => c.name.toLowerCase() == catName.toLowerCase() && c.type == tx.type,
        orElse: () => categories.firstWhere(
          (c) => c.type == tx.type,
          orElse: () => categories.first,
        ),
      );
      apiCategoryId = matchingCat.id;
    }

    String? isoTime;
    try {
      DateTime? dt = _parseDateTime(tx.transactionTime);
      if (dt != null) {
        isoTime = dt.toUtc().toIso8601String();
      }
    } catch (_) {}

    return {
      'accountId': apiAccountId,
      if (apiCategoryId != null) 'categoryId': apiCategoryId,
      'type': tx.type,
      'amount': tx.amount,
      'description': tx.description,
      if (isoTime != null) 'transactionTime': isoTime,
      'source': tx.source,
    };
  }

  static Future<void> _syncNotificationTxsToApi(List<TransactionModel> localTxs, List<TransactionModel> apiTxs) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;

      final notifTxs = localTxs.where((tx) => tx.source == 'notification').toList();
      if (notifTxs.isEmpty) return;

      final accounts = await getAccounts();
      final categories = await getCategories();

      for (var tx in notifTxs) {
        bool existsOnApi = apiTxs.any((apiTx) =>
            apiTx.amount == tx.amount &&
            apiTx.transactionTime == tx.transactionTime &&
            apiTx.description == tx.description);

        if (!existsOnApi) {
          try {
            final bodyMap = _buildApiTransactionBody(tx, categories, accounts);
            final response = await http.post(
              Uri.parse('$baseUrl/transactions'),
              headers: _headers(token),
              body: jsonEncode(bodyMap),
            ).timeout(const Duration(seconds: 4));
            print('Synced notification transaction to API server (${response.statusCode}): ${tx.description}');
          } catch (e) {
            print('Sync notification to API failed: $e');
          }
        }
      }
    } catch (e) {
      print('Auto-sync notification error: $e');
    }
  }

  static DateTime? _parseDateTime(String dateStr) {
    try {
      if (dateStr.contains('T') || (dateStr.contains('-') && !dateStr.contains('/'))) {
        return DateTime.parse(dateStr);
      }
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

  static List<TransactionModel> _mergeTransactions(List<TransactionModel> apiList, List<TransactionModel> localList) {
    final Map<String, TransactionModel> map = {};
    for (var tx in apiList) {
      final key = 'api_${tx.id}_${tx.transactionTime}_${tx.amount}';
      map[key] = tx;
    }
    for (var tx in localList) {
      final key = 'local_${tx.id}_${tx.transactionTime}_${tx.amount}';
      map[key] = tx;
    }
    final combined = map.values.toList();
    
    combined.sort((a, b) {
      DateTime? dtA = _parseDateTime(a.transactionTime);
      DateTime? dtB = _parseDateTime(b.transactionTime);
      if (dtA != null && dtB != null) {
        return dtB.compareTo(dtA);
      }
      return 0;
    });

    return combined;
  }

  static Future<bool> insertTransaction(TransactionModel tx) async {
    try {
      final token = await getToken();
      final accounts = await getAccounts();
      final categories = await getCategories();
      final bodyMap = _buildApiTransactionBody(tx, categories, accounts);

      await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: _headers(token),
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API InsertTransaction failed: $e');
    }
    await DatabaseHelper.instance.insertTransaction(tx);
    return true;
  }

  static Future<bool> updateTransaction(TransactionModel tx) async {
    try {
      final token = await getToken();
      final accounts = await getAccounts();
      final categories = await getCategories();
      final bodyMap = _buildApiTransactionBody(tx, categories, accounts);

      if (tx.id != null) {
        await http.put(
          Uri.parse('$baseUrl/transactions/${tx.id}'),
          headers: _headers(token),
          body: jsonEncode(bodyMap),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      print('API UpdateTransaction failed: $e');
    }
    if (tx.id is int) {
      await DatabaseHelper.instance.updateTransactionCategory(tx.id, tx.category ?? 'Khác');
    }
    return true;
  }

  static Future<bool> deleteTransaction(dynamic id) async {
    try {
      final token = await getToken();
      await http.delete(Uri.parse('$baseUrl/transactions/$id'), headers: _headers(token)).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API DeleteTransaction failed: $e');
    }
    if (id is int) {
      await DatabaseHelper.instance.deleteTransaction(id);
    }
    return true;
  }

  static Future<bool> updateTransactionCategory(dynamic id, String category) async {
    try {
      final token = await getToken();
      if (id != null) {
        final categories = await getCategories();
        final catObj = categories.firstWhere((c) => c.name.toLowerCase() == category.toLowerCase(), orElse: () => categories.first);
        await http.put(
          Uri.parse('$baseUrl/transactions/$id'),
          headers: _headers(token),
          body: jsonEncode({'categoryId': catObj.id}),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      print('API UpdateTransactionCategory failed: $e');
    }
    if (id is int) {
      await DatabaseHelper.instance.updateTransactionCategory(id, category);
    }
    return true;
  }

  // ---- CATEGORIES ----
  static Future<List<CategoryModel>> getCategories() async {
    List<CategoryModel> cats = [];
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/categories'), headers: _headers(token)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        List<dynamic> list = jsonDecode(response.body);
        cats = list.map((json) => CategoryModel.fromMap(json)).toList();
      }
    } catch (e) {
      print('API GetCategories failed: $e');
    }

    if (cats.isEmpty) {
      cats = await DatabaseHelper.instance.getCategories();
    }

    bool hasKhacExpense = cats.any((c) => c.name.toLowerCase() == 'khác' && c.type == 'EXPENSE');
    if (!hasKhacExpense) {
      cats.add(CategoryModel(
        id: 'default_khac_expense',
        name: 'Khác',
        type: 'EXPENSE',
        color: '#6B7280',
        icon: 'more_horiz',
      ));
    }

    bool hasKhacIncome = cats.any((c) => c.name.toLowerCase() == 'khác' && c.type == 'INCOME');
    if (!hasKhacIncome) {
      cats.add(CategoryModel(
        id: 'default_khac_income',
        name: 'Khác',
        type: 'INCOME',
        color: '#6B7280',
        icon: 'more_horiz',
      ));
    }

    return cats;
  }

  static Future<bool> insertCategory(CategoryModel category) async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: _headers(token),
        body: jsonEncode({
          'name': category.name,
          'type': category.type,
          'color': category.color,
          'icon': category.icon,
          'isActive': category.isActive == 1,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API InsertCategory failed: $e');
    }
    await DatabaseHelper.instance.insertCategory(category);
    return true;
  }

  static Future<bool> updateCategory(CategoryModel category) async {
    try {
      final token = await getToken();
      if (category.id != null) {
        await http.put(
          Uri.parse('$baseUrl/categories/${category.id}'),
          headers: _headers(token),
          body: jsonEncode({
            'name': category.name,
            'type': category.type,
            'color': category.color,
            'icon': category.icon,
            'isActive': category.isActive == 1,
          }),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      print('API UpdateCategory failed: $e');
    }
    if (category.id is int) {
      await DatabaseHelper.instance.updateCategory(category);
    }
    return true;
  }

  static Future<bool> deleteCategory(dynamic id, String targetCategoryName) async {
    try {
      final token = await getToken();
      await http.delete(Uri.parse('$baseUrl/categories/$id'), headers: _headers(token)).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API DeleteCategory failed: $e');
    }
    if (id is int) {
      await DatabaseHelper.instance.deleteCategorySafe(id, targetCategoryName);
    }
    return true;
  }

  // ---- ADMIN APIS ----
  static Future<Map<String, dynamic>> getAdminUsers({String? search, String? status, int page = 1, int limit = 10}) async {
    try {
      final token = await getToken();
      String url = '$baseUrl/admin/users?page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) url += '&search=$search';
      if (status != null && status.isNotEmpty) url += '&status=$status';

      final response = await http.get(Uri.parse(url), headers: _headers(token));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) {
          return {'items': decoded['data'], 'pagination': decoded['pagination']};
        } else if (decoded is List) {
          return {'items': decoded, 'pagination': null};
        }
      }
    } catch (e) {
      print('GetAdminUsers error: $e');
    }
    return {'items': [], 'pagination': null};
  }

  static Future<bool> lockUser(String userId, String reason) async {
    try {
      final token = await getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/lock'),
        headers: _headers(token),
        body: jsonEncode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('LockUser error: $e');
    }
    return false;
  }

  static Future<bool> unlockUser(String userId) async {
    try {
      final token = await getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/unlock'),
        headers: _headers(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('UnlockUser error: $e');
    }
    return false;
  }

  static Future<bool> deactivateUser(String userId, String reason) async {
    try {
      final token = await getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/deactivate'),
        headers: _headers(token),
        body: jsonEncode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('DeactivateUser error: $e');
    }
    return false;
  }

  static Future<List<dynamic>> getAdminSessions() async {
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/admin/sessions'), headers: _headers(token));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
        if (decoded is List) return decoded;
      }
    } catch (e) {
      print('GetAdminSessions error: $e');
    }
    return [];
  }

  static Future<bool> revokeSession(String sessionId, String reason) async {
    try {
      final token = await getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/sessions/$sessionId/revoke'),
        headers: _headers(token),
        body: jsonEncode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('RevokeSession error: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>?> getSecurityStatistics() async {
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/admin/security/statistics'), headers: _headers(token));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
        if (decoded is Map) return decoded as Map<String, dynamic>;
      }
    } catch (e) {
      print('GetSecurityStatistics error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getSecuritySettings() async {
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/admin/settings/security'), headers: _headers(token));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
        if (decoded is Map) return decoded as Map<String, dynamic>;
      }
    } catch (e) {
      print('GetSecuritySettings error: $e');
    }
    return null;
  }

  static Future<bool> updateSecuritySettings(Map<String, dynamic> settings) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/admin/settings/security'),
        headers: _headers(token),
        body: jsonEncode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('UpdateSecuritySettings error: $e');
    }
    return false;
  }

  static Future<List<dynamic>> getAuditLogs() async {
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/admin/audit-logs'), headers: _headers(token));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
        if (decoded is List) return decoded;
      }
    } catch (e) {
      print('GetAuditLogs error: $e');
    }
    return [];
  }

  static Future<http.Response?> loginWithGoogle(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'), // Điều chỉnh lại endpoint tùy thuộc vào API của backend ASP.NET Core bạn viết
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['accessToken'] ?? data['jwt'];
        final user = data['user'];
        if (token != null) {
          await saveToken(token);
          if (user != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_role', user['role']?.toString() ?? 'User');
            await prefs.setString('user_email', user['email'] ?? '');
          }
        }
      }
      return response;
    } catch (e) {
      print('Login with Google error: $e');
    }
    return null;
  }
}
