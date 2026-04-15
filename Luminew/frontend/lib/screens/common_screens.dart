import 'package:flutter/material.dart';
import '../models.dart';
import '../api_service.dart';
import 'student_profile_edit_screen.dart';
import '../widgets/luminew_header.dart'; // 導入統一標頭

// 通知中心
class NotificationCenter extends StatelessWidget {
  final AppUser user;
  final bool isTeacher;
  const NotificationCenter({
    super.key,
    required this.user,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF0),
      appBar: AppBar(
        title: const Text("通知中心"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF675B83),
      ),
      body: FutureBuilder<List<Invitation>>(
        future: ApiService.getInvitations(user.id, isTeacher),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data!.isEmpty) return const Center(child: Text("無新通知"));
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (ctx, i) {
              var inv = snap.data![i];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.red,
                  ),
                  title: Text(
                    isTeacher
                        ? "${inv.studentName} 回應了邀請"
                        : "${inv.teacherName} 邀請你面試",
                  ),
                  subtitle: Text(inv.message),
                  trailing: (!isTeacher && inv.status == 'Pending')
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () async {
                                await ApiService.updateInvitation(
                                  inv.id,
                                  'Accepted',
                                );
                                // 這裡可以跳轉到面試設定
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await ApiService.updateInvitation(
                                  inv.id,
                                  'Rejected',
                                );
                              },
                            ),
                          ],
                        )
                      : Text(inv.status),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ... (previous classes omitted for brevity in replace_file_content)

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const SettingsScreen({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF0),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
            children: [
              // 個人資料區 (V5 極簡線性設計)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFAD9DC7,
                  ).withOpacity(0.30), // 與交流頁面卡片同步 (0.15)
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAD9DC7).withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.account_circle,
                        size: 80,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF675B83), // 改回深紫色
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(
                          0xFF675B83,
                        ).withOpacity(0.7), // 改回深紫色 (半透明)
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 與郵件同步的「品牌紫」身份標籤
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent, // 改回絕對透明
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(
                            0xFF675B83,
                          ).withOpacity(0.7), // 深紫色邊框
                          width: 1,
                        ),
                      ),
                      child: Text(
                        user.role == 'Student' ? '學生帳號' : '教師帳號',
                        style: TextStyle(
                          color: const Color(
                            0xFF675B83,
                          ).withOpacity(0.7), // 同步改為深紫色文字 (0.3 透明度)
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSettingsItem(
                Icons.person_outline_rounded,
                '編輯使用者資料',
                const Color(0xFFAD9DC7),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentProfileEditScreen(user: user),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildSettingsItem(
                Icons.star_outline_rounded,
                '訂閱方案：${user.subscription}',
                Colors.orange,
                () {},
              ),
              _buildDivider(),
              _buildSettingsItem(
                Icons.notifications_none,
                '推播設定',
                const Color(0xFFAD9DC7),
                () {},
              ),
              _buildDivider(),
              _buildSettingsItem(
                Icons.help_outline,
                '幫助與回饋',
                const Color(0xFFAD9DC7),
                () {},
              ),
              _buildDivider(),
              _buildSettingsItem(Icons.logout, '登出帳號', Colors.redAccent, () {
                onLogout(); // 修正：調用正規登出回呼
              }),
            ],
          ),
          const LuminewHeader(title: '設定'),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Divider(color: Colors.grey.withOpacity(0.15), height: 1),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF675B83),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
// ClassChatRoom 保持在 chat_screens.dart