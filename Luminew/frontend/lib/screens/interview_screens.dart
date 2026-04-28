// fileName: lib/screens/interview_screens.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // ★ 新增：支援磨砂濾鏡效果
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
import '../widgets/luminew_header.dart'; // 導入統一標頭
import 'student_screens.dart';
import 'auth_screen.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  questions: _type == '學習歷程' ? _generatedQuestions : null,
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

        // ★ 移除重複長延時：後端已經預留 1.8 秒熱機時間，前端只需極短延遲亮燈
        Timer(const Duration(milliseconds: 50), () {
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

    print(
      '🎙️ [Interview] 開始建立與 D-ID 的 WebRTC 連線 (教授: ${widget.interviewer})...',
    );
    await _didService.startInterview(widget.interviewer, widget.type, customQuestions: widget.questions);
    if (mounted)
      setState(() {
        _isInterviewing = true;
        _isWsConnecting = false;
      });
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

        // 在 Web 上，initialize 會觸發瀏覽器權限詢問
        await _controller!.initialize();
        if (mounted) setState(() {});
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: kLuminewMainPurple.withOpacity(0.95),
                        width: 2,
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
                                            isStudent ? "我：" : "教授：",
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

                // 3. 底部區域量體優化 (移除冗餘問題顯示，留待結束分析後查看)
                const SizedBox(height: 24),

                // 3. 底部控制按鈕
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: kLuminewMainPurple),
                        SizedBox(height: 12),
                        Text(
                          "AI 正在進行深度情緒分析",
                          style: TextStyle(
                            color: kLuminewMainPurple,
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
                        const SizedBox(height: 10),
                        Text(
                          _isWaitingProfessor
                              ? "教授思考中..."
                              : (_isInterviewing
                                    ? (_canStudentSpeak ? "點擊結束個人發言" : "延遲收音中")
                                    : "開始面試對答"),
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

          // 4. 右上角面試者 PIP (移除外框樣式)
          Positioned(
            top: 50,
            right: 20,
            width: 110,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
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
      } else if (url.startsWith('blob:') || kIsWeb) {
        // ★ Web 的 XFile.path 回傳 blob URL，一樣用 networkUrl 播放
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

  void _showNoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "面試心得筆記",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kLuminewDeepIndigo,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: kLuminewMainPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "記錄下您的亮點與需要改進的地方",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Expanded(
                child: TextField(
                  maxLines: null,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "在這裡寫下您的想法...",
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 16, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: kLuminewGooseYellow,
        appBar: AppBar(
          backgroundColor: kLuminewMainPurple,
          elevation: 0,
          leading: Container(
            alignment: Alignment.center,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: const Text(
            '面試結果',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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
          bottom: TabBar(
            isScrollable: false, // 改為不可捲動，平均分配分佈
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'AI 分析'),
              Tab(text: '面試問題'),
              Tab(text: '評語討論'),
              Tab(text: '詳細內容'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: AI 分析
            _KeepAliveWrapper(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(20),
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
                            widget.aiSuggestion!,
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
                  _EmailResultWidget(
                    record: widget.record,
                    studentName: widget.user.name,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        // 終極修復方案：先嘗試 pop 到最底層，若不行則強制 pushReplacement
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
                      icon: const Icon(
                        Icons.home_outlined,
                        color: kLuminewMainPurple,
                      ),
                      label: const Text(
                        '回到首頁',
                        style: TextStyle(
                          color: kLuminewMainPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: kLuminewMainPurple.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: kLuminewMainPurple.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab 2: 面試問題
            _KeepAliveWrapper(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
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
            // Tab 3: 評語討論 (聊天室模式)
            _KeepAliveWrapper(
              child: Column(
                children: [
                  Expanded(
                    child: _comments.isEmpty
                        ? const Center(child: Text("尚無評語討論"))
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
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
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      8 + MediaQuery.of(context).viewInsets.bottom,
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
                padding: const EdgeInsets.all(16),
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
                            items: ['Private', 'Class', 'Platform']
                                .map(
                                  (mode) => DropdownMenuItem(
                                    value: mode,
                                    child: Text(
                                      mode == 'Private'
                                          ? '私人（僅自己可見）'
                                          : (mode == 'Class'
                                                ? '班級（老師與同學可見）'
                                                : '平台（公開）'),
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

    double maxSec = (timeline.last['t'] as num).toDouble();
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
          radarBorderData: const BorderSide(color: Colors.transparent),
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
    final videoFile = widget.record.videoUrl!.isNotEmpty
        ? File(widget.record.videoUrl!)
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
    } else if (widget.record.videoUrl!.isNotEmpty && hasLocalVideo) {
      return _videoLoadFailed
          ? _buildVideoPlaceholder(Icons.videocam_off, '影片載入失敗')
          : const Center(child: CircularProgressIndicator());
    } else if (widget.record.videoUrl!.isNotEmpty && !hasLocalVideo) {
      return _buildVideoPlaceholder(
        Icons.history_toggle_off_rounded,
        '影像已歸檔或移除',
      );
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
