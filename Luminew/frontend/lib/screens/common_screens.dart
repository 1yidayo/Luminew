import 'package:flutter/material.dart';
import '../models.dart';
import '../api_service.dart';
import 'student_profile_edit_screen.dart';
import '../widgets/luminew_header.dart'; // 導入統一標頭
import '../theme/app_theme.dart'; // 引入設計系統

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

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const SettingsScreen({super.key, required this.user, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF0),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
            children: [
              // 個人資料區 (全新設計系統版)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.purpleSurface,
                  borderRadius: BorderRadius.circular(AppDesign.radiusL),
                  border: Border.all(color: AppColors.purpleBorder),
                  boxShadow: AppDesign.premiumShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2), width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.surfaceWhite,
                        child: Icon(Icons.account_circle, size: 80, color: AppColors.primaryPurple),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.user.name, style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(widget.user.email, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDesign.radiusCircle),
                        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.5)),
                      ),
                      child: Text(
                        widget.user.role == 'Student' ? '學生帳號' : '教師帳號',
                        style: AppTextStyles.labelTiny,
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
                      builder: (_) => StudentProfileEditScreen(user: widget.user),
                    ),
                  ).then((_) {
                    // 返回後重新整理畫面，確保名字即時變更
                    setState(() {});
                  });
                },
              ),
              _buildDivider(),
              _buildSettingsItem(
                Icons.star_outline_rounded,
                '訂閱方案：${widget.user.subscription}',
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
                widget.onLogout(); // 修正：調用正規登出回呼
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
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.deepIndigo),
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