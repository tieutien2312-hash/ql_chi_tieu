import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '992371026241-3kdrjob3e2av2klva8lt1g88hsjiinjg.apps.googleusercontent.com',
  );

  /// Đăng nhập bằng Google và trả về role của người dùng ('User' / 'Admin')
  static Future<String?> signInWithGoogle(BuildContext context) async {
    try {
      // Reset phiên đăng nhập cũ để luôn hiển thị màn hình chọn tài khoản Google
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 1. Mở popup đăng nhập Google trên điện thoại
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Người dùng hủy thao tác

      // 2. Lấy idToken xác thực từ Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      String userRole = 'User';

      if (idToken != null) {
        // 3. Gửi idToken về Backend để xác thực và nhận JWT Token
        final response = await ApiService.loginWithGoogle(idToken);
        if (response != null && response.statusCode == 200) {
          userRole = await ApiService.getUserRole();
        } else {
          // Fallback khi backend offline hoặc không trả về token 200
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', googleUser.email);
          await prefs.setString('user_role', 'User');
        }
      } else {
        // Fallback lưu session cục bộ
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', googleUser.email);
        await prefs.setString('user_role', 'User');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xin chào ${googleUser.displayName}!')),
        );
      }

      return userRole;
    } catch (error) {
      debugPrint('Lỗi đăng nhập Google: $error');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
