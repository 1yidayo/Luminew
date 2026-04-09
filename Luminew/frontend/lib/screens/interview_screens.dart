// fileName: lib/screens/interview_screens.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models.dart';
import '../mock_data.dart';
import '../api_service.dart';
import '../did_interview_service.dart';
import '../config.dart';
import '../widgets/did_video_widget.dart';

// 全域變數：用來儲存可用的相機列表
List<CameraDescription> cameras = [];

// ★ Luminew 質感風全域組件 ★
Widget _buildPremiumCard({
  required String title,
  required IconData icon,
  required Widget child,
  bool isError = false,
  GlobalKey? key,
}) {
  final accentColor = isError ? Colors.redAccent : kLuminewMainPurple;
  return Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: kLuminewSurface,
      borderRadius: BorderRadius.circular(kLuminewRadius),
      border: isError ? Border.all(color: Colors.redAccent, width: 2) : null,
      boxShadow: [
        BoxShadow(
          color: accentColor.withOpacity(0.05),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isError ? Colors.redAccent : kLuminewDeepIndigo,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

const kLuminewMainPurple = Color(0xFFAD9DC7); // 核心紫色
const kLuminewPalePurple = Color(0xFFF5F3FF); // 背景淡紫色
const kLuminewDeepIndigo = Color(0xFF675B83); // 文字部分採用較深的紫色，提升閱讀性
const kLuminewSurface = Colors.white; // 卡片與表面
const kLuminewSuccess = Color(0xFFA5F3E0); // 莫蘭迪綠
const kLuminewWarning = Color(0xFFFDE68A); // 莫蘭迪黃
const kLuminewConfident = Color(0xFFFDE68A); // 自信 (黃)
const kLuminewNervous = Color(0xFF93C5FD); // 緊張 (藍)
const kLuminewPassion = Color(0xFFFDA4AF); // 熱忱 (粉)
const kLuminewRelaxed = Color(0xFFA5F3E0); // 沈穩 (綠)
const kLuminewRadius = 20.0; // 統一導角

// ★ 質感風下拉選單
Widget _buildDropdown(
  String label,
  List<String> items,
  Function(String?) onChange,
  String currentValue,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: kLuminewDeepIndigo,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLuminewMainPurple.withOpacity(0.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: items.contains(currentValue) ? currentValue : items.first,
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(color: kLuminewDeepIndigo),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChange,
          ),
        ),
      ),
    ],
  );
}

// ==========================================
// 1. 面試紀錄列表 (讀取 SQL 資料)
// ==========================================
class InterviewRecordListScreen extends StatefulWidget {
  final AppUser user;
  const InterviewRecordListScreen({super.key, required this.user});

  @override
  State<InterviewRecordListScreen> createState() =>
      _InterviewRecordListScreenState();
}

