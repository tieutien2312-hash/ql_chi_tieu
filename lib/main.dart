import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final token = await ApiService.getToken();
  final role = await ApiService.getUserRole();

  Widget initialScreen;
  if (token == null || token.isEmpty) {
    // Không có token -> Về trang đăng nhập
    initialScreen = const LoginScreen();
  } else {
    String normalizedRole = role.toLowerCase().trim();
    if (normalizedRole == 'admin' || role == '1') {
      // Nếu là Admin -> Điều hướng về Dashboard Admin
      initialScreen = const AdminDashboardScreen();
    } else if (normalizedRole == 'user' || normalizedRole == 'member' || role == '0' || normalizedRole.isNotEmpty) {
      // Nếu là User -> Điều hướng vào trang chủ của User (MainScreen)
      initialScreen = const MainScreen();
    } else {
      // Nếu không phải 2 quyền trên -> Về trang đăng nhập
      initialScreen = const LoginScreen();
    }
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý chi tiêu',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialScreen,
    );
  }
}
