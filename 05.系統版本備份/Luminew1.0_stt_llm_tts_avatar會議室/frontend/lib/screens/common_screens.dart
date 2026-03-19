import 'package:flutter/material.dart';
import '../models.dart';
import '../sql_service.dart';

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
      appBar: AppBar(title: const Text("通知中心")),
      body: FutureBuilder<List<Invitation>>(
        future: SqlService.getInvitations(user.id, isTeacher),
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
                                await SqlService.updateInvitation(
                                  inv.id,
                                  'Accepted',
                                );
                                // 這裡可以跳轉到面試設定
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await SqlService.updateInvitation(
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

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const SettingsScreen({super.key, required this.onLogout, required this.user});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text("${user.name} (${user.role})"),
            accountEmail: Text(user.email),
            currentAccountPicture: CircleAvatar(child: Text(user.name[0])),
            decoration: const BoxDecoration(color: Colors.indigo),
          ),
          ListTile(
            title: const Text("訂閱狀態"),
            subtitle: Text(user.subscription),
            trailing: ElevatedButton(onPressed: () {}, child: const Text("升級")),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
// ClassChatRoom 保持在 chat_screens.dart