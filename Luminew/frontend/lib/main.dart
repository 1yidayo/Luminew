import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/student_screens.dart';
import 'screens/teacher_screens.dart';

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
          ? AuthScreen(onAuthSuccess: (u) => setState(() => _currentUser = u))
          : _currentUser!.role == 'Teacher'
          ? TeacherMainScaffold(
              onLogout: () => setState(() => _currentUser = null),
              user: _currentUser!,
            )
          : StudentMainScaffold(
              onLogout: () => setState(() => _currentUser = null),
              user: _currentUser!,
            ),
    );
  }
}
