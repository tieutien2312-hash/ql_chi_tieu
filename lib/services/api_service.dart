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

    // Always fetch local SQLite accounts (which includes auto-captured notification accounts)
    final localAccounts = await DatabaseHelper.instance.getAccounts();
    return _mergeAccounts(apiAccounts, localAccounts);
  }

  static List<Account> _mergeAccounts(List<Account> apiList, List<Account> localList) {
    final Map<String, Account> map = {};
    for (var acc in apiList) {
      map[acc.accountNumber] = acc;
    }
    for (var acc in localList) {
      map[acc.accountNumber] = acc; // local takes precedence or combines
    }
    return map.values.toList();
  }

  static Future<bool> insertAccount(Account account) async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('$baseUrl/accounts'),
        headers: _headers(token),
        body: jsonEncode(account.toMap()),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API InsertAccount failed: $e');
    }
    await DatabaseHelper.instance.insertAccount(account);
    return true;
  }

  static Future<bool> deleteAccount(int id) async {
    try {
      final token = await getToken();
      await http.delete(Uri.parse('$baseUrl/accounts/$id'), headers: _headers(token)).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API DeleteAccount failed: $e');
    }
    await DatabaseHelper.instance.deleteAccount(id);
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

    // Always fetch local SQLite transactions (which contains bank notification listener captures)
    final localTxs = await DatabaseHelper.instance.getTransactions();
    return _mergeTransactions(apiTxs, localTxs);
  }

  static List<TransactionModel> _mergeTransactions(List<TransactionModel> apiList, List<TransactionModel> localList) {
    final Map<String, TransactionModel> map = {};
    for (var tx in apiList) {
      final key = '${tx.transactionTime}_${tx.amount}_${tx.description}';
      map[key] = tx;
    }
    for (var tx in localList) {
      final key = '${tx.transactionTime}_${tx.amount}_${tx.description}';
      map[key] = tx; // local SQLite notification captures included
    }
    final combined = map.values.toList();
    combined.sort((a, b) => b.id.toString().compareTo(a.id.toString()));
    return combined;
  }

  static Future<bool> insertTransaction(TransactionModel tx) async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: _headers(token),
        body: jsonEncode(tx.toMap()),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API InsertTransaction failed: $e');
    }
    await DatabaseHelper.instance.insertTransaction(tx);
    return true;
  }

  static Future<bool> deleteTransaction(dynamic id) async {
    try {
      final token = await getToken();
      if (id is int) {
        await http.delete(Uri.parse('$baseUrl/transactions/$id'), headers: _headers(token)).timeout(const Duration(seconds: 4));
        await DatabaseHelper.instance.deleteTransaction(id);
      }
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
      if (id is int) {
        await http.put(
          Uri.parse('$baseUrl/transactions/$id/category'),
          headers: _headers(token),
          body: jsonEncode({'category': category}),
        ).timeout(const Duration(seconds: 4));
        await DatabaseHelper.instance.updateTransactionCategory(id, category);
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
    try {
      final token = await getToken();
      final response = await http.get(Uri.parse('$baseUrl/categories'), headers: _headers(token)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => CategoryModel.fromMap(json)).toList();
      }
    } catch (e) {
      print('API GetCategories failed: $e');
    }
    return await DatabaseHelper.instance.getCategories();
  }

  static Future<bool> insertCategory(CategoryModel category) async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: _headers(token),
        body: jsonEncode(category.toMap()),
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
      await http.put(
        Uri.parse('$baseUrl/categories/${category.id}'),
        headers: _headers(token),
        body: jsonEncode(category.toMap()),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API UpdateCategory failed: $e');
    }
    await DatabaseHelper.instance.updateCategory(category);
    return true;
  }

  static Future<bool> deleteCategory(int id, String targetCategoryName) async {
    try {
      final token = await getToken();
      await http.delete(Uri.parse('$baseUrl/categories/$id'), headers: _headers(token)).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('API DeleteCategory failed: $e');
    }
    await DatabaseHelper.instance.deleteCategorySafe(id, targetCategoryName);
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
}
