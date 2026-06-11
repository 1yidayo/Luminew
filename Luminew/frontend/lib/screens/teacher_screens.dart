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
      TeacherStudentScreen(user: widget.user),
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
                  _buildNavItem(0, Icons.people_outlined, Icons.people, '學生'),
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

// 學生管理
class TeacherStudentScreen extends StatefulWidget {
  final AppUser user;
  const TeacherStudentScreen({super.key, required this.user});
  @override
  State<TeacherStudentScreen> createState() => _TeacherStudentScreenState();
}

class _TeacherStudentScreenState extends State<TeacherStudentScreen> {
  List<Student> _students = [];
  String _teacherCode = "";
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
      final p = await ApiService.getTeacherProfile(widget.user.email);
      _teacherCode = p['TeacherCode'] ?? '';
      _students = await ApiService.getTeacherStudents(widget.user.email);
    } catch (e) {
      print("讀取失敗: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            child: _isLoading && _students.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
                    children: [
                      // 邀請碼區塊
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: kLuminewMainPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(kRadius),
                        ),
                        child: Column(
                          children: [
                            const Text("我的專屬老師邀請碼", style: TextStyle(color: kLuminewDeepIndigo, fontSize: 14)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _teacherCode));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已複製邀請碼")));
                              },
                              child: Text(
                                _teacherCode, 
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5, color: kLuminewMainPurple)
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text("我的學生", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kLuminewDeepIndigo)),
                      ),
                      const SizedBox(height: 10),
                      if (_students.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text("目前還沒有學生加入喔！", style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ..._students.map((s) => _buildStudentCardItem(s)),
                    ],
                  ),
          ),
          LuminewHeader(
            title: '我的學生',
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
        ],
      ),
    );
  }

  Widget _buildStudentCardItem(Student s) {
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
          child: const Icon(Icons.person_rounded, color: kLuminewMainPurple),
        ),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text("點擊查看面試紀錄", style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeacherStudentRecordsScreen(student: s, user: widget.user)),
        ),
      ),
    );
  }
}

class TeacherStudentRecordsScreen extends StatefulWidget {
  final Student student;
  final AppUser user;
  const TeacherStudentRecordsScreen({super.key, required this.student, required this.user});
  @override
  State<TeacherStudentRecordsScreen> createState() => _TeacherStudentRecordsScreenState();
}

class _TeacherStudentRecordsScreenState extends State<TeacherStudentRecordsScreen> {
  List<InterviewRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      var list = await ApiService.getTeacherRecords(widget.user.email, widget.student.id);
      if (mounted) setState(() { _records = list; });
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                  ? const Center(child: Text("該學生尚未向您公開任何紀錄", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
                      itemCount: _records.length,
                      itemBuilder: (ctx, i) {
                        final rec = _records[i];
                        return InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InterviewResultScreen(
                                record: rec,
                                user: widget.user,
                              ),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rec.date.toIso8601String().split('T')[0],
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    Text(
                                      '分數: ${rec.overallScore}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: kLuminewDeepIndigo),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rec.type,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kLuminewDeepIndigo),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          LuminewHeader(title: "${widget.student.name} 的面試紀錄", showBackButton: true),
        ],
      ),
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