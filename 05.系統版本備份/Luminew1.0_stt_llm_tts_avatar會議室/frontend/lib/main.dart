import 'package:flutter/material.dart';
import 'sql_service.dart';
import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/student_screens.dart';
import 'screens/teacher_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //SqlService.connect();
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
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
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
