import 'dart:ui';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../widgets/luminew_header.dart'; // 導入新組件

enum UserRole { student, teacher }

class AuthScreen extends StatefulWidget {
  final Function(AppUser) onAuthSuccess;
  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // 文字控制器
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // 狀態變數
  UserRole _selectedRole = UserRole.student;
  bool _isLoggingIn = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailError = false;
  bool _isNameError = false;      // ★ 新增：姓名錯誤狀態
  bool _isPasswordError = false;  // ★ 新增：密碼錯誤狀態

  final GlobalKey _emailKey = GlobalKey();
  final GlobalKey _nameKey = GlobalKey();     // ★ 新增：姓名跳轉 Key
  final GlobalKey _passwordKey = GlobalKey(); // ★ 新增：密碼跳轉 Key

  // 處理登入/註冊邏輯
  Future<void> _handleAuth() async {
    // 收起鍵盤
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      // 重置所有錯誤狀態
      setState(() {
        _isNameError = false;
        _isEmailError = false;
        _isPasswordError = false;
      });

      // 1. 驗證姓名 (僅註冊模式)
      if (!_isLoggingIn && name.isEmpty) {
        setState(() => _isNameError = true);
        Scrollable.ensureVisible(_nameKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        throw Exception("姓名不可為空");
      }

      // 2. 驗證電子郵件
      if (email.isEmpty) {
        setState(() => _isEmailError = true);
        Scrollable.ensureVisible(_emailKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        throw Exception("電子郵件不可為空");
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        setState(() => _isEmailError = true);
        Scrollable.ensureVisible(_emailKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        throw Exception("請輸入正確的電子郵件格式");
      }

      // 3. 驗證密碼
      if (password.isEmpty) {
        setState(() => _isPasswordError = true);
        Scrollable.ensureVisible(_passwordKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        throw Exception("密碼不可為空");
      }

      if (_isLoggingIn) {
        // 🟢 登入模式
        AppUser? user = await ApiService.login(email, password);
        if (user != null) {
          widget.onAuthSuccess(user);
        } else {
          throw Exception("帳號或密碼錯誤");
        }
      } else {
        // 🔵 註冊模式
        if (name.isEmpty) throw Exception("請輸入姓名");

        // 將 Enum 轉成資料庫儲存的字串 ('Student' 或 'Teacher')
        String roleStr = _selectedRole == UserRole.student
            ? 'Student'
            : 'Teacher';

        // 1. 寫入資料庫
        await ApiService.registerUser(email, password, name, roleStr);

        // 2. 註冊成功後，自動執行登入
        AppUser? user = await ApiService.login(email, password);
        if (user != null) {
          widget.onAuthSuccess(user);
        }
      }
    } catch (e) {
      setState(() {
        // 去掉 "Exception: " 字樣，讓錯誤訊息比較好看
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF0),
      body: Stack(
        children: [
          // --- 主要表單內容 ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 120, 32, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 模式標題 (登入/註冊) ---
                  Center(
                    child: Text(
                      _isLoggingIn ? '登入' : '註冊',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAD9DC7), // 回歸原本的紫色標題
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- 註冊專用欄位 ---
                  if (!_isLoggingIn) ...[
                    _buildRoleSelector(),
                    const SizedBox(height: 20),
                    TextField(
                      key: _nameKey,
                      controller: _nameController,
                      style: const TextStyle(color: Color(0xFF5A5A5A)), // 輸入文字改為深灰色
                      decoration: InputDecoration(
                        labelText: '姓名',
                        labelStyle: const TextStyle(color: Color(0xFF5A5A5A)), // 標籤改為深灰色
                        prefixIcon: const Icon(Icons.badge),
                        prefixIconColor: MaterialStateColor.resolveWith((
                          states,
                        ) {
                          if (_isNameError) return Colors.red;
                          if (states.contains(MaterialState.focused))
                            return const Color(0xFFAD9DC7);
                          return const Color(0xFF5A5A5A); // 同步改為深灰色
                        }),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          borderSide: BorderSide(
                            color: _isNameError ? Colors.red : Colors.grey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          borderSide: BorderSide(
                            color: _isNameError
                                ? Colors.red
                                : Colors.grey.shade400,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          borderSide: BorderSide(
                            color: _isNameError
                                ? Colors.red
                                : const Color(0xFFAD9DC7),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_isNameError) setState(() => _isNameError = false);
                      },
                    ),
                    const SizedBox(height: 15),
                  ],

                  // --- Email 輸入框 ---
                    TextField(
                      key: _emailKey,
                      controller: _emailController,
                      style: const TextStyle(color: Color(0xFF5A5A5A)), // 改為深灰色
                      decoration: InputDecoration(
                        labelText: '電子郵件',
                        labelStyle: const TextStyle(color: Color(0xFF5A5A5A)),
                        prefixIcon: const Icon(Icons.email),
                        prefixIconColor: MaterialStateColor.resolveWith((states) {
                          if (_isEmailError) return Colors.red;
                          if (states.contains(MaterialState.focused))
                            return const Color(0xFFAD9DC7);
                          return const Color(0xFF5A5A5A); // 改為灰色
                        }),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        borderSide: BorderSide(
                          color: _isEmailError ? Colors.red : Colors.grey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        borderSide: BorderSide(
                          color: _isEmailError
                              ? Colors.red
                              : Colors.grey.shade400,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        borderSide: BorderSide(
                          color: _isEmailError
                              ? Colors.red
                              : const Color(0xFFAD9DC7),
                          width: 2,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_isEmailError) setState(() => _isEmailError = false);
                    },
                  ),
                  const SizedBox(height: 15),

                  // --- 密碼 輸入框 ---
                  TextField(
                    key: _passwordKey,
                    controller: _passwordController,
                    style: const TextStyle(color: Color(0xFF5A5A5A)), // 改為深灰色
                    decoration: InputDecoration(
                      labelText: _isLoggingIn ? '密碼' : '設定密碼',
                      labelStyle: const TextStyle(color: Color(0xFF5A5A5A)),
                      prefixIcon: const Icon(Icons.lock),
                      prefixIconColor: MaterialStateColor.resolveWith((states) {
                        if (_isPasswordError) return Colors.red;
                        if (states.contains(MaterialState.focused))
                          return const Color(0xFFAD9DC7);
                        return const Color(0xFF5A5A5A); // 改為灰色
                      }),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        borderSide: BorderSide(
                          color: _isPasswordError ? Colors.red : Colors.grey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        borderSide: BorderSide(
                          color: _isPasswordError
                              ? Colors.red
                              : Colors.grey.shade400,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        borderSide: BorderSide(
                          color: _isPasswordError
                              ? Colors.red
                              : const Color(0xFFAD9DC7),
                          width: 2,
                        ),
                      ),
                    ),
                    obscureText: true,
                    onChanged: (_) {
                      if (_isPasswordError)
                        setState(() => _isPasswordError = false);
                    },
                  ),
                  const SizedBox(height: 30),

                  // --- 錯誤訊息 ---
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // --- 送出按鈕 ---
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFAD9DC7),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            _isLoggingIn ? '登入' : '註冊',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),

                  // --- 切換模式 ---
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoggingIn = !_isLoggingIn;
                        _errorMessage = null;
                        _isEmailError = false;
                      });
                    },
                    child: Text(
                      _isLoggingIn ? '沒有帳號？點此註冊' : '已有帳號？點此登入',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5A5A5A), // 改為統一深灰色
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- 標頭 ---
          LuminewHeader(
            title: 'Luminew',
            centerTitle: true,
            textColor: const Color(0xFF675B83), // 這裡使用深紫色 (kLuminewDeepIndigo) 比較顯眼且穩定
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ],
      ),
    );
  }


  // 角色選擇器 UI
  Widget _buildRoleSelector() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RoleOption(
            title: '學生',
            icon: Icons.person_outline,
            isSelected: _selectedRole == UserRole.student,
            onTap: () => setState(() => _selectedRole = UserRole.student),
          ),
          _RoleOption(
            title: '教師',
            icon: Icons.school_outlined,
            isSelected: _selectedRole == UserRole.teacher,
            onTap: () => setState(() => _selectedRole = UserRole.teacher),
          ),
        ],
      ),
    );
  }
}

// 自訂角色選擇按鈕元件
class _RoleOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : const Color(0xFF5A5A5A), // 未選中改為深灰色
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
