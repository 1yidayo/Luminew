import 'package:flutter/material.dart';
import '../sql_service.dart';
import '../models.dart';

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
  bool _isLoggingIn = true; // true=登入模式, false=註冊模式
  bool _isLoading = false;
  String? _errorMessage;

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
      if (email.isEmpty || password.isEmpty) {
        throw Exception("帳號與密碼不能為空");
      }

      if (_isLoggingIn) {
        // 🟢 登入模式
        AppUser? user = await SqlService.login(email, password);
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
        await SqlService.registerUser(email, password, name, roleStr);

        // 2. 註冊成功後，自動執行登入
        AppUser? user = await SqlService.login(email, password);
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
      appBar: AppBar(
        title: Text(_isLoggingIn ? '登入系統' : '註冊帳號'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- 只有「註冊」時才顯示：角色選擇 & 姓名 ---
              if (!_isLoggingIn) ...[
                _buildRoleSelector(),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // --- Email 輸入框 ---
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '電子郵件',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 15),

              // --- 密碼 輸入框 ---
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _isLoggingIn ? '密碼' : '設定密碼',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 30),

              // --- 錯誤訊息顯示 ---
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

              // --- 登入/註冊 按鈕 ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
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

              // --- 切換模式按鈕 ---
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoggingIn = !_isLoggingIn;
                    _errorMessage = null; // 切換時清空錯誤訊息
                  });
                },
                child: Text(
                  _isLoggingIn ? '沒有帳號？點此註冊' : '已有帳號？點此登入',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 角色選擇器 UI
  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
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
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
