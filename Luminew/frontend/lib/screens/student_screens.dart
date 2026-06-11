// fileName: lib/screens/student_screens.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models.dart';
import '../api_service.dart';
import 'common_screens.dart';
import 'interview_screens.dart';
import 'chat_screens.dart';
import '../widgets/luminew_header.dart'; // 導入標頭組件
import '../theme/app_theme.dart'; // 引入設計系統

const Color kLuminewMainPurple = Color(0xFFAD9DC7);
const Color kLuminewGooseYellow = Color(0xFFFFFDF0);
const Color kLuminewDeepIndigo = Color(0xFF675B83);

const double kRadiusL = 24.0;
const double kRadiusM = 16.0;
const double kRadiusS = 10.0;
const double kRadius = 20.0; // 相容舊代碼

// ==========================================
// 1. 學生端主架構
// ==========================================
class StudentMainScaffold extends StatefulWidget {
  final VoidCallback onLogout;
  final AppUser user;
  const StudentMainScaffold({
    super.key,
    required this.onLogout,
    required this.user,
  });

  @override
  State<StudentMainScaffold> createState() => _StudentMainScaffoldState();
}

class _StudentMainScaffoldState extends State<StudentMainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      InterviewHomePage(user: widget.user),
      ClassForumScreen(userEmail: widget.user.email),
      InterviewRecordListScreen(user: widget.user),
      StudentTeacherScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      appBar: null,
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.navBarBackground, 
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRadius),
            topRight: Radius.circular(kRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRadius),
            topRight: Radius.circular(kRadius),
          ),
          child: SafeArea(
            bottom: true, // 確保適配各種螢幕底部
            child: Container(
              height: 75,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, '首頁'),
                  _buildNavItem(
                    1,
                    Icons.chat_bubble_outline,
                    Icons.chat_bubble,
                    '交流',
                  ),
                  _buildNavItem(
                    2,
                    Icons.video_library_outlined,
                    Icons.video_library,
                    '紀錄',
                  ),
                  _buildNavItem(3, Icons.school_outlined, Icons.school, '老師'),
                  _buildNavItem(
                    4,
                    Icons.settings_outlined,
                    Icons.settings,
                    '設定',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _index == index;
    return GestureDetector(
      onTap: () => setState(() => _index = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent, // 包裹文字與圖示的選取框
          borderRadius: BorderRadius.circular(kRadiusS), // 正方形導角
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: Colors.white, size: 24),
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

// ==========================================
// 2. 學生主頁
// ==========================================
class InterviewHomePage extends StatelessWidget {
  final AppUser user;
  const InterviewHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24.0,
              110.0,
              24.0,
              20.0,
            ), // 頂部預留標頭空間
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Hello, ${user.name}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kLuminewDeepIndigo,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '準備好開始練習了嗎？',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                _buildCard(
                  context,
                  title: '模擬面試',
                  icon: Icons.smart_toy_outlined,
                  subtitle: '與虛擬教授沉浸式練習',
                  color: AppColors.primaryPurpleSoft,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MockInterviewSetupScreen(user: user),
                    ),
                  ),
                ),

                _buildCard(
                  context,
                  title: '檔案分析',
                  icon: Icons.auto_awesome_outlined,
                  subtitle: '分析你的學習歷程或自傳',
                  color: AppColors.primaryPurpleMuted,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PortfolioAnalysisScreen(user: user),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- 統一懸浮標頭 ---
          LuminewHeader(
            title: 'Luminew',
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: kLuminewDeepIndigo,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentNotificationsScreen(user: user),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(kRadiusM),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 預約面試
// ==========================================
class StudentBookingScreen extends StatefulWidget {
  final AppUser user;
  const StudentBookingScreen({super.key, required this.user});
  @override
  State<StudentBookingScreen> createState() => _StudentBookingScreenState();
}

class _StudentBookingScreenState extends State<StudentBookingScreen> {
  final _teacherEmailCtrl = TextEditingController();
  List<InterviewSlot> _slots = [];
  bool _isLoading = false;

  Future<void> _search() async {
    if (_teacherEmailCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      var list = await ApiService.getAvailableSlots(_teacherEmailCtrl.text);
      setState(() => _slots = list);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("錯誤: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _book(String slotId) async {
    try {
      await ApiService.bookSlot(slotId, widget.user.email);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ 預約成功！")));
      _search();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ 失敗: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      appBar: AppBar(
        title: const Text("預約面試"),
        backgroundColor: Colors.white,
        foregroundColor: kLuminewDeepIndigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teacherEmailCtrl,
                    decoration: InputDecoration(
                      labelText: "輸入老師 Email",
                      hintText: "teacher@test.com",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLuminewMainPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text("查詢"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                ? const Center(
                    child: Text(
                      "目前無可用時段",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _slots.length,
                    itemBuilder: (ctx, i) {
                      final s = _slots[i];
                      final dateStr = "${s.startTime.month}/${s.startTime.day}";
                      final timeStr =
                          "${s.startTime.hour.toString().padLeft(2, '0')}:${s.startTime.minute.toString().padLeft(2, '0')}";
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: Colors.green,
                            ),
                          ),
                          title: Text(
                            "$dateStr $timeStr (30分)",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            "名額：1",
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _book(s.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("立即預約"),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 通知中心
// ==========================================
class StudentNotificationsScreen extends StatefulWidget {
  final AppUser user;
  const StudentNotificationsScreen({super.key, required this.user});
  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  Future<void> _respond(String id, String status) async {
    await ApiService.updateInvitation(id, status);
    setState(() {});
  }

  void _joinMeeting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("視訊會議")),
          body: const Center(
            child: Text("學生視訊畫面連線中...", style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      appBar: AppBar(
        title: const Text("通知中心"),
        backgroundColor: Colors.white,
        foregroundColor: kLuminewDeepIndigo,
        elevation: 0,
      ),
      body: FutureBuilder<List<Invitation>>(
        future: ApiService.getInvitations(widget.user.id, false),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) return const Center(child: Text("目前無新通知"));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.length,
            itemBuilder: (ctx, i) {
              final inv = snap.data![i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            color: kLuminewMainPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${inv.teacherName} 邀請您面試",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        inv.message,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (inv.status == 'Pending') ...[
                            TextButton(
                              onPressed: () => _respond(inv.id, 'Rejected'),
                              child: const Text(
                                "殘忍拒絕",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _respond(inv.id, 'Accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kLuminewMainPurple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text("接受邀請"),
                            ),
                          ] else if (inv.status == 'Accepted') ...[
                            Expanded(child: Container()),
                            ElevatedButton.icon(
                              onPressed: _joinMeeting,
                              icon: const Icon(Icons.video_call),
                              label: const Text("進入面試"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                          ] else ...[
                            Text(
                              "已拒絕",
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ],
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

// ==========================================
// 5. 學生班級 (修復括號問題)
// ==========================================
class StudentTeacherScreen extends StatefulWidget {
  final AppUser user;
  const StudentTeacherScreen({super.key, required this.user});
  @override
  State<StudentTeacherScreen> createState() => _StudentTeacherScreenState();
}

class _StudentTeacherScreenState extends State<StudentTeacherScreen> {
  final _codeCtrl = TextEditingController();
  List<Teacher> _teachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _teachers = await ApiService.getStudentTeachers(widget.user.email);
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _join() async {
    if (_codeCtrl.text.isEmpty) return;
    try {
      final res = await ApiService.joinTeacher(_codeCtrl.text, widget.user.email);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("成功加入老師：${res['teacherName']}")));
      _codeCtrl.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 110), // 為 Header 留白
            // V10: 極簡通透功能條
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.purpleSurface,
                  borderRadius: BorderRadius.circular(AppDesign.radiusM),
                  border: Border.all(
                    color: AppColors.purpleBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.vpn_key_outlined,
                      size: 18,
                      color: kLuminewDeepIndigo,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.deepIndigo,
                          fontSize: 18,
                        ),
                        keyboardType: TextInputType.text, // 可能有英數字
                        decoration: const InputDecoration(
                          hintText: "輸入老師邀請碼",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 15, // 放大提示字至 15
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _join,
                      style: TextButton.styleFrom(
                        foregroundColor: kLuminewMainPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "加入老師",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ), // 放大按鈕字體
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _teachers.isEmpty
                  ? const Center(
                      child: Text(
                        "尚未加入任何老師",
                        style: TextStyle(color: Color(0xFF5A5A5A)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _teachers.length,
                      itemBuilder: (ctx, i) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: const Icon(
                            Icons.school,
                            color: kLuminewMainPurple,
                            size: 32,
                          ),
                          title: Text(
                            _teachers[i].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF675B83),
                            ),
                          ),
                          subtitle: Text(
                            _teachers[i].email,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          trailing: const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: kLuminewMainPurple,
                          ),
                          onTap: () {}, // 點擊不進入班級群聊，因為班級功能移除了
                        ),
                      ),
                    ),
            ),
          ],
        ),
        const LuminewHeader(title: '我的老師'),
      ],
    );
  }
}

// ==========================================
// 6. 學習歷程 AI 分析
// ==========================================
class PortfolioAnalysisScreen extends StatefulWidget {
  final AppUser user;
  const PortfolioAnalysisScreen({super.key, required this.user});
  @override
  State<PortfolioAnalysisScreen> createState() =>
      _PortfolioAnalysisScreenState();
}

class _PortfolioAnalysisScreenState extends State<PortfolioAnalysisScreen> {
  // 狀態
  PlatformFile? _selectedFile;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;
  bool _isSendingEmail = false;

  Future<void> _sendPortfolioEmail() async {
    if (_analysisResult == null || _isSendingEmail) return;

    setState(() => _isSendingEmail = true);
    try {
      final summary = _analysisResult!['summary'] ?? '';
      final strengths = (_analysisResult!['strengths'] as List<dynamic>? ?? []).join('\n');
      final weaknesses = (_analysisResult!['weaknesses'] as List<dynamic>? ?? []).join('\n');
      final suggestions = (_analysisResult!['suggestions'] as List<dynamic>? ?? []).join('\n');

      await ApiService.sendPortfolioAnalysisEmail(
        recipientEmail: widget.user.email,
        studentName: widget.user.name,
        summary: summary,
        strengths: strengths,
        weaknesses: weaknesses,
        suggestions: suggestions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已將分析結果寄送至您的信箱'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 寄送失敗: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  // 選擇 PDF 檔案
  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _analysisResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = '選取檔案時發生錯誤: $e');
    }
  }

  // 上傳並分析 PDF
  Future<void> _analyzePortfolio() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      setState(() => _errorMessage = '請先選擇一個 PDF 檔案');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.rootUrl}/emotion/analyze_portfolio'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf',
          _selectedFile!.bytes!,
          filename: _selectedFile!.name,
        ),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('分析逾時，請稍後再試'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() => _analysisResult = data['analysis']);
        } else {
          setState(() => _errorMessage = data['error'] ?? '分析失敗');
        }
      } else {
        var data = jsonDecode(response.body);
        setState(() => _errorMessage = data['error'] ?? '伺服器錯誤 (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _errorMessage = '錯誤: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gooseYellow,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacings.pagePadding, 80, AppSpacings.pagePadding, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 說明標題
                Text('上傳檔案', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacings.gapS),
                Text('讓 AI 分析你的學習歷程或自傳，並給予改進建議。', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacings.gapXL),

                // 上傳區塊 (質感優化)
                GestureDetector(
                  onTap: _isAnalyzing ? null : _pickPdf,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacings.cardPadding * 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppDesign.radiusL),
                      border: Border.all(
                        color: _selectedFile != null ? AppColors.success : AppColors.primaryPurple.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: AppDesign.premiumShadow,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                          size: 54,
                          color: _selectedFile != null ? AppColors.success : AppColors.primaryPurple,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFile != null ? _selectedFile!.name : '點擊選擇 PDF 檔案',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: _selectedFile != null ? AppColors.success : AppColors.primaryPurple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacings.gapL),

                // 分析按鈕 (質感優化)
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (_isAnalyzing || (_analysisResult != null && _selectedFile != null)) ? null : _analyzePortfolio,
                    icon: _isAnalyzing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_analysisResult != null ? Icons.check_circle : Icons.auto_awesome),
                    label: Text(
                      _isAnalyzing 
                          ? '分析中，請稍候...' 
                          : (_analysisResult != null ? '分析完成' : '開始 AI 智慧分析'), 
                      style: AppTextStyles.buttonText
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _analysisResult != null ? AppColors.success : AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _analysisResult != null ? AppColors.success.withOpacity(0.6) : AppColors.textDisabled,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesign.radiusM)),
                      elevation: 0,
                    ),
                  ),
                ),

                // 錯誤訊息
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacings.gapM),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
                      ],
                    ),
                  ),
                ],

                // 分析結果
                if (_analysisResult != null) ...[
                  const SizedBox(height: AppSpacings.gapXL),
                  _buildResultCard(),
                  const SizedBox(height: AppSpacings.gapL),
                  
                  // 寄給我按鈕 (質感優化)
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _isSendingEmail ? null : _sendPortfolioEmail,
                      icon: _isSendingEmail
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple))
                          : const Icon(Icons.email_outlined),
                      label: Text(_isSendingEmail ? '寄送中...' : '將此分析報告寄給我', style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryPurple)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesign.radiusM)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacings.gapM),
                ],
              ],
            ),
          ),
          const LuminewHeader(title: '檔案分析', showBackButton: true),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final strengths = _analysisResult!['strengths'] as List<dynamic>? ?? [];
    final weaknesses = _analysisResult!['weaknesses'] as List<dynamic>? ?? [];
    final suggestions = _analysisResult!['suggestions'] as List<dynamic>? ?? [];
    final summary = _analysisResult!['summary'] ?? _analysisResult!['comment'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.50),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 整體評語區塊
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.primaryPurple, size: 24),
              const SizedBox(width: 10),
              Text('整體評語', style: AppTextStyles.h3.copyWith(color: AppColors.deepIndigo, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87, height: 1.5, fontSize: 15),
          ),

          // 分隔線
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: AppColors.primaryPurple.withOpacity(0.3), thickness: 1),
          ),

          // 亮點優勢
          if (strengths.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.primaryPurple, size: 24),
                const SizedBox(width: 10),
                Text('亮點優勢', style: AppTextStyles.h3.copyWith(color: AppColors.deepIndigo, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ...strengths.map((s) => _buildBulletPoint(s)),
            const SizedBox(height: 12),
          ],

          // 不足之處
          if (weaknesses.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.primaryPurple, size: 24),
                const SizedBox(width: 10),
                Text('不足之處', style: AppTextStyles.h3.copyWith(color: AppColors.deepIndigo, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ...weaknesses.map((w) => _buildBulletPoint(w)),
            const SizedBox(height: 12),
          ],

          // 改進建議區塊
          if (suggestions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.lightbulb, color: AppColors.primaryPurple, size: 24),
                const SizedBox(width: 10),
                Text('改進建議', style: AppTextStyles.h3.copyWith(color: AppColors.deepIndigo, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ...suggestions.map((s) => _buildBulletPoint(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 6, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87, height: 1.5))),
        ],
      ),
    );
  }
}
