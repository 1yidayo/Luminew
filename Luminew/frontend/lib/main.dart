import 'package:flutter/material.dart';
import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/student_screens.dart';
import 'screens/teacher_screens.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //// ApiService.connect();
  runApp(const LuminewApp());
}

class LuminewApp extends StatefulWidget {
  const LuminewApp({super.key});
  @override
  State<LuminewApp> createState() => _LuminewAppState();
}

class _LuminewAppState extends State<LuminewApp> {
  AppUser? _currentUser;
  bool _showSplash = false; // 登入後才為 true，顯示一次待機畫面

  void _onAuthSuccess(AppUser user) {
    setState(() {
      _currentUser = user;
      // _showSplash = true; // 觸發待機畫面
    });
  }

  Widget _buildMainScaffold() {
    if (_currentUser!.role == 'Teacher') {
      return TeacherMainScaffold(
        onLogout: () => setState(() {
          _currentUser = null;
          _showSplash = false;
        }),
        user: _currentUser!,
      );
    } else {
      return StudentMainScaffold(
        onLogout: () => setState(() {
          _currentUser = null;
          _showSplash = false;
        }),
        user: _currentUser!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luminew',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFAD9DC7),
          primary: const Color(0xFFAD9DC7),
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F3FF),
        useMaterial3: true,
      ),
      home: _currentUser == null
          // 未登入 → 顯示登入頁
          ? AuthScreen(onAuthSuccess: _onAuthSuccess)
          // 登入後直接顯示主頁
          : _buildMainScaffold(),
    );
  }
}
