// fileName: lib/screens/student_screens.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models.dart';
import '../sql_service.dart';
import 'common_screens.dart';
import 'interview_screens.dart';
import 'chat_screens.dart';

const Color kPrimaryColor = Color(0xFF3F51B5);
const Color kBackgroundColor = Color(0xFFF8F9FB);
const double kRadius = 16.0;

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
      ClassChatRoom(
        chatKey: 'public',
        userEmail: widget.user.email,
        title: '公共交流',
        showAppBar: false,
      ),
      InterviewRecordListScreen(user: widget.user),
      StudentClassScreen(user: widget.user),
      SettingsScreen(onLogout: widget.onLogout, user: widget.user),
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _index == 1
          ? AppBar(
              title: const Text('公共交流區'),
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: Colors.black,
            )
          : null,
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主頁',
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
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: '班級',
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

// ==========================================
// 2. 學生主頁
// ==========================================
class InterviewHomePage extends StatelessWidget {
  final AppUser user;
  const InterviewHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('主頁', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentNotificationsScreen(user: user),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Hello, ${user.name}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
              title: '開始模擬面試 (AI)',
              icon: Icons.smart_toy,
              subtitle: '與 AI 機器人練習',
              color: kPrimaryColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockInterviewSetupScreen(user: user),
                ),
              ),
            ),

            _buildCard(
              context,
              title: '預約 Live 面試',
              icon: Icons.calendar_today_rounded,
              subtitle: '搶約老師時段',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentBookingScreen(user: user),
                ),
              ),
            ),

            _buildCard(
              context,
              title: '學習歷程 AI 分析',
              icon: Icons.auto_awesome,
              subtitle: 'AI 智慧評價您的 PDF',
              color: Colors.green,
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
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (color ?? Colors.black).withOpacity(0.15),
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
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 18,
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
      var list = await SqlService.getAvailableSlots(_teacherEmailCtrl.text);
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
      await SqlService.bookSlot(slotId, widget.user.email);
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("預約面試"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                    backgroundColor: kPrimaryColor,
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
    await SqlService.updateInvitation(id, status);
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("通知中心"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<Invitation>>(
        future: SqlService.getInvitations(widget.user.id, false),
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
                            color: kPrimaryColor,
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
                                backgroundColor: kPrimaryColor,
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
class StudentClassScreen extends StatefulWidget {
  final AppUser user;
  const StudentClassScreen({super.key, required this.user});
  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  final _codeCtrl = TextEditingController();
  List<Class> _classes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _classes = await SqlService.getStudentClasses(widget.user.email);
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _join() async {
    if (_codeCtrl.text.isEmpty) return;
    try {
      await SqlService.joinClass(_codeCtrl.text, widget.user.email);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("成功加入")));
      _codeCtrl.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('我的班級'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "輸入 6 位數邀請碼",
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
                  onPressed: _join,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text("加入"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _classes.isEmpty
                ? const Center(child: Text("尚未加入班級"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classes.length,
                    itemBuilder: (ctx, i) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const Icon(
                          Icons.school,
                          color: kPrimaryColor,
                          size: 32,
                        ),
                        title: Text(
                          _classes[i].name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text("點擊進入聊天室"),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassChatRoom(
                              chatKey: _classes[i].id,
                              userEmail: widget.user.email,
                              title: _classes[i].name,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
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
  State<PortfolioAnalysisScreen> createState() => _PortfolioAnalysisScreenState();
}

class _PortfolioAnalysisScreenState extends State<PortfolioAnalysisScreen> {
  // 狀態
  PlatformFile? _selectedFile;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  // 選擇 PDF 檔案
  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // 需要取得檔案資料
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _analysisResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '選取檔案時發生錯誤: $e';
      });
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
      // 建立 multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/emotion/analyze_portfolio'),
      );

      request.files.add(http.MultipartFile.fromBytes(
        'pdf',
        _selectedFile!.bytes!,
        filename: _selectedFile!.name,
      ));

      // 發送請求
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('分析逾時，請稍後再試'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _analysisResult = data['analysis'];
          });
        } else {
          setState(() {
            _errorMessage = data['error'] ?? '分析失敗';
          });
        }
      } else {
        var data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['error'] ?? '伺服器錯誤 (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '錯誤: $e';
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('學習歷程 AI 分析'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 說明文字
            const Text(
              '上傳您的學習歷程 PDF，AI 將為您分析並給予改進建議。',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // 上傳區塊
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFile != null ? Colors.green : Colors.grey[300]!,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : '點擊選擇 PDF 檔案',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _selectedFile != null ? Colors.green : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 分析按鈕
            ElevatedButton.icon(
              onPressed: _isAnalyzing || _selectedFile == null ? null : _analyzePortfolio,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isAnalyzing ? '分析中，請稍候...' : '開始 AI 分析'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // 錯誤訊息
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 分析結果
            if (_analysisResult != null) ...[
              const SizedBox(height: 30),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final score = _analysisResult!['overall_score'] ?? 0;
    final strengths = _analysisResult!['strengths'] as List<dynamic>? ?? [];
    final weaknesses = _analysisResult!['weaknesses'] as List<dynamic>? ?? [];
    final comment = _analysisResult!['comment'] ?? '';
    final suggestions = _analysisResult!['suggestions'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題和分數
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              const Text(
                'AI 分析結果',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getScoreColor(score),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score 分',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 優點
          if (strengths.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.thumb_up, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text('優點', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            ...strengths.map((s) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Text('• $s', style: const TextStyle(fontSize: 14)),
            )),
            const SizedBox(height: 16),
          ],

          // 需改進
          if (weaknesses.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Text('需改進', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            ...weaknesses.map((w) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Text('• $w', style: const TextStyle(fontSize: 14)),
            )),
            const SizedBox(height: 16),
          ],

          // 整體評語
          if (comment.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.chat, color: Colors.blue, size: 18),
                SizedBox(width: 6),
                Text('整體評語', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(comment, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 16),
          ],

          // 改進建議
          if (suggestions.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                SizedBox(width: 6),
                Text('改進建議', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            ...suggestions.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}