import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialize error: $e');
  }
  await AppSettingsController.instance.loadSettings();
  
  final token = await ApiService.getToken();
  final role = await ApiService.getUserRole();
  
  Widget initialScreen;
  if (token != null && token.isNotEmpty) {
    if (role == 'Admin') {
      initialScreen = const AdminDashboardScreen();
    } else {
      initialScreen = const MainScreen();
    }
  } else {
    initialScreen = const LoginScreen();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final settings = AppSettingsController.instance;
        return MaterialApp(
          title: 'Moni',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.primaryColor,
              primary: settings.primaryColor,
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              foregroundColor: Color(0xFF202432),
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.fontSizeScale),
              ),
              child: child!,
            );
          },
          home: initialScreen,
        );
      },
    );
  }
}
