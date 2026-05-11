// fileName: lib/screens/teacher_screens.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../api_service.dart';
import 'common_screens.dart';
import 'chat_screens.dart';
import 'interview_screens.dart';
import '../widgets/luminew_header.dart'; // 導入組件

// UI 常數
const Color kLuminewMainPurple = Color(0xFFAD9DC7);
const Color kLuminewGooseYellow = Color(0xFFFFFDF0);
const Color kLuminewDeepIndigo = Color(0xFF675B83);
const Color kCardColor = Colors.white;

const double kRadiusL = 24.0;
const double kRadiusM = 16.0;
const double kRadiusS = 10.0;
const double kRadius = 20.0; // 相容舊代碼

// 主架構
class TeacherMainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const TeacherMainScaffold({
    super.key,
    required this.onLogout,
    required this.user,
  });

  @override
  State<TeacherMainScaffold> createState() => _TeacherMainScaffoldState();
}

class _TeacherMainScaffoldState extends State<TeacherMainScaffold> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TeacherClassScreen(user: widget.user),
      TeacherScheduleScreen(user: widget.user),
      ClassForumScreen(userEmail: widget.user.email),
      InterviewRecordListScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      appBar: null, // 移除全域 AppBar，交由子頁面控制
      body: pages[_idx],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kLuminewMainPurple.withOpacity(0.8), // 同步輕量化 (0.8)
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRadius),
            topRight: Radius.circular(kRadius),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRadius),
            topRight: Radius.circular(kRadius),
          ),
          child: SafeArea(
            bottom: true,
            child: Container(
              height: 75,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.class_outlined, Icons.class_, '班級'),
                  _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month, '排程'),
                  _buildNavItem(2, Icons.chat_bubble_outline, Icons.chat_bubble, '交流'),
                  _buildNavItem(3, Icons.video_library_outlined, Icons.video_library, '紀錄'),
                  _buildNavItem(4, Icons.settings_outlined, Icons.settings, '設定'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _idx == index;
    return GestureDetector(
      onTap: () => setState(() => _idx = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusS),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 班級管理
class TeacherClassScreen extends StatefulWidget {
  final AppUser user;
  const TeacherClassScreen({super.key, required this.user});
  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  List<Class> _list = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      var data = await ApiService.getTeacherClasses(widget.user.email);
      if (mounted) setState(() => _list = data);
    } catch (e) {
      print("讀取失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createClass() async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        title: const Text("建立新班級"),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: "班級名稱",
            hintText: "例如：計算機概論",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (c.text.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await ApiService.createClass(c.text, widget.user.email);
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ 建立成功！"), backgroundColor: Colors.green),
                  );
                }
                await _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("❌ 錯誤: $e"), backgroundColor: Colors.red),
                  );
                }
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kLuminewMainPurple, foregroundColor: Colors.white),
            child: const Text("建立"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLuminewGooseYellow,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            color: kLuminewMainPurple,
            child: _isLoading && _list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: Text(
                              "尚未建立班級\n請點擊右下角新增",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF5A5A5A)),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
                        itemCount: _list.length,
                        itemBuilder: (ctx, i) => _buildClassCardItem(i),
                      ),
          ),
          LuminewHeader(
            title: '班級管理',
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: kLuminewDeepIndigo),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TeacherNotificationsScreen(user: widget.user)),
                ),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: _createClass,
              icon: const Icon(Icons.add),
              label: const Text("新增班級"),
              backgroundColor: kLuminewMainPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCardItem(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kLuminewMainPurple.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.school_rounded, color: kLuminewMainPurple),
        ),
        title: Text(_list[i].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text("點擊管理學生與面試", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeacherClassDetailScreen(cls: _list[i], user: widget.user)),
        ),
      ),
    );
  }
}

