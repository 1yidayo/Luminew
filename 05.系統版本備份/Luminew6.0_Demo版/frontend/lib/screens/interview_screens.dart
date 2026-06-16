// fileName: lib/screens/interview_screens.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui'; // ★ 新增：支援磨砂濾鏡效果
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../widgets/luminew_header.dart'; // 導入統一標頭
import '../theme/app_theme.dart'; // 導入 AppColors
import 'student_screens.dart';
import 'auth_screen.dart';
import '../utils/web_uploader_stub.dart'
    if (dart.library.html) '../utils/web_uploader.dart'; // ★ Web XHR 上傳 + 進度條

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
      color: kLuminewMainPurple.withOpacity(0.15), // 同步論壇：15% 通透紫
      borderRadius: BorderRadius.circular(kRadiusM),
      border: isError
          ? Border.all(color: Colors.redAccent, width: 2)
          : Border.all(color: kLuminewMainPurple.withOpacity(0.05)),
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
const kLuminewGooseYellow = Color(0xFFFFFDF0); // 背景鵝黃色
const kLuminewDeepIndigo = Color(0xFF675B83); // 文字深紫色
const kLuminewSurface = Colors.white; // 卡片表面
const kLuminewSuccess = Color.fromARGB(255, 142, 202, 187);
const kLuminewWarning = Color.fromARGB(255, 253, 199, 138);
const kLuminewConfident = Color.fromARGB(255, 253, 230, 138);
const kLuminewNervous = Color.fromARGB(255, 148, 197, 238);
const kLuminewPassion = Color.fromARGB(255, 236, 174, 181);
const kLuminewRelaxed = Color.fromARGB(255, 160, 219, 204);

const double kRadiusL = 24.0;
const double kRadiusM = 16.0;
const double kRadiusS = 10.0;
const kLuminewRadius = 20.0; // 舊的導角，維持部分相容

// ★ 質感風下拉選單
Widget _buildDropdown(
  BuildContext context,
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ), // 2/3 高度 (原本是 8)
        decoration: BoxDecoration(
          color: kLuminewMainPurple.withOpacity(0.15), // 恢復紫色通透底
          borderRadius: BorderRadius.circular(kRadiusM),
          border: Border.all(color: kLuminewMainPurple.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: kLuminewDeepIndigo.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: currentValue,
              hint: const Text(
                "請選擇",
                style: TextStyle(color: Color(0xFF333333)),
              ),
              style: const TextStyle(
                color: Color(0xFF5A5A5A), // ★ 統一使用質感深灰色
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              isExpanded: true,
              borderRadius: BorderRadius.circular(kRadiusM),
              dropdownColor: kLuminewGooseYellow, // 選單背景：鵝黃色
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: kLuminewMainPurple,
              ),
              onChanged: onChange,
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          // ★ 點開時：選取項為紫色預覽 (kLuminewMainPurple) vs 未選取項為深灰色 (0xFF5A5A5A)
                          color: e == currentValue
                              ? kLuminewMainPurple
                              : const Color(0xFF5A5A5A),
                          fontWeight: e == currentValue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
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
  late Future<List<InterviewRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _refreshRecords();
  }

  void _refreshRecords() {
    setState(() {
      _recordsFuture = ApiService.getRecords(widget.user.id, filter: 'All');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLuminewGooseYellow,
      body: Stack(
        children: [
          FutureBuilder<List<InterviewRecord>>(
            future: _recordsFuture,
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
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text("載入失敗: ${snapshot.error}"),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _refreshRecords,
                        child: const Text("再試一次"),
                      ),
                    ],
                  ),
                );
              }

              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return const Center(
                  child: Text("目前沒有面試紀錄", style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 20), // 預留標頭空間
                itemCount: records.length,
                itemBuilder: (ctx, i) {
                  final rec = records[i];
                  return _buildRecordItem(rec);
                },
              );
            },
          ),
          LuminewHeader(
            title: '面試紀錄', // 簡化標題
            showBackButton: false, // 移除返回鍵以防誤觸退出
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: kLuminewDeepIndigo),
                onPressed: _refreshRecords,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(InterviewRecord r) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: kLuminewMainPurple.withOpacity(0.15), // 同步：15% 通透紫
        borderRadius: BorderRadius.circular(kRadiusM),
        border: Border.all(color: kLuminewMainPurple.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        splashColor: Colors.transparent, // ★ 移除黑色閃爍
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: kLuminewGooseYellow,
            shape: BoxShape.circle,
            border: Border.all(color: kLuminewMainPurple.withOpacity(0.2)),
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
          r.interviewName.isNotEmpty ? r.interviewName : '${r.type} 面試',
          style: const TextStyle(
            color: kLuminewDeepIndigo,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${r.date.year}/${r.date.month}/${r.date.day} | ${r.type} | ${r.durationSec ~/ 60}\'${(r.durationSec % 60).toString().padLeft(2, '0')}\"',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: kLuminewMainPurple),
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
  String _interviewer = '引導型教授';
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
  Uint8List? _selectedFileBytes; // ★ Web 用 bytes
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
    _requestPermissionsEarly();
  }

  Future<void> _requestPermissionsEarly() async {
    // 從主頁進入設定頁面時，第一時間要求相機與麥克風權限，讓設備有時間緩衝穩定
    await [Permission.camera, Permission.microphone].request();
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
      withData: true, // ★ Web 需要此參數才能讀到 bytes
    );

    if (result != null) {
      final file = result.files.single;
      setState(() {
        if (kIsWeb) {
          _selectedFileBytes = file.bytes;
          _selectedFile = null;
        } else {
          _selectedFile = File(file.path!);
          _selectedFileBytes = null;
        }
        _selectedFileName = file.name;
        _pdfError = false; // ★ 檔案選好了，清除紅字提示
        _generatedQuestions = []; // 清除舊問題
      });

      // 自動開始分析
      await _analyzeFileAndGenerateQuestions();
    }
  }

  // ★ 上傳檔案並生成問題
  Future<void> _analyzeFileAndGenerateQuestions() async {
    if (_selectedFile == null && _selectedFileBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.httpUrl}/emotion/generate_questions'),
      );

      // ★ 跳過 Ngrok 警告頁面，確保 MultipartRequest 也能直接獲得 JSON 回應
      request.headers['ngrok-skip-browser-warning'] = 'true';

      if (kIsWeb && _selectedFileBytes != null) {
        // ★ Web：用 bytes，不能用 fromPath
        request.files.add(
          http.MultipartFile.fromBytes('pdf', _selectedFileBytes!, filename: _selectedFileName),
        );
      } else if (!kIsWeb && _selectedFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('pdf', _selectedFile!.path),
        );
      }
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
          setState(() {
            _generatedQuestions = [];
          });
          String userMsg = "檔案分析失敗，請重新上傳！";
          if (data['message'] == 'empty_pdf') {
            userMsg = "檔案分析失敗：PDF 內沒有可讀取的文字，請重新上傳含有文字的檔案！";
          } else if (data['message'] == 'pdf_read_error') {
            userMsg = "檔案分析失敗：無法讀取該 PDF 檔案，請確認是否損毀並重新上傳！";
          } else if (data['message'] == 'no_api_key') {
            userMsg = "系統錯誤：未配置 API 金鑰，請聯繫管理員！";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMsg), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        print("❌ API 錯誤: ${response.statusCode}");
        setState(() {
          _generatedQuestions = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('伺服器連線異常，請稍後再試！'), backgroundColor: Colors.redAccent),
        );
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
      backgroundColor: kLuminewGooseYellow, // 保持鵝黃背景
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _setupScrollController,
            padding: const EdgeInsets.fromLTRB(24, 110, 24, 20), // 預留標頭空間
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
                        style: const TextStyle(
                          color: Color(0xFF5A5A5A), // ★ 打字顏色維持深灰色
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "面試名稱",
                          hintStyle: TextStyle(
                            color: Colors.grey.withOpacity(0.7),
                          ),
                          errorText: _nameError,
                          errorStyle: const TextStyle(color: Colors.redAccent),
                          prefixIcon: Icon(
                            Icons.title,
                            color: _nameError != null
                                ? Colors.redAccent
                                : kLuminewMainPurple,
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
                        context,
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
                        context,
                        "面試教授",
                        ['引導型教授', '親和型教授', '嚴謹型教授'],
                        (val) => setState(() => _interviewer = val!),
                        _interviewer,
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        context,
                        "語言設定",
                        ['中文', '英文 (暫不開放)'],
                        (val) {
                          if (val == '英文 (暫不開放)') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('英文模式正在開發中，暫不開放')),
                            );
                            return;
                          }
                          setState(() => _lang = val!);
                        },
                        _lang == '英文' ? '英文 (暫不開放)' : _lang,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ★ 錄影設定卡片 (精簡風格)
                _buildPremiumCard(
                  title: "錄影本次面試",
                  icon: Icons.videocam,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '結束後可回顧自己的表情與肢體動作',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                      Switch(
                        activeColor: kLuminewMainPurple,
                        value: _saveVideo,
                        onChanged: (v) => setState(() => _saveVideo = v),
                      ),
                    ],
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
                        _type == '學習歷程'
                            ? "請務必上傳檔案，AI 方能針對內容提問"
                            : "上傳學習歷程或自傳，AI 會針對內容提問",
                        style: TextStyle(
                          color: _pdfError ? Colors.redAccent : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 15),
                      InkWell(
                        onTap: _isAnalyzing ? null : _pickFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: kLuminewGooseYellow.withOpacity(0.5),
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
                          icon: Icon(
                            _calibrationDone ? Icons.check : Icons.face,
                          ),
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
                    onPressed: (_isAnalyzing)
                        ? null // 解析時禁用按鈕
                        : () {
                            // 1. 校驗名稱
                            if (_nameController.text.trim().isEmpty) {
                              setState(() => _nameError = "請輸入面試名稱");
                              _scrollTo(_nameCardKey);
                              return;
                            }
                            // 2. 校驗檔案
                            if (_type == '學習歷程' && _selectedFile == null && _selectedFileBytes == null) {
                              setState(() => _pdfError = true);
                              _scrollTo(_pdfCardKey);
                              return;
                            }
                            // 3. 校驗分析狀態
                            if ((_selectedFile != null || _selectedFileBytes != null) &&
                                _generatedQuestions.isEmpty &&
                                _isAnalyzing) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('AI 正在分析您的 PDF，請稍候...'),
                                ),
                              );
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
                                  questions: _generatedQuestions.isNotEmpty ? _generatedQuestions : null,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAnalyzing
                          ? Colors.grey
                          : kLuminewMainPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _isAnalyzing ? 0 : 8,
                      shadowColor: kLuminewMainPurple.withOpacity(0.4),
                    ),
                    child: Text(
                      _isAnalyzing ? 'AI 分析檔案中...' : '開始模擬面試',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                // ★ 修改後的免責聲明
                /*
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
                */
              ],
            ),
          ),
          // --- 同步標頭：具備與論壇一致的返回箭頭 ---
          const LuminewHeader(title: '面試場景設定', showBackButton: true),
        ],
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
        Uri.parse(
          '${AppConfig.httpUrl}/emotion/calibrate',
        ),
      );
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            await file.readAsBytes(),
            filename: file.name,
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('video', file.path));
      }

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