class _InterviewRecordListScreenState extends State<InterviewRecordListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewPalePurple, // 背景淡紫
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '面試紀錄回顧',
          style: TextStyle(
            color: kLuminewDeepIndigo,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kLuminewDeepIndigo),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<List<InterviewRecord>>(
        future: ApiService.getRecords(widget.user.id, 'All'),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kLuminewMainPurple),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "載入失敗: ${snapshot.error}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text("重試"),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(
              child: Text('尚無紀錄', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: records.length,
            itemBuilder: (ctx, i) {
              final r = records[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kLuminewSurface,
                  borderRadius: BorderRadius.circular(kLuminewRadius),
                  boxShadow: [
                    BoxShadow(
                      color: kLuminewMainPurple.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: kLuminewPalePurple,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kLuminewMainPurple.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "${r.overallScore}",
                        style: const TextStyle(
                          color: kLuminewMainPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    r.interviewName.isNotEmpty
                        ? r.interviewName
                        : '${r.type} 面試',
                    style: const TextStyle(
                      color: kLuminewDeepIndigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${r.date.year}/${r.date.month}/${r.date.day} | ${r.interviewer} 教授',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: kLuminewMainPurple,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InterviewResultScreen(
                        record: r,
                        user: widget.user,
                        aiComment: r.aiComment,
                        aiSuggestion: r.aiSuggestion,
                      ),
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

// ==========================================
// 2. 面試設定頁 (完整下拉選單 + 檔案上傳)
// ==========================================
class MockInterviewSetupScreen extends StatefulWidget {
  final AppUser user;
  const MockInterviewSetupScreen({super.key, required this.user});

  @override
  State<MockInterviewSetupScreen> createState() =>
      _MockInterviewSetupScreenState();
}

class _MockInterviewSetupScreenState extends State<MockInterviewSetupScreen> {
  // 儲存使用者的選擇
  String _type = '通用型';
  String _interviewer = '保羅';
  String _lang = '中文';
  bool _saveVideo = true;

  // ★ 新增：面試名稱（必填）
  final TextEditingController _nameController = TextEditingController();
  String? _nameError;
  bool _pdfError = false; // ★ 檔案未填錯誤狀態

  final ScrollController _setupScrollController = ScrollController();
  final GlobalKey _nameCardKey = GlobalKey();
  final GlobalKey _pdfCardKey = GlobalKey();

  // 檔案上傳相關
  File? _selectedFile;
  String? _selectedFileName;
  List<String> _generatedQuestions = [];
  bool _isAnalyzing = false;

  // ★ 校準相關
  Map<String, dynamic>? _baseline;
  bool _isCalibrating = false;
  bool _calibrationDone = false;

  @override
  void initState() {
    super.initState();
    // 預設展開校準數據？
  }

  void _scrollTo(GlobalKey key) {
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _setupScrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ★ 個人化校準：彈出預覽畫面 → 錄 5 秒 → 上傳 → 取得 baseline
  Future<void> _calibrate() async {
    setState(() {
      _isCalibrating = true;
      _calibrationDone = false;
      _baseline = null;
    });

    try {
      // 0. 先請求麥克風權限
      final recorder = AudioRecorder();
      await recorder.hasPermission();
      recorder.dispose();

      // 1. 開啟前鏡頭
      if (cameras.isEmpty) cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camCtrl = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camCtrl.initialize();

      // 2. 彈出全螢幕對話框顯示預覽
      if (!mounted) {
        camCtrl.dispose();
        return;
      }

      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _CalibrationDialog(camCtrl: camCtrl),
      );

      // 3. 清理
      camCtrl.dispose();

      // 4. 處理結果
      if (result != null) {
        setState(() {
          _baseline = result;
          _calibrationDone = true;
        });
        print('✅ 校準完成: $_baseline');
      }
    } catch (e) {
      print('❌ 校準失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('校準失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCalibrating = false);
    }
  }

  // ★ 選擇 PDF 檔案
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileName = result.files.single.name;
        _pdfError = false; // ★ 檔案選好了，清除紅字提示
        _generatedQuestions = []; // 清除舊問題
      });

      // 自動開始分析
      await _analyzeFileAndGenerateQuestions();
    }
  }

  // ★ 上傳檔案並生成問題
  Future<void> _analyzeFileAndGenerateQuestions() async {
    if (_selectedFile == null) return;

    setState(() => _isAnalyzing = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/emotion/generate_questions'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('pdf', _selectedFile!.path),
      );
      request.fields['interview_type'] = _type;

      print("📤 上傳 PDF 並生成問題...");
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw Exception("連線逾時");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _generatedQuestions = (data['questions'] as List)
                .map((q) => q.toString())
                .toList();
          });
          print("✅ 成功生成 ${_generatedQuestions.length} 個問題");
        } else {
          print("⚠️ 問題生成失敗: ${data['message']}");
        }
      } else {
        print("❌ API 錯誤: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 錯誤: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('問題生成失敗: $e')));
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewPalePurple, // 改用淡紫色背景
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '面試場景設定',
          style: TextStyle(
            color: kLuminewDeepIndigo,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: kLuminewDeepIndigo),
      ),
      body: SingleChildScrollView(
        controller: _setupScrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ★ 名稱與類型設定
            _buildPremiumCard(
              key: _nameCardKey,
              title: "面試基本資訊",
              icon: Icons.edit_note,
              isError: _nameError != null,
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "面試名稱",
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                      errorText: _nameError,
                      errorStyle: const TextStyle(color: Colors.redAccent),
                      prefixIcon: Icon(
                        Icons.title,
                        color: _nameError != null ? Colors.redAccent : kLuminewMainPurple,
                      ),
                    ),
                    onChanged: (v) {
                      if (_nameError != null && v.isNotEmpty) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown(
                    "面試類型",
                    ['通用型', '資管專業', '學習歷程'],
                    (val) => setState(() {
                      _type = val!;
                      // 僅在類型切換時重設錯誤狀態，不自動變紅
                      _pdfError = false;
                    }),
                    _type,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    "面試教授",
                    ['引導型教授', '親和型教授', '嚴謹型教授'],
                    (val) => setState(() => _interviewer = val!),
                    _interviewer,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown("語言設定", ['中文', '英文 (暫不開放)'], (val) {
                    if (val == '英文 (暫不開放)') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('英文模式正在開發中，暫不開放')),
                      );
                      return;
                    }
                    setState(() => _lang = val!);
                  }, _lang == '英文' ? '英文 (暫不開放)' : _lang),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ★ 錄影設定卡片
            _buildPremiumCard(
              title: "錄製設定",
              icon: Icons.videocam,
              child: SwitchListTile(
                title: const Text(
                  '儲存面試錄影',
                  style: TextStyle(color: kLuminewDeepIndigo),
                ),
                subtitle: const Text(
                  '結束後可回顧自己的表情與肢體動作',
                  style: TextStyle(fontSize: 12),
                ),
                activeColor: kLuminewMainPurple,
                value: _saveVideo,
                onChanged: (v) => setState(() => _saveVideo = v),
              ),
            ),
            const SizedBox(height: 20),

            // ★ 檔案上傳卡片
            _buildPremiumCard(
              key: _pdfCardKey,
              title: _type == '學習歷程' ? "個人化資料 (必填)" : "個人化資料 (選填)",
              icon: Icons.upload_file,
              isError: _pdfError,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _type == '學習歷程' ? "請務必上傳檔案，AI 方能針對內容提問" : "上傳學習歷程或自傳，AI 會針對內容提問",
                    style: TextStyle(
                      color: _pdfError ? Colors.redAccent : Colors.grey, 
                      fontSize: 13
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: _isAnalyzing ? null : _pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kLuminewPalePurple.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kLuminewMainPurple.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_isAnalyzing)
                            const CircularProgressIndicator(
                              color: kLuminewMainPurple,
                            )
                          else ...[
                            Icon(
                              _selectedFile != null
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: kLuminewMainPurple,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFileName ?? "點擊選擇 PDF 檔案",
                              style: const TextStyle(
                                color: kLuminewMainPurple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_generatedQuestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已成功分析並生成 ${_generatedQuestions.length} 個個人化問題',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ★ 個人化校準卡片
            _buildPremiumCard(
              title: "面試前校準 (選填)",
              icon: Icons.camera_front,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "錄製 5 秒影片以進行基準面部情緒分析",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isCalibrating ? null : _calibrate,
                      icon: Icon(_calibrationDone ? Icons.check : Icons.face),
                      label: Text(
                        _isCalibrating
                            ? "系統校準中..."
                            : (_calibrationDone ? "校準已完成" : "開始 5 秒快速校準"),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: BorderSide(
                          color: _calibrationDone
                              ? Colors.green
                              : kLuminewMainPurple,
                        ),
                        foregroundColor: _calibrationDone
                            ? Colors.green
                            : kLuminewMainPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ★ 開始面試按鈕
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: () {
                  // 1. 校驗名稱
                  if (_nameController.text.trim().isEmpty) {
                    setState(() => _nameError = "請輸入面試名稱");
                    _scrollTo(_nameCardKey);
                    return;
                  }
                  // 2. 校驗檔案
                  if (_type == '學習歷程' && _selectedFile == null) {
                    setState(() => _pdfError = true);
                    _scrollTo(_pdfCardKey);
                    return;
                  }
                  // 進入正式面試
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MockInterviewScreen(
                        user: widget.user,
                        type: _type,
                        interviewer: _interviewer,
                        language: _lang,
                        saveVideo: _saveVideo,
                        interviewName: _nameController.text.trim(),
                        baseline: _baseline,
                        questions: _generatedQuestions,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLuminewMainPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: kLuminewMainPurple.withOpacity(0.4),
                ),
                child: const Text(
                  '開始模擬面試',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ★ 修改後的免責聲明
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '將錄製使用者影像以供後續回顧表情使用，現階段的測試者若同意錄製即代表同意授權影像做模型微調與研究，研究過後將刪除資料，不會用於其他用途與公開發佈。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} // ★ 新增：校準專用對話框（含相機預覽）

class _CalibrationDialog extends StatefulWidget {
  final CameraController camCtrl;
  const _CalibrationDialog({required this.camCtrl});

  @override
  State<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<_CalibrationDialog> {
  int _countdown = 5;
  String _statusMessage = "準備開始錄影...";
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _startCalibrationProcess();
  }

  Future<void> _startCalibrationProcess() async {
    try {
      // 給預覽一點時間顯示
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _statusMessage = "請保持自然放鬆，看著鏡頭";
      });
      await widget.camCtrl.startVideoRecording();

      // 5 秒倒數
      for (int i = 5; i > 0; i--) {
        if (!mounted) return;
        setState(() {
          _countdown = i;
        });
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;
      setState(() {
        _countdown = 0;
        _statusMessage = "處理中，請稍候...";
        _isUploading = true;
      });

      final file = await widget.camCtrl.stopVideoRecording();

      // 上傳
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/emotion/calibrate'),
      );
      request.files.add(await http.MultipartFile.fromPath('video', file.path));

      var streamedResp = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('校準逾時'),
      );
      var resp = await http.Response.fromStream(streamedResp);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          if (mounted)
            Navigator.pop(context, Map<String, dynamic>.from(data['baseline']));
        } else {
          throw Exception(data['error'] ?? '校準失敗');
        }
      } else {
        throw Exception('Server error: ${resp.statusCode}');
      }
    } catch (e) {
      print('❌ 校準失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('校準失敗: $e')));
        Navigator.pop(context, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 相機預覽
              CameraPreview(widget.camCtrl),

              // 黑色半透明遮罩
              Container(color: Colors.black45),

              // UI 層
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isUploading) ...[
                    Text(
                      '$_countdown',
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 10),
                        ],
                      ),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // 關閉按鈕
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    // 若正在錄影，讓流程自行中斷並關閉
                    Navigator.pop(context, null);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. 面試錄影頁 (相機 + AI連線 + SQL儲存)
// ==========================================
class MockInterviewScreen extends StatefulWidget {
  final AppUser user;
  final String type;
  final String interviewer;
  final String language;
  final bool saveVideo;
  final List<String>? questions;
  final String interviewName;
  final Map<String, dynamic>? baseline; // ★ 新增：校準基線

  const MockInterviewScreen({
    super.key,
    required this.user,
    required this.type,
    required this.interviewer,
    required this.language,
    required this.saveVideo,
    required this.interviewName,
    this.questions,
    this.baseline, // ★ 新增
  });

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isUploading = false;
  int _sec = 0;
  Timer? _timer;
  String _statusMessage = "";

  // ★ WebSocket 即時面試
  late final DidInterviewService _didService;
  bool _isInterviewing = false;
  bool _isWsConnecting = false;
  bool _isWaitingProfessor = false;
  bool _canStudentSpeak = false; // ★ 新增：控制學生是否可以說話（延遲顯示開麥）
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  String _connectionStatus = "Disconnected";

  // ★ TTS 音訊播放

  @override
  void initState() {
    super.initState();
    final baseUrl = ApiService.baseUrl.replaceAll('/api/db', '');
    _didService = DidInterviewService(backendUrl: baseUrl);
    _didService.init().then((_) {
      if (mounted) setState(() {});
    });
    _initCamera();
    _setupWsCallbacks();
  }

  // ★ 設定 WebSocket 回呼
  void _setupWsCallbacks() {
    _didService.onTranscript = (role, text) {
      if (mounted) {
        setState(() {
          _chatMessages.add({'role': role, 'text': text});
          // 如果教授開始說話，前端進入等待狀態
          if (role == 'professor') {
            _isWaitingProfessor = true;
            _canStudentSpeak = false;
          }
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_chatScrollController.hasClients) {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    };
    _didService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('WebRTC Error: $error')));
        setState(() {
          _isInterviewing = false;
          _isWsConnecting = false;
        });
      }
    };
    _didService.onTtsDone = () {
      // ★ 教授說完了，延遲 1 秒後開啟麥克風顯示，讓學生心理有準備
      if (mounted) {
        setState(() {
          _isWaitingProfessor = false;
          // _startAudioStream(); // 不要立刻收音，等 1 秒
        });

        // ★ 恢復穩定邏輯：教授說完後，多等 1.2 秒才亮起按鈕，確保後端麥克風已完全就緒
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _canStudentSpeak = true);
            if (_isInterviewing) {
              _startAudioStream();
            }
          }
        });
      }
    };
    _didService.onVideoTrack = () {
      if (mounted) {
        print('📺 [UI] 偵測到視訊執軌道掛載，重新渲染畫面');
        setState(() {});
      }
    };
    _didService.onConnectionState = (state) {
      if (mounted) {
        setState(() {
          _connectionStatus = state;
        });
      }
    };
  }

  // ★ 開始即時面試
  Future<void> _startLiveInterview() async {
    setState(() {
      _isWsConnecting = true;
      _isWaitingProfessor = true;
      _canStudentSpeak = false;
    });

    // 如果開啟了錄影分析，也要同步啟動錄影
    if (widget.saveVideo && !_isRecording) {
      // 這裡不直接 await _startRecording 是為了避免阻塞 WS 連線
      _startRecording();
    }

    print('🎙️ [Interview] 開始建立與 D-ID 的 WebRTC 連線 (教授: ${widget.interviewer})...');
    await _didService.startInterview(widget.interviewer);
    if (mounted)
      setState(() {
        _isInterviewing = true;
        _isWsConnecting = false;
      });
  }

  void _stopLiveInterview() {
    print("⏹ [Interview] 手動停止面試指令觸發");

    // 如果正在錄製中，優先走錄製結束流程（該流程會自動清理面試狀態）
    if (_isRecording) {
      _stopAndAnalyze();
      return;
    }

    // 單純停止 WebRTC 與 WebSocket
    _didService.stopInterview();
    if (mounted) {
      setState(() {
        _isInterviewing = false;
        _isWsConnecting = false;
        _isWaitingProfessor = false;
      });
    }
  }

  void _signalSpeechEnd() {
    _didService.stopRecording();
    setState(() {
      _isWaitingProfessor = true;
      _canStudentSpeak = false;
    });
  }

  void _startAudioStream() {
    _didService.startRecording();
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }

      if (cameras.isNotEmpty) {
        // 優先使用前鏡頭
        final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        // ★ 關閉 enableAudio 避免跟 AudioRecorder 搶麥克風導致閃退
        // ★ Web 版使用 medium 可避開瀏覽器 low resolution 常常導致的長寬比變形黑螢幕問題
        _controller = CameraController(
          frontCam,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) setState(() {});
      } else {
        setState(() => _statusMessage = "找不到相機鏡頭，請檢查設備。");
      }
    } catch (e) {
      print("相機初始化失敗: $e");
      setState(() => _statusMessage = "相機開啟失敗: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    _didService.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // ★ 修正：先請求麥克風權限，避免 camera 插件內部觸發 SecurityException
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('需要麥克風權限才能錄影')));
        }
        return;
      }

      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _sec = 0;
      });

      // ★ 新增：如果還沒開啟語音對答，就自動幫忙開啟
      if (!_isInterviewing && !_isWsConnecting) {
        _startLiveInterview();
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _sec++);
      });
    } catch (e) {
      print("開始錄影失敗: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("錄影啟動失敗: $e")));
    }
  }

  Future<void> _stopAndAnalyze() async {
    if (!_isRecording) return;
    print("🛑 [Record] 停止錄影並進入分析流程...");

    // 1. 同步停止面試狀態
    _didService.stopInterview();

    // 停止計時與錄影
    _timer?.cancel();
    XFile file;
    try {
      file = await _controller!.stopVideoRecording();
    } catch (e) {
      print("停止錄影失敗: $e");
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isUploading = true;
        _isInterviewing = false;
        _isWsConnecting = false;
        _isWaitingProfessor = false;
      });
    }

    try {
      final apiUrl = '${ApiService.rootUrl}/emotion/analyze';
      print("★★★ 準備上傳影片到: $apiUrl ★★★");
      print("★★★ 影片路徑: ${file.path} ★★★");

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            await file.readAsBytes(),
            filename: kIsWeb ? file.name : 'video.mp4',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('video', file.path),
        );
      }
      // ★ 傳送設定給後端
      request.fields['save_video'] = widget.saveVideo ? 'true' : 'false';
      request.fields['interviewer'] = widget.interviewer;

      // ★ 傳送逐字稿給後端
      if (_chatMessages.isNotEmpty) {
        request.fields['transcript'] = jsonEncode(_chatMessages);
        print('💬 已附上逐字稿');
      }

      // ★ 傳送校準基線（如果有）
      if (widget.baseline != null) {
        request.fields['baseline'] = jsonEncode(widget.baseline);
        print('🎯 帶上個人基線: ${widget.baseline}');
      }

      print("★★★ 正在上傳影片... ★★★");
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 300),
        onTimeout: () {
          print("★★★ 連線逾時！★★★");
          throw Exception("連線逾時，請檢查 Python Server 是否開啟");
        },
      );

      print("★★★ 收到回應，狀態碼: ${streamedResponse.statusCode} ★★★");
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        // ★ 如果因為沒偵測到臉而發生錯誤，不要崩潰，直接塞入假資料讓它順利跳轉。
        if (data.containsKey('error')) {
          data['emotions'] = {
            'confidence': 0,
            'nervous': 0,
            'passion': 0,
            'relaxed': 0,
          };
          data['ai_analysis'] = {
            'overall_score': 0,
            'comment':
                '【系統警告】無法從影片中偵測到清晰的人臉，情緒分析已強制略過。\n\n' + (data['error'] ?? ''),
            'suggestion': '請確保攝影機鏡頭開啟，環境光源充足，並讓臉部居中顯示於畫面之中。',
          };
          data['timeline'] = [];
        }

        final emotions = data['emotions'];
        final ai = data['ai_analysis'];
        final timelineList = data['timeline'] ?? [];

        String finalVideoUrl = data['video_url'] ?? '';
        if (finalVideoUrl.startsWith('/')) {
          finalVideoUrl = '${AppConfig.httpUrl}$finalVideoUrl';
        }

        // 建立紀錄物件
        final r = InterviewRecord(
          id: 'IR${DateTime.now().millisecondsSinceEpoch}',
          studentId: widget.user.email,
          date: DateTime.now(),
          durationSec: _sec,
          scores: {
            'overall': ai['overall_score'] ?? 0,
            'confidence': emotions['confidence'] ?? 0,
            'passion': emotions['passion'] ?? 0,
            'nervous': emotions['nervous'] ?? 0,
            'relaxed': emotions['relaxed'] ?? 0,
          },
          type: widget.type,
          interviewer: widget.interviewer,
          language: widget.language,
          privacy: 'Private',
          aiComment: ai['comment'] ?? '',
          aiSuggestion: ai['suggestion'] ?? '',
          timelineData: jsonEncode(timelineList),
          videoUrl: finalVideoUrl,
          questions: widget.questions ?? [],
          interviewName: widget.interviewName,
        );

        mockService.addRecord(r);

        try {
          final serverId = await ApiService.saveRecord(r);
          if (serverId != null) {
            r.id = serverId;
            print("✅ 資料庫儲存成功，正版 ID: $serverId");
          }
        } catch (dbError) {
          print("❌ 資料庫儲存失敗: $dbError");
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => InterviewResultScreen(
                record: r,
                user: widget.user,
                aiComment: ai['comment'],
                aiSuggestion: ai['suggestion'],
                videoUrl: file.path,
              ),
            ),
          );
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print("錯誤: $e");
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("分析失敗"),
            content: Text(
              "錯誤訊息：$e\n\n請確認：\n1. Python Server 有開嗎？\n2. IP 位址改對了嗎？",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("確定"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_statusMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, color: Colors.orange, size: 64),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _statusMessage = "");
                    _initCamera();
                  },
                  child: const Text('重啟相機權限'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: kLuminewPalePurple,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 1. 頂部狀態列
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kLuminewMainPurple.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kLuminewDeepIndigo.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${widget.type} / ${widget.interviewer} / ${widget.language} "
                              "(${(_sec ~/ 60).toString().padLeft(2, '0')}:${(_sec % 60).toString().padLeft(2, '0')})",
                              style: const TextStyle(
                                color: kLuminewDeepIndigo,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _connectionStatus == 'connected'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "連線狀態: $_connectionStatus",
                                  style: TextStyle(
                                    color: kLuminewDeepIndigo.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. 核心影像區域：D-ID 教授
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 90),
                  child: Container(
                    width: double.infinity,
                    height: 510, // 增加高度至 520 (滿足高一些且下移的需求)
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: kLuminewMainPurple.withOpacity(0.95),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kLuminewMainPurple.withOpacity(0.4),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // A. 教授影像 (使用遠端渲染器)
                          DidVideoWidget(renderer: _didService.remoteRenderer),

                          // B. 載入中遮罩
                          if (_isWaitingProfessor)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: kLuminewMainPurple,
                                    ),
                                    SizedBox(height: 12),
                                    const Text(
                                      "教授說話中...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // C. 懸浮字幕 (Floating Overlay - 灰底半透明)
                          if (_chatMessages.isNotEmpty)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                height: 110, // 限制高度
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: ListView.builder(
                                  controller: _chatScrollController,
                                  padding: EdgeInsets.zero,
                                  itemCount: _chatMessages.length,
                                  itemBuilder: (context, index) {
                                    final msg = _chatMessages[index];
                                    final isStudent = msg['role'] == 'student';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isStudent ? "我: " : "教授: ",
                                            style: TextStyle(
                                              color: isStudent
                                                  ? Colors.lightBlueAccent
                                                  : Colors.amberAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              msg['text'] ?? "",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 3. 底部區域 (僅限問題，逐字稿改為懸浮)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // 個人化問題區
                        if (widget.questions != null &&
                            widget.questions!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kLuminewDeepIndigo.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.tips_and_updates_outlined,
                                      color: kLuminewMainPurple,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '個人化面試問題',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...widget.questions!.asMap().entries.map((
                                  entry,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${entry.key + 1}. ',
                                          style: const TextStyle(
                                            color: kLuminewMainPurple,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.85,
                                              ),
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // 3. 底部控制按鈕
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: kLuminewMainPurple),
                        SizedBox(height: 12),
                        Text(
                          "AI 正在進行深度情緒分析...",
                          style: TextStyle(
                            color: kLuminewDeepIndigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40, top: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap:
                              _isWsConnecting ||
                                  _isWaitingProfessor ||
                                  (!_isInterviewing ? false : !_canStudentSpeak)
                              ? null
                              : (_isInterviewing
                                    ? _signalSpeechEnd
                                    : _startLiveInterview),
                          onLongPress: (_isInterviewing || _isRecording)
                              ? _stopLiveInterview
                              : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _isWaitingProfessor ||
                                      (_isInterviewing && !_canStudentSpeak)
                                  ? Colors.grey.withOpacity(0.1)
                                  : (_isInterviewing
                                        ? kLuminewDeepIndigo
                                        : Colors.white),
                              border: Border.all(
                                color: kLuminewDeepIndigo,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kLuminewDeepIndigo.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isWsConnecting
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: kLuminewDeepIndigo,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Icon(
                                    _isInterviewing
                                        ? (_canStudentSpeak
                                              ? Icons.mic
                                              : Icons.mic_off)
                                        : Icons.play_arrow_rounded,
                                    color: _isInterviewing
                                        ? Colors.white
                                        : kLuminewDeepIndigo,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isWaitingProfessor
                              ? "教授說話中"
                              : (_isInterviewing
                                    ? (_canStudentSpeak ? "點擊結束個人發言" : "延遲收音中")
                                    : "開始面試對答"),
                          style: const TextStyle(
                            color: kLuminewDeepIndigo,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isInterviewing || _isRecording)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "(長按結束整場面試並分析)",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 4. 右上角面試者 PIP (移除外框樣式)
          Positioned(
            top: 50,
            right: 20,
            width: 100,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // 學生自拍預覽：移除手動翻轉，嘗試預設視角
                  CameraPreview(_controller!),
                  // 加上一個微弱的陰影邊界以便區分背景
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. 超級整合結果頁 (AI分析 + 留言板 + 詳細設定)
// ==========================================
class InterviewResultScreen extends StatefulWidget {
  final InterviewRecord record;
  final AppUser user;
  final String? aiComment;
  final String? aiSuggestion;
  final String? videoUrl; // ★ 新增

  const InterviewResultScreen({
    super.key,
    required this.record,
    required this.user,
    this.aiComment,
    this.aiSuggestion,
    this.videoUrl, // ★ 新增
  });

  @override
  State<InterviewResultScreen> createState() => _InterviewResultScreenState();
}

class _InterviewResultScreenState extends State<InterviewResultScreen> {
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  Duration _videoPosition = Duration.zero;

  bool _isIndexMode = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  bool _videoLoadFailed = false;

  Future<void> _initVideo() async {
    String? url = widget.videoUrl ?? widget.record.videoUrl;
    if (url != null && url.isNotEmpty && url != 'null') {
      print("🎬 嘗試載入影片: $url");

      if (url.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _videoController = VideoPlayerController.file(File(url));
      }
      try {
        await _videoController!.initialize().timeout(
          const Duration(seconds: 15),
        );
        _videoController!.addListener(() {
          if (mounted && _videoController != null) {
            setState(() => _videoPosition = _videoController!.value.position);
          }
        });
        if (mounted) setState(() => _isVideoInitialized = true);
      } catch (e) {
        if (mounted) setState(() => _videoLoadFailed = true);
      }
    }
  }

  List<Color> _getScoreGradient(int score) {
    if (score >= 90) return [Colors.green.shade400, Colors.teal];
    if (score >= 61) return [Colors.orange.shade400, Colors.deepOrange];
    return [Colors.red.shade400, Colors.redAccent];
  }

  void _loadComments() async {
    try {
      var c = await ApiService.getComments(widget.record.id);
      if (mounted) setState(() => _comments = c);
    } catch (_) {}
  }

  void _send() async {
    if (_commentCtrl.text.isEmpty) return;
    try {
      await ApiService.sendComment(
        widget.record.id,
        widget.user.email,
        _commentCtrl.text,
      );
      _commentCtrl.clear();
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("留言失敗: $e")));
    }
  }

  void _updatePrivacy(String? v) async {
    if (v == null) return;
    try {
      await ApiService.updatePrivacy(widget.record.id, v);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("已改為 $v")));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: kLuminewPalePurple,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: kLuminewDeepIndigo),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            '面試分析報告',
            style: TextStyle(
              color: kLuminewDeepIndigo,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: kLuminewDeepIndigo,
            indicatorWeight: 3,
            labelColor: kLuminewDeepIndigo,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                child: Text(
                  'AI 分析',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  '面試問題',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  '討論留言',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  '詳細內容',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ------------------------------------
            // Tab 1: AI 分析報告 (顯示圖表與評語)
            // ------------------------------------
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 原本的總分卡片
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      // ★ 改成動態顏色
                      gradient: LinearGradient(
                        colors: _getScoreGradient(widget.record.overallScore),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getScoreGradient(
                            widget.record.overallScore,
                          ).last.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'AI 綜合評分',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          '${widget.record.overallScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // ★★★ 順便把評語文字也改成對應的 ★★★
                        Text(
                          widget.record.overallScore >= 90
                              ? '表現完美！'
                              : widget.record.overallScore >= 61
                              ? '表現不錯！'
                              : '加油，再接再厲',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.aiComment != null) ...[
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.smart_toy, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text(
                                  "AI 教練短評",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.aiComment!,
                              style: const TextStyle(height: 1.5),
                            ),
                            const Divider(height: 24),
                            const Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  "改進建議",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.aiSuggestion!,
                              style: const TextStyle(
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "微表情數據分析",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const SizedBox(height: 20),

                  // 1. 切換按鈕 (情緒版 vs 索引版)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton("情緒 % 數版", !_isIndexMode, () {
                          setState(() => _isIndexMode = false);
                        }),
                        _buildTabButton("索引型 (次數)", _isIndexMode, () {
                          setState(() => _isIndexMode = true);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. 根據模式顯示對應的圖表
                  if (!_isIndexMode) ...[
                    // === 模式 A: %數型 ===
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "情緒平均佔比",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPercentageBars(), // 呼叫長條圖

                    const SizedBox(height: 30),

                    // ==========================================
                    // ★ 面試影片區塊 ★
                    // ==========================================
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "面試影片回放",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isVideoInitialized && _videoController != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 10),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 9 / 16,
                              // ★ 使用者要求：回放也要跟 PIP/後台一樣維持鏡像
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(3.14159), // 還原翻轉
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                            VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.red,
                              ),
                            ),
                            // 播放控制列
                            Container(
                              color: Colors.black,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _videoController!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _videoController!.value.isPlaying
                                            ? _videoController!.pause()
                                            : _videoController!.play();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (widget.record.videoUrl != null &&
                        widget.record.videoUrl != 'null')
                      // 有網址但載入失敗或載入中
                      _videoLoadFailed
                          ? Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.videocam_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '影片載入失敗',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(30),
                              child: const CircularProgressIndicator(),
                            )
                    else
                      // 沒有儲存影片
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.videocam_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '未儲存影片',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '可在面試設定中開啟「儲存錄影」功能',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "情緒波動曲線",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTimelineChart(), // 呼叫曲線圖
                    // ★★★ 新增：影片同步進度條 ★★★
                    if (_isVideoInitialized && _videoController != null)
                      _buildVideoSyncProgress(),
                  ] else ...[
                    // === 模式 B: 索引型 ===
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "主導情緒統計 (Winner Takes All)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildIndexCountView(), // 呼叫次數統計
                  ],

                  const SizedBox(height: 20),

                  const SizedBox(height: 30),

                  // 回首頁按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('回到首頁'),
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------
            // ★ 新增 Tab 2: 面試問題
            // ------------------------------------
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題區
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade600, Colors.teal.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.quiz, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '本次面試問題',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '共 ${widget.record.questions.length} 題個人化問題',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 問題列表
                  if (widget.record.questions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '此次面試未記錄問題',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '上傳學習歷程 PDF 可生成個人化問題',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...widget.record.questions.asMap().entries.map((entry) {
                      int index = entry.key;
                      String question = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                question,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // 提示文字
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '這些問題是根據你的學習歷程 PDF 自動生成的，可以幫助你準備真正的面試！',
                            style: TextStyle(fontSize: 13, color: Colors.brown),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------
            // Tab 3: 評語討論 (留言板功能)
            // ------------------------------------
            Column(
              children: [
                Expanded(
                  child: _comments.isEmpty
                      ? const Center(child: Text("尚無留言，快來搶頭香！"))
                      : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (ctx, i) {
                            bool isMe =
                                _comments[i].senderName == widget.user.name;
                            return ListTile(
                              title: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Text(
                                  _comments[i].senderName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              subtitle: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.green[100]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(_comments[i].content),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(
                            hintText: '輸入評語...',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ------------------------------------
            // Tab 3: 詳細設定 (隱私設定與詳細資訊)
            // ------------------------------------
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('面試官'),
                    trailing: Text(widget.record.interviewer),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('語言'),
                    trailing: Text(widget.record.language),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('時長'),
                    trailing: Text('${widget.record.durationSec} 秒'),
                  ),
                  const Divider(),
                  if (widget.user.id == widget.record.studentId) ...[
                    const Text(
                      "公開權限設定：",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: widget.record.privacy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Private',
                          child: Text('私人 (僅自己可見)'),
                        ),
                        DropdownMenuItem(
                          value: 'Class',
                          child: Text('班級 (老師與同學可見)'),
                        ),
                        DropdownMenuItem(
                          value: 'Platform',
                          child: Text('平台 (公開)'),
                        ),
                      ],
                      onChanged: _updatePrivacy,
                    ),
                  ],
                  const Spacer(),
                  // 回放功能按鈕 (這裡只做 UI 示意)
                  const Icon(Icons.play_circle, size: 80, color: Colors.grey),
                  const Text("播放影片 (需實作雲端儲存)"),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kLuminewDeepIndigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoInitialized && _videoController != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Transform.scale(
                scaleX: -1, // ★ 左右翻轉 (鏡像)
                child: VideoPlayer(_videoController!),
              ),
            ),
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: kLuminewDeepIndigo,
              ),
            ),
            Container(
              color: Colors.black,
              child: IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () => setState(
                  () => _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play(),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _videoLoadFailed
        ? const Center(
            child: Text("影片載入失敗", style: TextStyle(color: Colors.red)),
          )
        : const Center(
            child: CircularProgressIndicator(color: kLuminewDeepIndigo),
          );
  }

  Widget _buildIndexCountView() {
    List<dynamic> timeline = [];
    try {
      timeline = jsonDecode(widget.record.timelineData);
    } catch (_) {
      return const Center(child: Text("數據缺失"));
    }
    Map<String, int> counts = {'c': 0, 'p': 0, 'n': 0, 'r': 0};
    for (var p in timeline) {
      int c = p['c'], pp = p['p'], n = p['n'], r = p['r'];
      int maxVal = [c, pp, n, r].reduce((a, b) => a > b ? a : b);
      if (c == maxVal)
        counts['c'] = counts['c']! + 1;
      else if (pp == maxVal)
        counts['p'] = counts['p']! + 1;
      else if (n == maxVal)
        counts['n'] = counts['n']! + 1;
      else if (r == maxVal)
        counts['r'] = counts['r']! + 1;
    }
    return Column(
      children: [
        _buildCountRow("自信", counts['c']!, timeline.length, kLuminewConfident),
        _buildCountRow("熱忱", counts['p']!, timeline.length, kLuminewPassion),
        _buildCountRow("緊張", counts['n']!, timeline.length, kLuminewNervous),
        _buildCountRow("沈穩", counts['r']!, timeline.length, kLuminewRelaxed),
      ],
    );
  }

  Widget _buildCountRow(String label, int count, int total, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kLuminewSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kLuminewDeepIndigo.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 4, height: 40, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kLuminewDeepIndigo,
                    ),
                  ),
                  Text(
                    "主導了 $count 秒",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Text(
            "${count}s",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageBars() {
    final stats = [
      {
        'label': "自信",
        'score': widget.record.scores['confidence'] ?? 0,
        'color': kLuminewConfident,
      },
      {
        'label': "熱忱",
        'score': widget.record.scores['passion'] ?? 0,
        'color': kLuminewPassion,
      },
      {
        'label': "緊張",
        'score': widget.record.scores['nervous'] ?? 0,
        'color': kLuminewNervous,
      },
      {
        'label': "沈穩",
        'score': widget.record.scores['relaxed'] ?? 0,
        'color': kLuminewRelaxed,
      },
    ];
    return Column(
      children: stats
          .map(
            (s) => _buildStatRow(
              s['label'] as String,
              s['score'] as int,
              s['color'] as Color,
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatRow(String label, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kLuminewDeepIndigo,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "$score%",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: score / 100,
            color: color,
            backgroundColor: kLuminewPalePurple,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? kLuminewMainPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSyncProgress() {
    double maxSec = 10;
    try {
      List<dynamic> timeline = jsonDecode(widget.record.timelineData);
      if (timeline.isNotEmpty) maxSec = (timeline.last['t'] as num).toDouble();
    } catch (_) {}
    double curSec = _videoPosition.inMilliseconds / 1000.0;
    double progress = (curSec / maxSec).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            color: Colors.red,
            backgroundColor: Colors.grey[200],
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${curSec.toStringAsFixed(1)}s",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "影片時間軸同步",
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              Text(
                "${maxSec.toStringAsFixed(1)}s",
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineChart() {
    List<dynamic> timeline = [];
    try {
      timeline = jsonDecode(widget.record.timelineData);
    } catch (_) {
      return const SizedBox();
    }
    if (timeline.isEmpty) return const SizedBox();

    double maxSec = (timeline.last['t'] as num).toDouble();
    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20, right: 10),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxSec,
          minY: 0,
          maxY: 100,
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              if (event is FlTapUpEvent &&
                  response != null &&
                  response.lineBarSpots != null &&
                  response.lineBarSpots!.isNotEmpty) {
                final ts = response.lineBarSpots!.first.x;
                _videoController?.seekTo(
                  Duration(milliseconds: (ts * 1000).toInt()),
                );
                _videoController?.play();
              }
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey[100]!, strokeWidth: 1),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _buildLine(timeline, 'c', kLuminewConfident),
            _buildLine(timeline, 'p', kLuminewPassion),
            _buildLine(timeline, 'n', kLuminewNervous),
            _buildLine(timeline, 'r', kLuminewRelaxed),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<dynamic> data, String key, Color color) {
    return LineChartBarData(
      spots: data
          .map(
            (e) =>
                FlSpot((e['t'] as num).toDouble(), (e[key] as num).toDouble()),
          )
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}