// 班級詳情
class TeacherClassDetailScreen extends StatefulWidget {
  final Class cls;
  final AppUser user;
  const TeacherClassDetailScreen({super.key, required this.cls, required this.user});
  @override
  State<TeacherClassDetailScreen> createState() => _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen> {
  List<Student> _students = [];
  final Set<String> _selectedIds = {};
  bool _isAllSelected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      var list = await ApiService.getClassStudents(widget.cls.id);
      if (mounted) setState(() { _students = list; _isLoading = false; _selectedIds.clear(); _isAllSelected = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelectAll(bool? val) {
    setState(() {
      _isAllSelected = val ?? false;
      if (_isAllSelected) _selectedIds.addAll(_students.map((s) => s.id));
      else _selectedIds.clear();
    });
  }

  void _toggleSingle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) _selectedIds.remove(id);
      else _selectedIds.add(id);
      _isAllSelected = _selectedIds.length == _students.length;
    });
  }

  void _sendBulkInvite() {
    if (_selectedIds.isEmpty) return;
    final msgCtrl = TextEditingController(text: "面試時段已開放，請至「預約 Live 面試」搶位！");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text("發送邀請給 ${_selectedIds.length} 人"),
        content: TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: "邀請訊息", border: OutlineInputBorder()), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.sendBulkInvitations(widget.user.email, _selectedIds.toList(), msgCtrl.text);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 邀請已發送！")));
                setState(() { _selectedIds.clear(); _isAllSelected = false; });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ 錯誤: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kLuminewMainPurple, foregroundColor: Colors.white),
            child: const Text("發送"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kLuminewGooseYellow,
        body: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 90), // 預留標頭空間
                Container(
                  color: Colors.white,
                  child: const TabBar(
                    indicatorColor: kLuminewMainPurple,
                    labelColor: kLuminewDeepIndigo,
                    unselectedLabelColor: Colors.grey,
                    tabs: [Tab(text: '名單管理'), Tab(text: '班級聊天')],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMemberManagement(),
                      ClassChatRoom(chatKey: widget.cls.id, userEmail: widget.user.email, title: widget.cls.name, showAppBar: false),
                    ],
                  ),
                ),
              ],
            ),
            LuminewHeader(title: widget.cls.name, showBackButton: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberManagement() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          color: Colors.indigo.shade50,
          child: Column(
            children: [
              const Text("班級邀請碼", style: TextStyle(color: kLuminewDeepIndigo, fontSize: 12)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.cls.invitationCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已複製代碼")));
                },
                child: Text(widget.cls.invitationCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5, color: kLuminewMainPurple)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Checkbox(value: _isAllSelected, onChanged: _students.isEmpty ? null : _toggleSelectAll, activeColor: kLuminewMainPurple),
              const Text("全選學生", style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text("發送邀請 (${_selectedIds.length})"),
                onPressed: _selectedIds.isEmpty ? null : _sendBulkInvite,
                style: ElevatedButton.styleFrom(backgroundColor: _selectedIds.isEmpty ? Colors.grey[300] : kLuminewMainPurple, foregroundColor: Colors.white, elevation: 0),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty
                  ? const Center(child: Text("尚無學生加入"))
                  : ListView.builder(
                      itemCount: _students.length,
                      itemBuilder: (ctx, i) {
                        final s = _students[i];
                        final isChecked = _selectedIds.contains(s.id);
                        return Container(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                          child: ListTile(
                            tileColor: Colors.white,
                            leading: Checkbox(value: isChecked, onChanged: (v) => _toggleSingle(s.id), activeColor: kLuminewMainPurple),
                            title: Text(s.name),
                            subtitle: const Text("尚未進行面試"),
                            onTap: () => _toggleSingle(s.id),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// 預約排程
class TeacherScheduleScreen extends StatefulWidget {
  final AppUser user;
  const TeacherScheduleScreen({super.key, required this.user});
  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  List<InterviewSlot> _slots = [];
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getTeacherSlots(widget.user.email);
      if (mounted) setState(() => _slots = data);
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSlotDialog() async {
    DateTime now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 60)));
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end = start.add(const Duration(minutes: 30));
    await ApiService.addInterviewSlot(widget.user.email, start, end);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("時段已新增")));
    _loadSlots();
  }

  Future<void> _deleteSlot(String id) async {
    await ApiService.deleteSlot(id);
    _loadSlots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlotDialog,
        icon: const Icon(Icons.add),
        label: const Text("新增時段"),
        backgroundColor: kLuminewMainPurple,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadSlots,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 200),
                          Center(child: Text("目前未開放任何時段", style: TextStyle(color: Colors.grey))),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 110, 16, 80),
                        itemCount: _slots.length,
                        itemBuilder: (ctx, i) => _buildSlotCard(_slots[i]),
                      ),
          ),
          const LuminewHeader(title: '預約排程'),
        ],
      ),
    );
  }

  Widget _buildSlotCard(InterviewSlot slot) {
    final dateStr = "${slot.startTime.month}/${slot.startTime.day}";
    final timeStr = "${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: slot.isBooked ? kLuminewMainPurple : Colors.transparent, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: slot.isBooked ? Colors.green[50] : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.access_time_filled, color: slot.isBooked ? Colors.green : Colors.grey),
        ),
        title: Text("$dateStr $timeStr (30分)", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(slot.isBooked ? "預約學生：${slot.bookedByStudentName}" : "等待預約中...", style: TextStyle(color: slot.isBooked ? Colors.black87 : Colors.grey)),
        trailing: slot.isBooked
            ? ElevatedButton(
                onPressed: () => _joinMeeting(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                child: const Text("進入面試"),
              )
            : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteSlot(slot.id)),
      ),
    );
  }

  void _joinMeeting(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text("視訊會議")), body: const Center(child: Text("老師視訊畫面連線中...", style: TextStyle(fontSize: 20))))));
  }
}

// 通知中心
class TeacherNotificationsScreen extends StatelessWidget {
  final AppUser user;
  const TeacherNotificationsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      body: Stack(
        children: [
          FutureBuilder<List<Invitation>>(
            future: ApiService.getInvitations(user.id, true),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.isEmpty) {
                return const Center(child: Text("尚無通知紀錄", style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
                itemCount: snap.data!.length,
                itemBuilder: (ctx, i) {
                  final inv = snap.data![i];
                  final isAccepted = inv.status == 'Accepted';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5),
                      ],
                    ),
                    child: ListTile(
                      title: Text("給: ${inv.studentName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("訊息: ${inv.message}", maxLines: 1),
                      trailing: isAccepted
                          ? ElevatedButton(
                              onPressed: () => _joinMeeting(context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                              child: const Text("進入面試"),
                            )
                          : Chip(
                              label: Text(inv.status),
                              backgroundColor: inv.status == 'Rejected' ? Colors.red[50] : Colors.orange[50],
                              labelStyle: TextStyle(color: inv.status == 'Rejected' ? Colors.red : Colors.orange, fontSize: 12),
                            ),
                    ),
                  );
                },
              );
            },
          ),
          const LuminewHeader(title: '通知紀錄', showBackButton: true),
        ],
      ),
    );
  }

  void _joinMeeting(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text("視訊會議")), body: const Center(child: Text("老師視訊畫面連線中...", style: TextStyle(fontSize: 20))))));
  }
}