class _MockInterviewScreenState extends State<MockInterviewScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  final _webRecorder = WebVideoRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0; // 0.0 ~ 1.0 上傳進度

  // ★ 使用導覽元件的 GlobalKey 定位
  final GlobalKey _statusBarKey = GlobalKey();
  final GlobalKey _professorVideoKey = GlobalKey();
  final GlobalKey _studentCameraKey = GlobalKey();
  final GlobalKey _micButtonKey = GlobalKey();
  int _sec = 0;
  Timer? _timer;
  String _statusMessage = "";

  // ★ WebSocket 即時面試
  late final DidInterviewService _didService;
  bool _isInterviewing = false;
  bool _isWsConnecting = false;
  bool _isWaitingProfessor = false;
  bool _canStudentSpeak = false; // ★ 新增：控制學生是否可以說話（延遲顯示開麥）
  bool _isVideoTrackReceived = false; // ★ 新增：影像軌道是否已成功接收
  bool _hasFirstSpeakStarted = false; // ★ 新增：標記教授是否已經開始過第一次說話
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  String _connectionStatus = "Disconnected";

  String get _connectionStatusChinese {
    final statusLower = _connectionStatus.toLowerCase();
    if (statusLower.contains('connected') || statusLower.contains('completed')) {
      return _isVideoTrackReceived ? '已連線' : '連線中...';
    } else if (statusLower.contains('checking') || statusLower.contains('new') || statusLower.contains('connecting')) {
      return '連線中...';
    } else if (statusLower.contains('disconnected')) {
      return '尚未連線';
    } else if (statusLower.contains('failed')) {
      return '連線失敗';
    } else if (statusLower.contains('closed')) {
      return '連線已關閉';
    } else {
      return _connectionStatus;
    }
  }

  String _getConnectionLoadingText() {
    final statusLower = _connectionStatus.toLowerCase();
    if (statusLower.contains('failed')) {
      return "連線失敗，請重試";
    }
    return "連線虛擬教授中，請稍候...";
  }

  void _onRemoteVideoValueChange() {
    if (_didService.remoteRenderer.value.width > 0 && !_isVideoTrackReceived) {
      print("📺 [WebRTC] 偵測到影片首幀寬度已大於 0 (${_didService.remoteRenderer.value.width}x${_didService.remoteRenderer.value.height})，立即移開毛玻璃卡片");
      if (mounted) {
        setState(() {
          _isVideoTrackReceived = true;
        });
      }
    }
  }

  // ★ 麥克風動畫與教授說話監控變數
  late AnimationController _micWaveController;
  Timer? _amplitudeTimer;
  double _micAmplitude = 0.0;

  Timer? _professorSpeakTimer;
  bool _hasProfessorStartedSpeaking = false;
  int _professorSilentTicks = 0;
  int _professorLoadTicks = 0;
  bool _receivedInterviewEnd = false;

  // ★ TTS 音訊播放

  @override
  void initState() {
    super.initState();
    final baseUrl = ApiService.baseUrl.replaceAll('/api/db', '');
    _didService = DidInterviewService(backendUrl: baseUrl);
    _didService.remoteRenderer.addListener(_onRemoteVideoValueChange); // ★ 新增監聽器
    _didService.init().then((_) {
      if (mounted) setState(() {});
    });
    _initCamera();
    _setupWsCallbacks();
    _micWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

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
            // 重設監聽器狀態
            _hasProfessorStartedSpeaking = false;
            _professorSilentTicks = 0;
            _professorLoadTicks = 0;
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
      print("🔊 [WebSocket] 收到 tts_done，使用 WebRTC Stats 音量監控中，忽略此事件的主動開麥");
    };
    _didService.onVideoTrack = () {
      if (mounted) {
        print('📺 [UI] 偵測到視訊軌道掛載，等待解碼器繪製首影格...');
      }
    };
    _didService.onConnectionState = (state) {
      if (mounted) {
        setState(() {
          _connectionStatus = state;
        });
      }
    };
    _didService.onInterviewEnd = () {
      if (mounted) {
        print('🏁 [UI] 面試結束信號收到，等待教授結語播放完畢...');
        setState(() {
          _receivedInterviewEnd = true;
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
      _isVideoTrackReceived = false; // ★ 重置狀態
      _hasFirstSpeakStarted = false; // ★ 重置狀態
    });

    // 如果開啟了錄影分析，也要同步啟動錄影
    if (widget.saveVideo && !_isRecording) {
      // 這裡不直接 await _startRecording 是為了避免阻塞 WS 連線
      _startRecording();
    }

    print(
      '🎙️ [Interview] 開始建立與 D-ID 的 WebRTC 連線 (教授: ${widget.interviewer})...',
    );
    await _didService.startInterview(widget.interviewer, widget.type, customQuestions: widget.questions);
    if (mounted) {
      setState(() {
        _isInterviewing = true;
        _isWsConnecting = false;
        _receivedInterviewEnd = false;
      });
      _startProfessorSpeakMonitor();
    }
  }

  void _stopLiveInterview() {
    print(
      "⏹ [Interview] 手動停止面試指令觸發 - 當前錄製狀態: $_isRecording, 面試狀態: $_isInterviewing",
    );

    // 如果正在錄製中，優先走錄製結束流程（該流程會自動清理面試狀態並分析跳轉）
    if (_isRecording) {
      _stopAndAnalyze();
      return;
    }

    print("⚠️ [Interview] 偵測到未進入錄製模式或錄製已失效，僅關閉串流...");
    // 單純停止 WebRTC 與 WebSocket
    _didService.stopInterview();
    if (mounted) {
      setState(() {
        _isInterviewing = false;
        _isWsConnecting = false;
        _isWaitingProfessor = false;
      });
      // 如果未錄製但結束了，提醒一下用戶
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('面試已停止 (未錄製影片也將不會有分析報告)')));
    }
  }

  void _signalSpeechEnd() {
    _stopAmplitudeMonitor();
    _didService.stopRecording();
    setState(() {
      _isWaitingProfessor = true;
      _canStudentSpeak = false;
    });
  }

  void _startAudioStream() {
    _didService.startRecording();
    _startAmplitudeMonitor();
  }

  void _startAmplitudeMonitor() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!_canStudentSpeak || !mounted) return;
      final amp = await _didService.getCurrentAmplitudeDb();
      if (mounted) setState(() => _micAmplitude = amp);
    });
  }

  void _stopAmplitudeMonitor() {
    _amplitudeTimer?.cancel();
    if (mounted) setState(() => _micAmplitude = 0.0);
  }

  void _startProfessorSpeakMonitor() {
    _professorSpeakTimer?.cancel();
    _hasProfessorStartedSpeaking = false;
    _professorSilentTicks = 0;
    _professorLoadTicks = 0;

    _professorSpeakTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted || !_isInterviewing) return;

      if (_isWaitingProfessor) {
        _professorLoadTicks++;
        bool isSpeaking = await _didService.isProfessorSpeaking();
        if (isSpeaking) {
          if (!_hasProfessorStartedSpeaking) {
            print("🔊 [Monitor] 偵測到教授開始說話");
            setState(() {
              _hasProfessorStartedSpeaking = true;
              _hasFirstSpeakStarted = true; // ★ 首次說話已開始，允許後續思考時顯示遮罩
            });
          }
          _professorSilentTicks = 0;

          // ★ 新增：如果本來在背景預開麥錄音，現在教授又出聲了，必須立刻關閉並丟棄
          if (_didService.isRecording) {
            print("🔇 [Monitor] 偵測到教授繼續發言，關閉背景預收音");
            _stopAmplitudeMonitor();
            await _didService.cancelRecording();
          }
        } else {
          // 安全超時降級：若已等待 12 秒且教授從未開始說話，視同已說完話
          if (!_hasProfessorStartedSpeaking && _professorLoadTicks >= 120) {
            print("⚠️ [Monitor] 教授加載超時 (12秒)，強制視同說完話");
            setState(() {
              _hasProfessorStartedSpeaking = true;
            });
          }
          
          if (_hasProfessorStartedSpeaking) {
            _professorSilentTicks++;

            // ★ 新增：在靜音達 0.7 秒時（7 ticks），背景預先開啟麥克風收音
            if (_professorSilentTicks == 7 && !_didService.isRecording) {
              print("🎙️ [Monitor] 靜音達 0.7 秒，背景啟動預收音");
              _startAudioStream();
            }

            if (_professorSilentTicks >= 12) { // 1.2 秒靜音
              print("🔇 [Monitor] 偵測到教授說話結束");
              setState(() {
                _hasProfessorStartedSpeaking = false;
                _professorSilentTicks = 0;
                _professorLoadTicks = 0;
                _isWaitingProfessor = false; // 重設此狀態
              });
              
              if (_receivedInterviewEnd) {
                print("🏁 [Monitor] 偵測到結語播放完畢，啟動自動分析");
                _stopAndAnalyze();
              } else {
                setState(() {
                  _canStudentSpeak = true;
                });
                if (!_didService.isRecording) {
                  _startAudioStream();
                }
              }
            }
          }
        }
      } else {
        _professorLoadTicks = 0;
      }
    });
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

        // 在 Web 上，initialize 會觸發瀏覽器權限詢問
        await _controller!.initialize();
        if (mounted) {
          setState(() {});
          // ★ 新增：如果使用者需要導覽，於相機初始化完成且畫面渲染後 300 毫秒開啟
          if (widget.user.showTutorial) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _startTutorialFlow();
              }
            });
          }
        }
        print("✅ 相機初始化完成");
      } else {
        setState(() => _statusMessage = "找不到相機鏡頭，請檢查設備是否已連接或被封鎖。");
        print("⚠️ 找不到相機鏡頭");
      }
    } catch (e) {
      print("❌ 相機初始化失敗: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("NotAllowedError") || errorMsg.contains("Permission denied")) {
        errorMsg = "權限被拒絕，請點擊網址列左側「鎖頭」圖標並手動允許相機權限。";
      } else if (errorMsg.contains("NotFoundError")) {
        errorMsg = "找不到可用的相機設備。";
      }
      setState(() => _statusMessage = "相機開啟失敗: $errorMsg");
    } finally {
      // 確保不論相機鏡頭啟動成功或失敗，都自動開始連線 AI 教授
      if (mounted && !_isInterviewing && !_isWsConnecting) {
        _startLiveInterview();
      }
    }
  }

  @override
  void dispose() {
    _didService.remoteRenderer.removeListener(_onRemoteVideoValueChange); // ★ 移除監聽器
    _tutorialOverlayEntry?.remove();
    _tutorialOverlayEntry = null;
    _controller?.dispose();
    _webRecorder.dispose(); // 新增釋放 Web 錄影資源
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _professorSpeakTimer?.cancel();
    _micWaveController.dispose();
    _didService.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // ★ 修正：Web 環境略過 Permission.microphone.request，因為網頁版會由瀏覽器自動處理
      if (!kIsWeb) {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('需要麥克風權限才能錄影')));
          }
          return;
        }
      }

      if (kIsWeb) {
        await _webRecorder.start();
      } else {
        await _controller!.startVideoRecording();
      }
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
    _stopAmplitudeMonitor(); // ★ 先停止音波監控

    // 1. 同步停止面試狀態
    _didService.stopInterview();

    // 停止計時與錄影
    _timer?.cancel();
    XFile file;
    try {
      if (kIsWeb) {
        final url = await _webRecorder.stop();
        if (url == null) throw Exception("網頁錄影失敗，無法取得影片 URL");
        file = XFile(url, name: 'video.webm');
      } else {
        file = await _controller!.stopVideoRecording();
      }
    } catch (e) {
      print("❌ [Record] 停止錄影失敗: $e");
      if (mounted) {
        setState(() => _isRecording = false); // 強制解除錄製狀態
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('停止錄影失敗: $e\n請重試或確認相機權限')));
      }
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

      if (kIsWeb) {
        // ★ Web 版：用 XHR 分塊上傳，支援即時進度回呼，避免大檔超時
        final webApiUrl = '${ApiService.rootUrl}/emotion/upload_chunk';
        print("★★★ [Web] 使用 XHR 分塊上傳影片到: $webApiUrl ★★★");

        final responseBody = await uploadVideoWebChunked(
          file.path, // blobUrl（Web 下 XFile.path 就是 blob URL）
          file.name, // fileName
          webApiUrl, // url
          {         // fields
            'save_video': widget.saveVideo ? 'true' : 'false',
            'interviewer': widget.interviewer,
            if (_chatMessages.isNotEmpty) 'transcript': jsonEncode(_chatMessages),
            if (widget.baseline != null) 'baseline': jsonEncode(widget.baseline),
          },
          onProgress: (percent) {
            if (mounted) setState(() => _uploadProgress = percent);
          },
        );

        // 上傳完成，進度條跳到 100%
        if (mounted) setState(() => _uploadProgress = 1.0);


        var data = jsonDecode(responseBody);

        // ★ 檢查是否為非同步任務 (job_id)
        if (data.containsKey('job_id')) {
          final jobId = data['job_id'];
          print('★★★ 開始輪詢任務狀態: $jobId ★★★');

          bool isDone = false;
          while (!isDone) {
            await Future.delayed(const Duration(seconds: 3));
            final statusRes = await http.get(Uri.parse('${ApiService.rootUrl}/emotion/status/$jobId'));
            if (statusRes.statusCode == 200) {
              final statusData = jsonDecode(statusRes.body);
              if (statusData['status'] == 'done') {
                data = statusData['result'];
                isDone = true;
                print('★★★ 分析完成！ ★★★');
              } else if (statusData['status'] == 'error') {
                throw Exception('後端分析發生錯誤: ${statusData['result']['error']}');
              }
            }
          }
        }

        // ★ 內嵌結果處理（與 Native 路徑相同邏輯）
        if (data.containsKey('error')) {
          data['emotions'] = {'confidence': 0, 'nervous': 0, 'passion': 0, 'relaxed': 0};
          data['ai_analysis'] = {
            'overall_score': 0,
            'comment': '【系統警告】無法從影片中偵測到清晰的人臉，情緒分析已強制略過。\n\n' + (data['error'] ?? ''),
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

        final r = InterviewRecord(
          id: 'IR${DateTime.now().millisecondsSinceEpoch}',
          studentId: widget.user.email,
          date: DateTime.now(),
          durationSec: _sec,
          scores: {
            'overall': (ai['overall_score'] as num? ?? 0).toInt(),
            'confidence': (emotions['confidence'] as num? ?? 0).toInt(),
            'passion': (emotions['passion'] as num? ?? 0).toInt(),
            'nervous': (emotions['nervous'] as num? ?? 0).toInt(),
            'relaxed': (emotions['relaxed'] as num? ?? 0).toInt(),
            'emotion_management': (100 - ((emotions['nervous'] as num?) ?? 0)).toInt(),
            'relevance': ((ai['relevance'] ?? ai['overall_score'] ?? 0) as num).toInt(),
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
        return; // ★ Web 分支結束
      }

      // ★ 以下為 Native (iOS/Android) 上傳流程 ★
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('video', file.path),
      );
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

        // ★ 新增：檢查是否為非同步任務 (job_id)
        if (data.containsKey('job_id')) {
          final jobId = data['job_id'];
          print('★★★ 開始輪詢任務狀態: $jobId ★★★');
          
          bool isDone = false;
          while (!isDone) {
            await Future.delayed(const Duration(seconds: 5)); // 每 5 秒問一次
            final statusRes = await http.get(Uri.parse('${ApiService.rootUrl}/emotion/status/$jobId'));
            if (statusRes.statusCode == 200) {
              final statusData = jsonDecode(statusRes.body);
              if (statusData['status'] == 'done') {
                data = statusData['result']; // 取得最終分析結果
                isDone = true;
                print('★★★ 分析完成！ ★★★');
              } else if (statusData['status'] == 'error') {
                throw Exception('後端分析發生錯誤: ${statusData['result']['error']}');
              } else {
                print('... 影片分析中 ...');
              }
            } else {
              throw Exception('無法取得任務進度，狀態碼: ${statusRes.statusCode}');
            }
          }
        }

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
            'overall': (ai['overall_score'] as num? ?? 0).toInt(),
            'confidence': (emotions['confidence'] as num? ?? 0).toInt(),
            'passion': (emotions['passion'] as num? ?? 0).toInt(),
            'nervous': (emotions['nervous'] as num? ?? 0).toInt(),
            'relaxed': (emotions['relaxed'] as num? ?? 0).toInt(),
            'emotion_management': (100 - ((emotions['nervous'] as num?) ?? 0)).toInt(),
            'relevance': ((ai['relevance'] ?? ai['overall_score'] ?? 0) as num).toInt(),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ 紀錄儲存失敗：$dbError'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 5),
              ),
            );
          }
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

  // ★ 使用導覽相關狀態與定位引導方法
  OverlayEntry? _tutorialOverlayEntry;
  int _tutorialStep = 0;

  Offset _getWidgetPosition(GlobalKey key) {
    if (key.currentContext == null) return Offset.zero;
    final renderBox = key.currentContext!.findRenderObject() as RenderBox;
    return renderBox.localToGlobal(Offset.zero);
  }

  Size _getWidgetSize(GlobalKey key) {
    if (key.currentContext == null) return Size.zero;
    final renderBox = key.currentContext!.findRenderObject() as RenderBox;
    return renderBox.size;
  }

  void _startTutorialFlow() {
    setState(() {
      _tutorialStep = 1;
    });
    _showTutorialOverlay();
  }

  void _nextTutorialStep() {
    if (_tutorialStep < 4) {
      setState(() {
        _tutorialStep++;
      });
      _tutorialOverlayEntry?.markNeedsBuild();
    } else {
      _endTutorialFlow();
    }
  }

  void _endTutorialFlow() async {
    _tutorialOverlayEntry?.remove();
    _tutorialOverlayEntry = null;
    setState(() {
      _tutorialStep = 0;
    });

    try {
      await ApiService.updateTutorialStatus(widget.user.email, false);
      widget.user.showTutorial = false; // 同步更新記憶體狀態
    } catch (e) {
      print("⚠️ [Tutorial] 更新導覽狀態失敗: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('導覽播放完畢！下次進入面試間將不再主動顯示。您隨時可以在設定頁面重啟導覽。'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showTutorialOverlay() {
    _tutorialOverlayEntry = OverlayEntry(
      builder: (context) {
        GlobalKey? targetKey;
        String title = "";
        String desc = "";

        if (_tutorialStep == 1) {
          targetKey = _statusBarKey;
          title = "1. 面試資訊與狀態";
          desc = "顯示當前面試類型、面試教授、語言，以及累計時間與教授連線狀態。";
        } else if (_tutorialStep == 2) {
          targetKey = _professorVideoKey;
          title = "2. AI 教授視訊";
          desc = "面試教授的影像呈現區域。請看著教授聆聽問題與互動。";
        } else if (_tutorialStep == 3) {
          targetKey = _studentCameraKey;
          title = "3. 個人鏡頭預覽";
          desc = "您的即時鏡頭畫面。AI 將在面試期間分析您的面部表情。";
        } else if (_tutorialStep == 4) {
          targetKey = _micButtonKey;
          title = "4. 語音控制按鈕";
          desc = "進入時單擊以連線教授。教授發言完畢會自動開啟麥克風，此時即可發言，發言結束再單擊按鈕關閉。如欲提前結束，長按此處即可開始 AI 分析。";
        }

        Offset targetOffset = Offset.zero;
        Size targetSize = Size.zero;
        if (targetKey != null) {
          targetOffset = _getWidgetPosition(targetKey);
          targetSize = _getWidgetSize(targetKey);
        }

        // ★ 當找不到定位或尺寸為 0 時（例如尚未佈局），使用預設的備用範圍
        if (targetOffset == Offset.zero || targetSize == Size.zero) {
          targetOffset = const Offset(50, 100);
          targetSize = const Size(200, 50);
        }

        final targetRect = Rect.fromLTWH(
          targetOffset.dx - 8,
          targetOffset.dy - 8,
          targetSize.width + 16,
          targetSize.height + 16,
        );

        return GestureDetector(
          onTap: _nextTutorialStep,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // A. 背景微暗遮罩 (0.2 透明度)
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.2),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                      ),
                      Positioned(
                        left: targetRect.left,
                        top: targetRect.top,
                        width: targetRect.width,
                        height: targetRect.height,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // B. 指引氣泡框 (半透明紫色)
              Positioned(
                left: (targetOffset.dx + targetSize.width / 2 - 130).clamp(16.0, MediaQuery.of(context).size.width - 276.0),
                top: targetOffset.dy + targetSize.height + 16 > MediaQuery.of(context).size.height - 220
                    ? targetOffset.dy - 160
                    : targetOffset.dy + targetSize.height + 16,
                width: 260,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xE6675B83), // 紫色半透明
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFAD9DC7).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFFFFFDF0),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          desc,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "點擊任意處繼續 ➔",
                              style: TextStyle(
                                color: Color(0xFFFFFDF0),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_tutorialOverlayEntry!);
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
      backgroundColor: kLuminewGooseYellow,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // 1. 頂部狀態列
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        key: _statusBarKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
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
                                    color: _connectionStatus.toLowerCase().contains('connected') ||
                                           _connectionStatus.toLowerCase().contains('completed')
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _connectionStatusChinese,
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
                  child: AspectRatio(
                    key: _professorVideoKey,
                    aspectRatio: 1.0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kLuminewMainPurple.withOpacity(0.95),
                          width: 1,
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
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // A. 教授影像 (使用遠端渲染器)
                          DidVideoWidget(renderer: _didService.remoteRenderer),

                          // B. 連線初始化毛玻璃遮罩 (方案 A：進房自動連線與毛玻璃加載 UI)
                          if (!_isVideoTrackReceived)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            color: kLuminewMainPurple,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _getConnectionLoadingText(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // C. 載入中遮罩 (當已連線且教授正在思考下一個問題時)
                          if (_isVideoTrackReceived && _isWaitingProfessor && !_hasProfessorStartedSpeaking && _hasFirstSpeakStarted)
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
                                      "教授思考中...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // C. 懸浮字幕 (Floating Overlay - 暂時注解)
                          // if (_chatMessages.isNotEmpty)
                          //   Positioned(
                          //     bottom: 12,
                          //     left: 12,
                          //     right: 12,
                          //     child: Container(
                          //       height: 110,
                          //       padding: const EdgeInsets.all(12),
                          //       decoration: BoxDecoration(
                          //         color: Colors.grey.withOpacity(0.6),
                          //         borderRadius: BorderRadius.circular(16),
                          //         border: Border.all(color: Colors.white24),
                          //       ),
                          //       child: ListView.builder(
                          //         controller: _chatScrollController,
                          //         padding: EdgeInsets.zero,
                          //         itemCount: _chatMessages.length,
                          //         itemBuilder: (context, index) {
                          //           final msg = _chatMessages[index];
                          //           final isStudent = msg['role'] == 'student';
                          //           return Padding(
                          //             padding: const EdgeInsets.symmetric(vertical: 4),
                          //             child: Row(
                          //               crossAxisAlignment: CrossAxisAlignment.start,
                          //               children: [
                          //                 Text(
                          //                   isStudent ? "我：" : "教授：",
                          //                   style: TextStyle(
                          //                     color: isStudent ? Colors.lightBlueAccent : Colors.amberAccent,
                          //                     fontSize: 12,
                          //                     fontWeight: FontWeight.bold,
                          //                   ),
                          //                 ),
                          //                 Expanded(
                          //                   child: Text(
                          //                     msg['text'] ?? "",
                          //                     style: const TextStyle(
                          //                       color: Colors.white,
                          //                       fontSize: 13,
                          //                       height: 1.4,
                          //                     ),
                          //                   ),
                          //                 ),
                          //               ],
                          //             ),
                          //           );
                          //         },
                          //       ),
                          //     ),
                          //   ),
                      ],
                      ),
                    ), // end of ClipRRect
                  ), // end of Container
                ), // end of AspectRatio
              ), // end of Padding

                const SizedBox(height: 12),

                // 3. 底部區域量體優化 (移除冗餘問題顯示，留待結束分析後查看)
                const SizedBox(height: 24),

                // 3. 底部控制按鈕
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    child: Column(
                      children: [
                        // 進度條
                        if (_uploadProgress < 1.0) ...[
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: kLuminewMainPurple.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(kLuminewMainPurple),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "正在上傳影片... ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(
                              color: kLuminewMainPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          const CircularProgressIndicator(color: kLuminewMainPurple),
                          const SizedBox(height: 12),
                          const Text(
                            "影片上傳完成，AI 正在分析中...",
                            style: TextStyle(
                              color: kLuminewMainPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40, top: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _micWaveController,
                          builder: (context, child) {
                            return SizedBox(
                              width: 180,
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 頻譜波浪指示器
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _MicSpectrumPainter(
                                        amplitude: _micAmplitude,
                                        animationValue: _micWaveController.value,
                                        isActive: _isInterviewing && _canStudentSpeak,
                                      ),
                                    ),
                                  ),
                                  // 麥克風按鈕
                                  GestureDetector(
                                    key: _micButtonKey,
                                    onTap: _isWsConnecting ||
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
                                        color: _isWaitingProfessor ||
                                                (_isInterviewing && !_canStudentSpeak)
                                            ? Colors.grey.withOpacity(0.1)
                                            : (_isInterviewing
                                                  ? kLuminewMainPurple
                                                  : Colors.grey.withOpacity(0.1)),
                                        border: Border.all(
                                          color: kLuminewMainPurple,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: kLuminewMainPurple.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _isWsConnecting
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                color: kLuminewMainPurple,
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
                                                  : kLuminewMainPurple,
                                              size: 40,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          !_isVideoTrackReceived
                              ? "連線中..."
                              : (_isWaitingProfessor
                                    ? (_hasProfessorStartedSpeaking
                                          ? "教授發言中"
                                          : "教授思考中")
                                    : (_isInterviewing
                                          ? (_canStudentSpeak ? "點擊結束個人發言" : "延遲收音中")
                                          : "開始面試對答")),
                          style: const TextStyle(
                            color: kLuminewMainPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isInterviewing || _isRecording)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "長按結束整場面試並分析",
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
        ),

          Positioned(
            top: 20,
            right: 20,
            width: 110,
            child: SafeArea(
              key: _studentCameraKey,
              bottom: false,
              left: false,
              right: false,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio > 1.0 
                      ? 1.0 / _controller!.value.aspectRatio 
                      : _controller!.value.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 學生自拍預覽：保持原始比例
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
                  ), // end of Stack
                ), // end of AspectRatio
              ), // end of ClipRRect
            ), // end of SafeArea
          ), // end of Positioned
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
  late final TextEditingController _noteCtrl; // ★ 心得控制器
  List<Comment> _comments = [];
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  Duration _videoPosition = Duration.zero;

  // ★ 筆記儲存狀態與旗標
  String _saveStatusText = "已儲存";
  bool _isSavingNote = false;

  Color get _saveStatusColor {
    if (_saveStatusText == "已儲存") return AppColors.success;
    if (_saveStatusText == "尚未儲存") return AppColors.warning;
    if (_saveStatusText == "儲存中...") return AppColors.primaryPurple;
    return AppColors.error;
  }

  bool _isIndexMode = false;
  bool _autoEmailSent = false;
  bool _isSendingEmail = false;

  List<Teacher> _studentTeachers = [];
  int? _selectedTeacherChannelId;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.record.note); // ★ 初始化心得
    _loadTeachers();
    _initVideo();
  }

  void _loadTeachers() async {
    if (widget.user.role != 'Teacher') {
      try {
        var t = await ApiService.getStudentTeachers(widget.user.email);
        if (mounted) {
          setState(() {
            _studentTeachers = t;
            if (t.isNotEmpty) _selectedTeacherChannelId = int.tryParse(t.first.id);
          });
        }
      } catch (_) {}
    } else {
      _selectedTeacherChannelId = int.tryParse(widget.user.id);
    }
    _loadComments();
  }

  @override
  void dispose() {
    _noteCtrl.dispose(); // ★ 釋放
    _videoController?.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  bool _videoLoadFailed = false;

  Future<void> _initVideo() async {
    String? url = widget.videoUrl ?? widget.record.videoUrl;
    if (url != null && url.isNotEmpty && url != 'null') {
      print("🎬 嘗試載入影片: $url");
      if (url.startsWith('http') || url.startsWith('blob:') || kIsWeb) {
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

  Widget _buildBackButton(bool showBackButton, Color? textColor) {
    return showBackButton
        ? Padding(
            padding: const EdgeInsets.only(right: 20), // 增加箭頭與文字的距離 (12 -> 20)
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
              onPressed: () => Navigator.pop(context),
              color: textColor ?? const Color(0xFF675B83),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              splashRadius: 28,
            ),
          )
        : const SizedBox.shrink();
  }

  List<Color> _getScoreGradient(int score) {
    if (score >= 90) return [Colors.green.shade400, Colors.teal];
    if (score >= 61) return [Colors.orange.shade400, Colors.deepOrange];
    return [Colors.red.shade400, Colors.redAccent];
  }

  void _loadComments() async {
    try {
      var c = await ApiService.getComments(widget.record.id, teacherChannelId: _selectedTeacherChannelId);
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
        teacherChannelId: _selectedTeacherChannelId,
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
    
    if (v == 'Teacher') {
      try {
        final teachers = await ApiService.getStudentTeachers(widget.user.email);
        if (teachers.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("您目前尚未加入任何老師")));
          }
          return;
        }
        
        List<int> selectedTeacherIds = [];
        if (!mounted) return;
        
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setStateSB) {
                return AlertDialog(
                  title: const Text("選擇要公開的老師", style: TextStyle(color: kLuminewDeepIndigo, fontWeight: FontWeight.bold)),
                  backgroundColor: kLuminewGooseYellow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusM)),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        final tId = int.tryParse(teacher.id) ?? 0;
                        return CheckboxListTile(
                          activeColor: kLuminewMainPurple,
                          title: Text(teacher.name, style: const TextStyle(color: kLuminewDeepIndigo)),
                          value: selectedTeacherIds.contains(tId),
                          onChanged: (bool? checked) {
                            setStateSB(() {
                              if (checked == true) {
                                selectedTeacherIds.add(tId);
                              } else {
                                selectedTeacherIds.remove(tId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false), 
                      child: const Text("取消", style: TextStyle(color: Colors.grey))
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLuminewMainPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusS)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text("確定")
                    ),
                  ],
                );
              }
            );
          }
        );
        
        if (confirm != true || selectedTeacherIds.isEmpty) return;
        
        await ApiService.updatePrivacy(widget.record.id, v, teacherIds: selectedTeacherIds);
        if (mounted) {
          setState(() { widget.record.privacy = v; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已改為老師可見，授權給 ${selectedTeacherIds.length} 位老師")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("更新失敗: $e")));
      }
    } else {
      try {
        await ApiService.updatePrivacy(widget.record.id, v);
        if (mounted) {
          setState(() { widget.record.privacy = v; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已改為私人")));
        }
      } catch (_) {}
    }
  }

  void _sendEmailManually() async {
    setState(() => _isSendingEmail = true);
    try {
      await ApiService.sendInterviewResultEmail(
        recipientEmail: widget.user.email,
        studentName: widget.user.name,
        overallScore: widget.record.overallScore,
        comment: (widget.record.aiComment ?? "").isNotEmpty ? widget.record.aiComment : "尚無評語",
        suggestion: (widget.record.aiSuggestion ?? "").isNotEmpty ? widget.record.aiSuggestion : "尚無建議",
        timelineText: "(詳細情緒波動數據請回 Luminew 平台查看)",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 寄送成功！請去信箱確認", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("寄信失敗：$e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  void _showNoteSheet(BuildContext context) {
    _noteCtrl.text = widget.record.note ?? "";
    _saveStatusText = "已儲存";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int charCount = _noteCtrl.text.length;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: AppColors.gooseYellow.withOpacity(0.95), // 品牌鵝黃磨砂背景
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesign.radiusL)),
                  border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: AppDesign.premiumShadow,
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.deepIndigo.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "面試心得筆記",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepIndigo,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _saveStatusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: _saveStatusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _isSavingNote
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        _saveStatusText = "儲存中...";
                                        _isSavingNote = true;
                                      });

                                      final newNote = _noteCtrl.text;
                                      widget.record.note = newNote;
                                      try {
                                        await ApiService.updateRecordNote(widget.record.id, newNote);
                                        setModalState(() {
                                          _saveStatusText = "已儲存";
                                        });
                                      } catch (e) {
                                        setModalState(() {
                                          _saveStatusText = "儲存失敗";
                                        });
                                        print("⚠️ 儲存筆記失敗: $e");
                                      } finally {
                                        setModalState(() {
                                          _isSavingNote = false;
                                        });
                                      }

                                      Future.delayed(const Duration(milliseconds: 800), () {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      });
                                    },
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDesign.radiusM),
                                ),
                              ),
                              child: _isSavingNote
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "儲存",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "記錄下您在此次面試中的發揮、亮點與待改進之處",
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.purpleSurface, // 質感淺紫底色
                          borderRadius: BorderRadius.circular(AppDesign.radiusM),
                          border: Border.all(
                            color: AppColors.primaryPurple.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _noteCtrl,
                          maxLines: null,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.textMain,
                          ),
                          decoration: const InputDecoration(
                            hintText: "在此輸入您的心得、反思或未來改進重點...",
                            hintStyle: TextStyle(color: AppColors.textLightGrey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              if (_saveStatusText != "尚未儲存") {
                                _saveStatusText = "尚未儲存";
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "字數：$charCount 字",
                          style: const TextStyle(
                            color: AppColors.textLightGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kLuminewGooseYellow,
        body: Stack(
          children: [
            // 1. 底層放 TabBarView (全螢幕，讓內容可以滑到 Header 後面被模糊)
            Positioned.fill(
              child: TabBarView(
          children: [
            // Tab 1: AI 分析
            _KeepAliveWrapper(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 150, 20, 20),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "綜合評分",
                      style: TextStyle(
                        color: kLuminewDeepIndigo,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildScoreHeader(),
                  const SizedBox(height: 40), // 大區塊間距
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "核心能力分佈",
                      style: TextStyle(
                        color: kLuminewDeepIndigo,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildRadarChart(),
                  const SizedBox(height: 40), // 大區塊間距
                  if (widget.aiComment != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kLuminewMainPurple.withOpacity(
                          0.20,
                        ), // 稍微降低透明度，讓底色更深一點點
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kLuminewMainPurple.withOpacity(0.50),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology, color: kLuminewDeepIndigo),
                              SizedBox(width: 8),
                              Text(
                                "AI 短評",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kLuminewDeepIndigo,
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
                              Icon(Icons.lightbulb, color: kLuminewDeepIndigo),
                              SizedBox(width: 8),
                              Text(
                                "改進建議",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kLuminewDeepIndigo,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.aiSuggestion ?? "",
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "微表情數據分析",
                      style: TextStyle(
                        color: kLuminewDeepIndigo,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: kLuminewMainPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(
                          "情緒 % 數版",
                          !_isIndexMode,
                          () => setState(() => _isIndexMode = false),
                        ),
                        _buildTabButton(
                          "索引型（次數）",
                          _isIndexMode,
                          () => setState(() => _isIndexMode = true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_isIndexMode) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "情緒平均佔比",
                        style: TextStyle(
                          color: kLuminewDeepIndigo,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPercentageBars(),
                    const SizedBox(height: 30),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "面試影片回放",
                        style: TextStyle(
                          color: kLuminewDeepIndigo,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildVideoPlayerSection(),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "情緒波動曲線",
                        style: TextStyle(
                          color: kLuminewDeepIndigo,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTimelineChart(),
                    if (_isVideoInitialized && _videoController != null)
                      _buildVideoSyncProgress(),
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "主導情緒統計",
                        style: TextStyle(
                          color: kLuminewDeepIndigo,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildIndexCountView(),
                  ],
                  const SizedBox(height: 40),
                  // ★ 並排按鈕：寄信（左，外框）& 回首頁（右，實心）
                  Row(
                    children: [
                      // 左：寄給我（外框透明）
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kLuminewMainPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(color: kLuminewMainPurple, width: 1.5),
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: _isSendingEmail ? null : _sendEmailManually,
                          icon: _isSendingEmail
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: kLuminewMainPurple),
                                )
                              : const Icon(Icons.email_outlined, size: 18),
                          label: Text(
                            _isSendingEmail ? "寄送中..." : "寄給我",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 右：回首頁（實心紫色）
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLuminewMainPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            try {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).popUntil((route) => route.isFirst);
                            } catch (_) {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => StudentMainScaffold(
                                    user: widget.user,
                                    onLogout: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AuthScreen(onAuthSuccess: (user) {}),
                                        ),
                                        (route) => false,
                                      );
                                    },
                                  ),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.home_outlined, size: 18),
                          label: const Text(
                            '回首頁',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tab 2: 面試問題 (已隱藏)
            /*
            _KeepAliveWrapper(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 146, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color.fromARGB(255, 30, 156, 144),
                            Colors.teal.shade400,
                          ],
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
                    if (widget.record.questions.isEmpty)
                      const Center(child: Text("此次面試未記錄問題"))
                    else
                      ...widget.record.questions.asMap().entries.map(
                        (entry) => ListTile(
                          leading: Text("${entry.key + 1}"),
                          title: Text(entry.value),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            */
            // Tab 3: 評語討論 (聊天室模式)
            _KeepAliveWrapper(
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (widget.user.role != 'Teacher' && widget.record.privacy == 'Teacher' && _studentTeachers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 140, 20, 0),
                            child: DropdownButtonFormField<int>(
                              value: _selectedTeacherChannelId,
                              decoration: InputDecoration(
                                labelText: '選擇老師頻道',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              items: _studentTeachers.map((t) {
                                return DropdownMenuItem<int>(
                                  value: int.tryParse(t.id),
                                  child: Text(t.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedTeacherChannelId = val;
                                });
                                _loadComments();
                              },
                            ),
                          ),
                        Expanded(
                          child: _comments.isEmpty
                              ? const Center(child: Text("尚無評語討論"))
                              : ListView.builder(
                                  padding: EdgeInsets.fromLTRB(20, (widget.user.role != 'Teacher' && widget.record.privacy == 'Teacher' && _studentTeachers.isNotEmpty) ? 20 : 150, 20, 20),
                            itemCount: _comments.length,
                            itemBuilder: (ctx, i) {
                              final comment = _comments[i];
                              bool isMe =
                                  comment.senderName == widget.user.name;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      CircleAvatar(
                                        backgroundColor: kLuminewGooseYellow,
                                        child: Text(
                                          comment.senderName[0],
                                          style: const TextStyle(
                                            color: kLuminewDeepIndigo,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? kLuminewMainPurple
                                              : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: Radius.circular(
                                              isMe ? 16 : 0,
                                            ),
                                            bottomRight: Radius.circular(
                                              isMe ? 0 : 16,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Text(
                                                  comment.senderName,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              comment.content,
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : kLuminewDeepIndigo,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isMe)
                                      CircleAvatar(
                                        backgroundColor: kLuminewMainPurple
                                            .withOpacity(0.2),
                                        child: const Icon(
                                          Icons.person,
                                          color: kLuminewMainPurple,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      8 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: kLuminewMainPurple,
                      boxShadow: [
                        BoxShadow(
                          color: kLuminewDeepIndigo.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            decoration: InputDecoration(
                              hintText: '輸入留言...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: kLuminewGooseYellow,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tab 4: 詳情
            _KeepAliveWrapper(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 146, 16, 16),
                child: Column(
                  children: [
                    _buildDetailCard(
                      Icons.history_edu,
                      '問題類型',
                      widget.record.type,
                    ),
                    _buildDetailCard(
                      Icons.person,
                      '面試官',
                      widget.record.interviewer,
                    ),
                    _buildDetailCard(
                      Icons.language,
                      '語言',
                      widget.record.language,
                    ),
                    _buildDetailCard(
                      Icons.timer,
                      '時長',
                      '${widget.record.durationSec} 秒',
                    ),
                    const Divider(height: 32),
                    if (widget.user.id == widget.record.studentId ||
                        widget.user.email == widget.record.studentId) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "隱私設定",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kLuminewDeepIndigo,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kLuminewMainPurple,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.record.privacy,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: kLuminewMainPurple,
                            ),
                            dropdownColor: kLuminewGooseYellow,
                            style: const TextStyle(
                              color: kLuminewDeepIndigo,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            items: ['Private', 'Teacher']
                                .map(
                                  (mode) => DropdownMenuItem(
                                    value: mode,
                                    child: Text(
                                      mode == 'Private'
                                          ? '私人（僅自己可見）'
                                          : '老師可見',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _updatePrivacy,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.movie_creation_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const Text("影片雲端處理中", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
            // 2. 頂層放毛玻璃 Positioned Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: AppColors.headerPurpleGlass,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LuminewHeader(
                            title: "面試結果",
                            showBackButton: true,
                            usePositioned: false,
                            showBottomBorder: false,
                            showOwnBackground: false,
                            textColor: Colors.white,
                            actions: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => _showNoteSheet(context),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          const TabBar(
                            isScrollable: false, // 改為不可捲動，平均分配分佈
                            indicatorColor: Colors.white,
                            indicatorWeight: 4,
                            indicatorSize: TabBarIndicatorSize.label,
                            indicatorPadding: EdgeInsets.symmetric(horizontal: 8),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white70,
                            tabs: [
                              Tab(text: 'AI 分析'),
                              // Tab(text: '面試問題'),
                              Tab(text: '評語討論'),
                              Tab(text: '詳細內容'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: kLuminewMainPurple, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kLuminewDeepIndigo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      int c = ((p['c'] ?? p['confidence'] ?? 0) as num).toInt();
      int pp = ((p['p'] ?? p['passion'] ?? 0) as num).toInt();
      int n = ((p['n'] ?? p['nervous'] ?? 0) as num).toInt();
      int r = ((p['r'] ?? p['relaxed'] ?? 0) as num).toInt();
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLuminewMainPurple, width: 1.5),
        // boxShadow: [
        //   BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        // ],
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
            value: (score / 100).clamp(0.0, 1.0),
            color: color,
            backgroundColor: kLuminewGooseYellow,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? kLuminewMainPurple.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? kLuminewMainPurple : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? kLuminewDeepIndigo : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
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
    if (maxSec <= 0) maxSec = 1.0; // 避免除以 0
    double curSec = _videoPosition.inMilliseconds / 1000.0;
    double progress = (curSec / maxSec).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            color: kLuminewDeepIndigo,
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
                  color: kLuminewDeepIndigo,
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

    double maxSec = ((timeline.last['t'] ?? 1.0) as num).toDouble();
    if (maxSec <= 0) maxSec = 1.0; // 避免 max >= min 的 FlChart 崩潰

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20, right: 10),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxSec,
          minY: 0,
          maxY: 105, // 允許 100 以上的浮點誤差防崩潰
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
    // 支援舊版長 key 對應
    final Map<String, String> longKeys = {
      'c': 'confidence',
      'p': 'passion',
      'n': 'nervous',
      'r': 'relaxed',
    };
    final String longKey = longKeys[key] ?? key;

    return LineChartBarData(
      spots: data
          .map(
            (e) => FlSpot(
              ((e['t'] ?? 0) as num).toDouble(),
              ((e[key] ?? e[longKey] ?? 0) as num).toDouble(),
            ),
          )
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildScoreHeader() {
    final score = widget.record.overallScore;
    final scoreColor = _getScoreGradient(score).last;

    return Container(
      clipBehavior: Clip.antiAlias, // ★ 加入裁切避免內部背景擋住導角
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kLuminewMainPurple.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLuminewMainPurple.withOpacity(0.50)),
      ),
      child: Row(
        children: [
          // 左側圓環 (3px 線條)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  strokeWidth: 12, // 再雙倍粗
                  strokeCap: StrokeCap.round, // 圓頭
                  color: kLuminewMainPurple,
                  backgroundColor: kLuminewGooseYellow.withOpacity(0.3),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$score",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  const Text(
                    "綜合評分",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          // 右側描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 90
                      ? "頂尖表現"
                      : score >= 75
                      ? "表現優異"
                      : score >= 60
                      ? "表現穩健"
                      : "尚有進步空間",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  score >= 90
                      ? "您在所有維度上都展現了極高的專業度，尤其是情緒穩定性令人印象深刻。"
                      : score >= 60
                      ? "整體表現平穩，但在某些細節（如切題率或熱忱度）仍有優化空間。"
                      : "建議針對 AI 提供的改進建議進行專項練習，提升面試自信心。",
                  style: const TextStyle(
                    fontSize: 13,
                    color: kLuminewDeepIndigo,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart() {
    final double emotionManagement =
        (widget.record.scores['emotion_management'] ?? 0).toDouble();
    final double relevance = (widget.record.scores['relevance'] ?? 0)
        .toDouble();
    final double confidence = (widget.record.scores['confidence'] ?? 0)
        .toDouble();
    final double passion = (widget.record.scores['passion'] ?? 0).toDouble();
    final double relaxed = (widget.record.scores['relaxed'] ?? 0).toDouble();

    final List<double> rawScores = [
      emotionManagement,
      relevance,
      confidence,
      passion,
      relaxed,
    ];

    double maxRaw = 0.1; // 防止除以 0
    for (double s in rawScores) {
      if (s > maxRaw) maxRaw = s;
    }

    // 自動等比例放大：讓最高分的那一項永遠落在最大佔比(第4.5圈=90分)，達成完美比例
    final double visualScale = 90.0 / maxRaw;


    return Container(
      height: 380,
      width: double.infinity,
      clipBehavior: Clip.antiAlias, // ★ 加入裁切避免內部背景擋住導角
      margin: EdgeInsets.zero, // ★ 移除 Margin，由外層 Padding 統一控制
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kLuminewMainPurple.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLuminewMainPurple.withOpacity(0.50)),
      ),
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon, // ★ 改為圓形網格，實現極致圓潤
          radarBorderData: BorderSide(color: Colors.grey.withOpacity(0.7), width: 2.0),
          titlePositionPercentageOffset: 0.1,
          titleTextStyle: const TextStyle(
            color: kLuminewDeepIndigo,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          getTitle: (index, angle) {
            // ... (keep case structure)
            switch (index) {
              case 0:
                return RadarChartTitle(text: '表情管理');
              case 1:
                return RadarChartTitle(text: '切題率');
              case 2:
                return RadarChartTitle(text: '自信度');
              case 3:
                return RadarChartTitle(text: '熱忱度');
              case 4:
                return RadarChartTitle(text: '沈穩度');
              default:
                return const RadarChartTitle(text: '');
            }
          },
          tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          tickBorderData: BorderSide(
            color: Colors.grey.withOpacity(0.7), // ★ 這裡就是那一圈圈的顏色
            width: 2.0,
          ),
          gridBorderData: const BorderSide(color: Colors.transparent),
          dataSets: [
            // ★ 回歸 100 分防守牆
            RadarDataSet(
              fillColor: Colors.transparent,
              borderColor: Colors.transparent,
              borderWidth: 0,
              entryRadius: 0,
              dataEntries: const [
                RadarEntry(value: 100),
                RadarEntry(value: 100),
                RadarEntry(value: 100),
                RadarEntry(value: 100),
                RadarEntry(value: 100),
              ],
            ),
            RadarDataSet(
              fillColor: kLuminewMainPurple.withOpacity(0.15), // 極淺紫色填充
              borderColor: kLuminewMainPurple, // 紫色邊框強化
              borderWidth: 2.5,
              entryRadius: 2,
              dataEntries: [
                RadarEntry(value: (emotionManagement * visualScale).clamp(0.0, 100.0)),
                RadarEntry(value: (relevance * visualScale).clamp(0.0, 100.0)),
                RadarEntry(value: (confidence * visualScale).clamp(0.0, 100.0)),
                RadarEntry(value: (passion * visualScale).clamp(0.0, 100.0)),
                RadarEntry(value: (relaxed * visualScale).clamp(0.0, 100.0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerSection() {
    final String? url = widget.videoUrl ?? widget.record.videoUrl;
    final videoFile = (url != null && url.isNotEmpty && !url.startsWith("http") && !url.startsWith("blob:"))
        ? File(url)
        : null;
    final bool hasLocalVideo = videoFile != null && videoFile.existsSync();

    if (_isVideoInitialized && _videoController != null) {
      return Column(
        children: [
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kLuminewDeepIndigo.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(3.14159), // 鏡像修正
                    child: VideoPlayer(_videoController!),
                  ),
                ),
                VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: kLuminewDeepIndigo,
                    bufferedColor: Colors.white24,
                    backgroundColor: kLuminewMainPurple,
                  ),
                ),
                Container(
                  height: 48,
                  color: kLuminewMainPurple,
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
          ),
        ],
      );
    } else if (url != null && url.isNotEmpty) {
      if (_videoLoadFailed) {
        return hasLocalVideo
            ? _buildVideoPlaceholder(Icons.videocam_off, '影片載入失敗')
            : _buildVideoPlaceholder(
                Icons.history_toggle_off_rounded,
                '影像已歸檔或移除',
              );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } else {
      return _buildVideoPlaceholder(Icons.videocam_off, '未記錄影片');
    }
  }

  Widget _buildVideoPlaceholder(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: kLuminewGooseYellow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(kRadiusM),
        border: Border.all(color: kLuminewMainPurple.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ============================================================
// ★ 狀態保持包裝器 (V17 強制修正)
// 解決 TabBarView 切換後頁面變空的 Bug
// ============================================================
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  __KeepAliveWrapperState createState() => __KeepAliveWrapperState();
}

class __KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必須調用
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true; // 永遠保持存活
}

// ==========================================
// ★ 新增功能：寄信小工具 (Email Result Widget)
// ==========================================
class _EmailResultWidget extends StatefulWidget {
  final InterviewRecord record;
  final String studentName;
  const _EmailResultWidget({Key? key, required this.record, required this.studentName}) : super(key: key);

  @override
  State<_EmailResultWidget> createState() => _EmailResultWidgetState();
}

class _EmailResultWidgetState extends State<_EmailResultWidget> {
  final _emailCtrl = TextEditingController();
  bool _isSending = false;

  void _sendEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入有效的信箱格式')),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      await ApiService.sendInterviewResultEmail(
        recipientEmail: email,
        studentName: widget.studentName,
        overallScore: widget.record.overallScore,
        comment: widget.record.aiComment.isNotEmpty ? widget.record.aiComment : '尚無評語',
        suggestion: widget.record.aiSuggestion.isNotEmpty ? widget.record.aiSuggestion : '尚無建議',
        timelineText: "(詳細情緒波動數據請回 Luminew 平台查看)",
      );
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('✅ 寄送成功！請去信箱確認', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
         );
         _emailCtrl.clear();
      }
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('寄信失敗：$e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
         );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("📨 寄送成績與分析報表至信箱", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kLuminewDeepIndigo)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kLuminewMainPurple, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: kLuminewMainPurple),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    hintText: '輸入你的電子信箱',
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              if (_isSending) 
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLuminewMainPurple)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: kLuminewMainPurple),
                  onPressed: _sendEmail,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MicSpectrumPainter extends CustomPainter {
  final double amplitude;
  final double animationValue;
  final bool isActive;

  _MicSpectrumPainter({
    required this.amplitude,
    required this.animationValue,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = 52.0;
    final maxBarHeight = 35.0;
    
    final count = 60;
    final angleStep = (2 * math.pi) / count;

    for (int i = 0; i < count; i++) {
      final angle = i * angleStep;
      
      // 根據 index 與動畫值產生一點隨機跳動感，讓它看起來更像頻譜而非單純同步縮放
      double noise = math.sin(animationValue * 10 + i * 0.5).abs();
      double barHeight = 2 + (amplitude * maxBarHeight * (0.4 + 0.6 * noise));
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5
        ..color = kLuminewMainPurple.withOpacity((0.2 + 0.8 * amplitude).clamp(0.2, 1.0));

      final pStart = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final pEnd = Offset(
        center.dx + math.cos(angle) * (innerRadius + barHeight),
        center.dy + math.sin(angle) * (innerRadius + barHeight),
      );

      canvas.drawLine(pStart, pEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MicSpectrumPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude || oldDelegate.animationValue != animationValue;
  }
}
