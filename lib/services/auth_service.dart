import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '992371026241-3kdrjob3e2av2klva8lt1g88hsjiinjg.apps.googleusercontent.com',
  );

  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // 1. Mở popup đăng nhập Google trên điện thoại
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // Người dùng hủy thao tác

      // 2. Lấy idToken xác thực
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        // 3. Gửi idToken về ASP.NET Core Backend để tạo/xác thực tài khoản và nhận JWT
        final response = await ApiService.loginWithGoogle(idToken);
        if (response?.statusCode == 200) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Xin chào ${googleUser.displayName}!')),
            );
          }
        }
      }
    } catch (error) {
      debugPrint('Lỗi đăng nhập Google: $error');
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}