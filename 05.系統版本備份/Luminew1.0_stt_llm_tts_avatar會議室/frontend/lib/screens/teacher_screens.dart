// fileName: lib/screens/teacher_screens.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'chat_screens.dart';
import 'interview_screens.dart';

// UI 常數
const Color kPrimaryColor = Color(0xFF3F51B5);
const Color kBackgroundColor = Color(0xFFF8F9FB);
const Color kCardColor = Colors.white;
const double kRadius = 16.0;

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
      ClassChatRoom(
        chatKey: 'public',
        userEmail: widget.user.email,
        title: '公共交流',
        showAppBar: false,
      ),
      InterviewRecordListScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _idx == 2
          ? null
          : AppBar(
              title: Text(
                ['班級管理', '預約排程', '交流', '面試紀錄', '設定'][_idx],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TeacherNotificationsScreen(user: widget.user),
                    ),
                  ),
                ),
              ],
            ),
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: kPrimaryColor.withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_),
            label: '班級',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '排程',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '交流',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: '紀錄',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
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
      var data = await SqlService.getTeacherClasses(widget.user.email);
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
              
              // 1. 先關閉對話框
              Navigator.pop(ctx);
              
              // 2. 顯示轉圈圈
              setState(() => _isLoading = true);
              
              try {
                // 3. 請求資料庫建立 (這裡會呼叫 sql_service.dart 去 INSERT Classes)
                await SqlService.createClass(c.text, widget.user.email);

                // 4. ★★★ 關鍵：等待 0.5 秒讓資料庫寫入完成 ★★★
                await Future.delayed(const Duration(milliseconds: 500));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ 建立成功！"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                
                // 5. 重新讀取 (這時候資料庫已經有資料了，所以列表會出現)
                await _load();

              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("❌ 錯誤: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                // 失敗也要把轉圈圈關掉
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("建立"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClass,
        icon: const Icon(Icons.add),
        label: const Text("新增班級"),
        backgroundColor: kPrimaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: kPrimaryColor,
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
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _list.length,
                itemBuilder: (ctx, i) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(kRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: kPrimaryColor,
                      ),
                    ),
                    title: Text(
                      _list[i].name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      "點擊管理學生與面試",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherClassDetailScreen(
                          cls: _list[i],
                          user: widget.user,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// 班級詳情
class TeacherClassDetailScreen extends StatefulWidget {
  final Class cls;
  final AppUser user;
  const TeacherClassDetailScreen({
    super.key,
    required this.cls,
    required this.user,
  });
  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
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
      var list = await SqlService.getClassStudents(widget.cls.id);
      if (mounted)
        setState(() {
          _students = list;
          _isLoading = false;
          _selectedIds.clear();
          _isAllSelected = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelectAll(bool? val) {
    setState(() {
      _isAllSelected = val ?? false;
      if (_isAllSelected) {
        _selectedIds.addAll(_students.map((s) => s.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSingle(String id) {
    setState(() {
      if (_selectedIds.contains(id))
        _selectedIds.remove(id);
      else
        _selectedIds.add(id);
      _isAllSelected = _selectedIds.length == _students.length;
    });
  }

  void _sendBulkInvite() {
    if (_selectedIds.isEmpty) return;
    final msgCtrl = TextEditingController(text: "面試時段已開放，請至「預約 Live 面試」搶位！");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        title: Text("發送邀請給 ${_selectedIds.length} 人"),
        content: TextField(
          controller: msgCtrl,
          decoration: const InputDecoration(
            labelText: "邀請訊息",
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SqlService.sendBulkInvitations(
                  widget.user.email,
                  _selectedIds.toList(),
                  msgCtrl.text,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("✅ 邀請已發送！")));
                setState(() {
                  _selectedIds.clear();
                  _isAllSelected = false;
                });
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("❌ 錯誤: $e")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
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
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: Text(widget.cls.name),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            indicatorColor: kPrimaryColor,
            labelColor: kPrimaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: '名單管理'),
              Tab(text: '班級聊天'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  color: Colors.indigo.shade50,
                  child: Column(
                    children: [
                      const Text(
                        "班級邀請碼",
                        style: TextStyle(color: Colors.indigo, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.cls.invitationCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("已複製代碼")),
                          );
                        },
                        child: Text(
                          widget.cls.invitationCode,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _isAllSelected,
                        onChanged: _students.isEmpty ? null : _toggleSelectAll,
                        activeColor: kPrimaryColor,
                      ),
                      const Text(
                        "全選學生",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text("發送邀請 (${_selectedIds.length})"),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : _sendBulkInvite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedIds.isEmpty
                              ? Colors.grey[300]
                              : kPrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
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
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.black12),
                                ),
                              ),
                              child: ListTile(
                                tileColor: Colors.white,
                                leading: Checkbox(
                                  value: isChecked,
                                  onChanged: (v) => _toggleSingle(s.id),
                                  activeColor: kPrimaryColor,
                                ),
                                title: Text(s.name),
                                subtitle: const Text("尚未進行面試"),
                                onTap: () => _toggleSingle(s.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            ClassChatRoom(
              chatKey: widget.cls.id,
              userEmail: widget.user.email,
              title: widget.cls.name,
              showAppBar: false,
            ),
          ],
        ),
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
      final data = await SqlService.getTeacherSlots(widget.user.email);
      if (mounted) setState(() => _slots = data);
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSlotDialog() async {
    DateTime now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final end = start.add(const Duration(minutes: 30));
    await SqlService.addInterviewSlot(widget.user.email, start, end);
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("時段已新增")));
    _loadSlots();
  }

  Future<void> _deleteSlot(String id) async {
    await SqlService.deleteSlot(id);
    _loadSlots();
  }

  void _joinMeeting(String slotId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("視訊會議")),
          body: const Center(
            child: Text("老師視訊畫面連線中...", style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlotDialog,
        icon: const Icon(Icons.add),
        label: const Text("新增時段"),
        backgroundColor: kPrimaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSlots,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _slots.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      "目前未開放任何時段",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _slots.length,
                itemBuilder: (ctx, i) {
                  final slot = _slots[i];
                  final dateStr =
                      "${slot.startTime.month}/${slot.startTime.day}";
                  final timeStr =
                      "${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(
                        color: slot.isBooked
                            ? kPrimaryColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: slot.isBooked
                              ? Colors.green[50]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.access_time_filled,
                          color: slot.isBooked ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text(
                        "$dateStr $timeStr (30分)",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        slot.isBooked
                            ? "預約學生：${slot.bookedByStudentName}"
                            : "等待預約中...",
                        style: TextStyle(
                          color: slot.isBooked ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      trailing: slot.isBooked
                          ? ElevatedButton(
                              onPressed: () => _joinMeeting(slot.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text("進入面試"),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteSlot(slot.id),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// 通知中心
class TeacherNotificationsScreen extends StatelessWidget {
  final AppUser user;
  const TeacherNotificationsScreen({super.key, required this.user});
  void _joinMeeting(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("視訊會議")),
          body: const Center(
            child: Text("老師視訊畫面連線中...", style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("邀請紀錄"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<Invitation>>(
        future: SqlService.getInvitations(user.id, true),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) return const Center(child: Text("無通知紀錄"));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(
                    "給: ${inv.studentName}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("訊息: ${inv.message}", maxLines: 1),
                  trailing: isAccepted
                      ? ElevatedButton(
                          onPressed: () => _joinMeeting(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text("進入面試"),
                        )
                      : Chip(
                          label: Text(inv.status),
                          backgroundColor: inv.status == 'Rejected'
                              ? Colors.red[50]
                              : Colors.orange[50],
                          labelStyle: TextStyle(
                            color: inv.status == 'Rejected'
                                ? Colors.red
                                : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}