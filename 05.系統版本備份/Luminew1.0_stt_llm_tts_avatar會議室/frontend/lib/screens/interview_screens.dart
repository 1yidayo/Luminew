// fileName: lib/screens/interview_screens.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import '../mock_data.dart';
import '../sql_service.dart';


// 全域變數：用來儲存可用的相機列表
List<CameraDescription> cameras = [];

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
      appBar: AppBar(title: const Text('面試紀錄')),
      body: FutureBuilder<List<InterviewRecord>>(
        // 從 SQL 資料庫讀取資料
        future: SqlService.getRecords(widget.user.id, 'All'),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ★ 修改：如果有錯誤，直接顯示錯誤並提供重試，而不是偷偷換假資料
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "無法連線到資料庫",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // 重新觸發 build -> 重新執行 future
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("重試連線"),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return const Center(child: Text('尚無紀錄'));
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (ctx, i) {
              final r = records[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: r.overallScore < 61
                            ? [Colors.red.shade700, Colors.redAccent]
                            : r.overallScore <= 80
                                ? [Colors.green.shade700, Colors.greenAccent]
                                : [Colors.indigo, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "${r.overallScore}",
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // ★ 改成顯示自訂面試名稱
                  title: Text(
                    r.interviewName.isNotEmpty ? r.interviewName : '${r.type} (${r.language})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // ★ 顯示日期時間
                  subtitle: Text(
                    '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')} ${r.date.hour.toString().padLeft(2, '0')}:${r.date.minute.toString().padLeft(2, '0')} | ${r.interviewer}',
                  ),
                  // ★ 修改：trailing 改成 Row（刪除按鈕 + 箭頭）
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          // 顯示確認對話框
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('確認刪除'),
                              content: const Text('確定要刪除這筆面試紀錄嗎？此操作無法復原。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('刪除', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await SqlService.deleteRecord(r.id);
                            setState(() {}); // 刷新列表
                          }
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      // 點擊後進入詳細結果頁 (包含留言功能)
                      builder: (_) =>
                          InterviewResultScreen(record: r, user: widget.user,aiComment: r.aiComment,
                        aiSuggestion: r.aiSuggestion),
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
  
  // 檔案上傳相關
  File? _selectedFile;
  String? _selectedFileName;
  List<String> _generatedQuestions = [];
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
      
      request.files.add(await http.MultipartFile.fromPath('pdf', _selectedFile!.path));
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
            // ★ 修正：確保每個元素都轉成 String
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題生成失敗: $e')),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面試設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "請選擇面試偏好",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ★ 0. 面試名稱（必填）
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '面試名稱',
                  hintText: '例如：輔大資管系面試練習',
                  border: const OutlineInputBorder(),
                  errorText: _nameError,
                  suffixIcon: const Icon(Icons.edit, color: Colors.grey),
                ),
                onChanged: (v) {
                  if (_nameError != null && v.isNotEmpty) {
                    setState(() => _nameError = null);
                  }
                },
              ),
            ),

            // 1. 面試類型
            _buildDropdown('面試類型', [
              '通用型',
              '科系專業',
              '學經歷',
            ], (v) => setState(() => _type = v!)),

            // 2. 面試官
            _buildDropdown('面試官', [
              '保羅',
              '林湘霖',
              '藍易振',
              'AI 面試官',
            ], (v) => setState(() => _interviewer = v!)),

            // 3. 語言
            _buildDropdown('語言', [
              '中文',
              '英文',
            ], (v) => setState(() => _lang = v!)),

            // 4. 儲存設定
            SwitchListTile(
              title: const Text('儲存錄影'),
              value: _saveVideo,
              onChanged: (v) => setState(() => _saveVideo = v),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ★ 5. 檔案上傳區塊
            const Text(
              "上傳學習歷程（選填）",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "AI 將根據您的學習歷程生成個人化面試問題",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            
            // 檔案選擇按鈕
            OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _pickFile,
              icon: Icon(_selectedFile == null ? Icons.upload_file : Icons.check_circle),
              label: Text(_selectedFile == null 
                ? '選擇 PDF 檔案' 
                : _selectedFileName ?? '已選擇檔案'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: BorderSide(
                  color: _selectedFile == null ? Colors.grey : Colors.green,
                ),
              ),
            ),
            
            // 分析中指示器
            if (_isAnalyzing) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('AI 正在分析您的學習歷程...'),
                ],
              ),
            ],
            
            // 顯示生成的問題數量
            if (_generatedQuestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '已生成 ${_generatedQuestions.length} 個個人化問題',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 開始面試按鈕
            ElevatedButton(
              onPressed: _isAnalyzing ? null : () {
                // ★ 驗證面試名稱必填
                if (_nameController.text.trim().isEmpty) {
                  setState(() => _nameError = '該欄位必填');
                  return;
                }
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MockInterviewScreen(
                      user: widget.user,
                      type: _type,
                      interviewer: _interviewer,
                      language: _lang,
                      saveVideo: _saveVideo,
                      questions: _generatedQuestions.isNotEmpty ? _generatedQuestions : null,
                      interviewName: _nameController.text.trim(), // ★ 新增
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                '開始面試',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // 下拉選單 UI 封裝
  Widget _buildDropdown(
    String label,
    List<String> items,
    Function(String?) onChange,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField(
        initialValue: items[0],
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChange,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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
  final String interviewName; // ★ 新增：面試名稱

  const MockInterviewScreen({
    super.key,
    required this.user,
    required this.type,
    required this.interviewer,
    required this.language,
    required this.saveVideo,
    required this.interviewName, // ★ 新增
    this.questions,
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

  @override
  void initState() {
    super.initState();
    _initCamera();
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

        _controller = CameraController(frontCam, ResolutionPreset.low);
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
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _sec = 0;
      });

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
      });
    }

    try {
      // ★★★ IP 設定：請確認這裡改成您電腦的 IP ★★★
      final apiUrl = 'http://10.0.2.2:8000/emotion/analyze';
      print("★★★ 準備上傳影片到: $apiUrl ★★★");
      print("★★★ 影片路徑: ${file.path} ★★★");
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      request.files.add(await http.MultipartFile.fromPath('video', file.path));
      // ★ 新增：傳送「是否儲存影片」的設定給後端
      request.fields['save_video'] = widget.saveVideo ? 'true' : 'false';

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
        final data = jsonDecode(response.body);
        final emotions = data['emotions'];
        final ai = data['ai_analysis'];
        final timelineList = data['timeline'] ?? [];

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
          videoUrl: data['video_url'],
          questions: widget.questions ?? [],
          interviewName: widget.interviewName, // ★ 新增：面試名稱
        );

        // 1. 存入 Mock (即時顯示用)
        mockService.addRecord(r);

        // 2. ★存入 SQL 資料庫★
        try {
          await SqlService.saveRecord(r);
          print("✅ 資料庫儲存成功！");
        } catch (dbError) {
          print("❌ 資料庫儲存失敗: $dbError");
        }

        if (mounted) {
          // 跳轉到結果頁，並使用 popUntil 讓它可以回到首頁
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => InterviewResultScreen(
                record: r,
                user: widget.user,
                aiComment: ai['comment'],
                aiSuggestion: ai['suggestion'],
                videoUrl: data['video_url'], // ★ 新增：傳入影片網址
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
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 相機預覽
          SizedBox.expand(child: CameraPreview(_controller!)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "面試官: ${widget.interviewer}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${(_sec ~/ 60).toString().padLeft(2, '0')}:${(_sec % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 10),
                        Text(
                          "AI 正在分析您的表情...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isRecording
                              ? _stopAndAnalyze
                              : _startRecording,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.transparent,
                            ),
                            child: _isRecording
                                ? const Icon(
                                    Icons.stop,
                                    color: Colors.white,
                                    size: 40,
                                  )
                                : const Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                // ★ 新增：顯示個人化問題
                if (widget.questions != null && widget.questions!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.question_answer, color: Colors.amber, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '個人化面試問題',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...widget.questions!.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${entry.key + 1}. ${entry.value}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
              ],
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
  VideoPlayerController? _videoController; // ★ 新增控制器
  bool _isVideoInitialized = false;
  Duration _videoPosition = Duration.zero; // ★ 追蹤影片當前播放位置

  bool _isIndexMode = false;

  // ★★★ 新增這個函式：用來判斷分數顏色 ★★★
  List<Color> _getScoreGradient(int score) {
    if (score < 61) {
      // 60分(含)以下：紅色 (警示)
      return [Colors.red.shade700, Colors.redAccent];
    } else if (score <= 80) {
      // 61-80分：綠色 (及格/良好)
      return [Colors.green.shade700, Colors.greenAccent];
    } else {
      // 81分(含)以上：藍色 (優秀)
      return [Colors.indigo, Colors.blueAccent];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
    _initVideo(); // ★ 初始化影片
  }

  @override
  void dispose() {
    _videoController?.dispose(); // ★ 釋放資源
    _commentCtrl.dispose();
    super.dispose();
  }

  // 初始化影片播放器
  bool _videoLoadFailed = false; // ★ 新增：記錄影片是否載入失敗
  
  Future<void> _initVideo() async {
    // 優先使用傳入的 videoUrl (如果是剛錄完)，其次使用 record.videoUrl (如果是從歷史紀錄進來)
    String? url = widget.videoUrl ?? widget.record.videoUrl;
    
    print("🎬 [DEBUG] widget.videoUrl = ${widget.videoUrl}");
    print("🎬 [DEBUG] widget.record.videoUrl = ${widget.record.videoUrl}");
    print("🎬 [DEBUG] 最終使用的 URL = $url");
    
    if (url != null && url.isNotEmpty && url != 'null') {
      print("🎬 嘗試載入影片: $url");
      
      if (url.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _videoController = VideoPlayerController.file(File(url));
      }

      try {
        print("🎬 開始初始化影片播放器...");
        await _videoController!.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('影片載入逾時 (超過15秒)');
          },
        );
        print("✅ 影片初始化成功！");
        
        // ★ 加入監聽器：追蹤影片播放位置
        _videoController!.addListener(() {
          if (mounted && _videoController != null) {
            setState(() {
              _videoPosition = _videoController!.value.position;
            });
          }
        });
        
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      } catch (e) {
        print("❌ 影片載入失敗: $e");
        print("   影片網址: $url");
        if (mounted) {
          setState(() {
            _videoLoadFailed = true;
          });
        }
      }
    } else {
      print("🎬 [DEBUG] 無影片 URL，不載入影片");
    }
  }

  // 讀取留言 (從 SQL)
  void _loadComments() async {
    try {
      var c = await SqlService.getComments(widget.record.id);
      if (mounted) setState(() => _comments = c);
    } catch (e) {
      print("留言讀取失敗 (可能是 ID 不對或 DB 沒資料): $e");
    }
  }

  // 發送留言
  void _send() async {
    if (_commentCtrl.text.isEmpty) return;
    try {
      await SqlService.sendComment(
        widget.record.id,
        widget.user.email,  // ★ 修正：要傳 email，不是 id
        _commentCtrl.text,
      );
      _commentCtrl.clear();
      _loadComments(); // 重新讀取
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("留言失敗: $e")));
    }
  }

  // 更新隱私權
  void _updatePrivacy(String? v) async {
    if (v == null) return;
    try {
      await SqlService.updatePrivacy(widget.record.id, v);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("已改為 $v")));
    } catch (e) {
      print("更新失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ★★★ 新增這段：定義資料並由高到低排序 ★★★
    final statList = [
      {'label': "自信 (Confidence)", 'score': widget.record.scores['confidence'] ?? 0, 'color': Colors.blue},
      {'label': "熱忱 (Passion)", 'score': widget.record.scores['passion'] ?? 0, 'color': Colors.red},
      {'label': "緊張 (Nervous)", 'score': widget.record.scores['nervous'] ?? 0, 'color': Colors.orange},
      {'label': "沈穩 (Relaxed)", 'score': widget.record.scores['relaxed'] ?? 0, 'color': Colors.green},
    ];
    // 從大排到小
    statList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return DefaultTabController(
      length: 4, // ★ 改為 4 個 Tab
      child: Scaffold(
        appBar: AppBar(
          title: const Text('面試結果'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'AI 分析'), // Tab 1: AI 分析報告
              Tab(text: '面試問題'), // ★ 新增 Tab 2: 面試問題
              Tab(text: '評語討論'), // Tab 3: 留言板功能
              Tab(text: '詳細設定'), // Tab 4: 隱私設定與回放
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
                          color: _getScoreGradient(widget.record.overallScore).last.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
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
                          widget.record.overallScore >= 90 ? '表現完美！' :
                          widget.record.overallScore >= 61 ? '表現不錯！' : '加油，再接再厲',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      child: Text("情緒平均佔比", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    _buildPercentageBars(), // 呼叫長條圖
                    
                    const SizedBox(height: 30),
                    
                    // ==========================================
                    // ★ 面試影片區塊 ★
                    // ==========================================
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("面試影片回放", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    if (_isVideoInitialized && _videoController != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 10)
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 9 / 16, // ★ 固定 4:3 比例
                              child: VideoPlayer(_videoController!),
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
                                      _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
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
                    else if (widget.record.videoUrl != null && widget.record.videoUrl != 'null')
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
                                  Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('影片載入失敗', style: TextStyle(color: Colors.grey)),
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
                            Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('未儲存影片', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('可在面試設定中開啟「儲存錄影」功能', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("情緒波動曲線", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      child: Text("主導情緒統計 (Winner Takes All)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            Icon(Icons.info_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              '此次面試未記錄問題',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            Text(
                              '上傳學習歷程 PDF 可生成個人化問題',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
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
                        Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
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

  Widget _buildStatRow(String label, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                "$score%",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: score / 100,
            color: color,
            backgroundColor: Colors.grey[200],
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }
  // 1. 切換按鈕樣式
  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 2. 長條圖
  Widget _buildPercentageBars() {
    final statList = [
      {'label': "自信", 'score': widget.record.scores['confidence'] ?? 0, 'color': Colors.blue},
      {'label': "熱忱", 'score': widget.record.scores['passion'] ?? 0, 'color': Colors.red},
      {'label': "緊張", 'score': widget.record.scores['nervous'] ?? 0, 'color': Colors.orange},
      {'label': "沈穩", 'score': widget.record.scores['relaxed'] ?? 0, 'color': Colors.green},
    ];
    statList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return Column(
      children: statList.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text("${item['score']}%", style: TextStyle(color: item['color'] as Color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: (item['score'] as int) / 100,
              color: item['color'] as Color,
              backgroundColor: Colors.grey[200],
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // 3. 索引型統計
  Widget _buildIndexCountView() {
    List<dynamic> timeline = [];
    try {
      timeline = jsonDecode(widget.record.timelineData);
    } catch (e) {
      return const Text("無詳細數據");
    }

    if (timeline.isEmpty) return const Text("數據不足");

    Map<String, int> counts = {'c': 0, 'p': 0, 'n': 0, 'r': 0};
    int total = timeline.length;

    for (var point in timeline) {
      int c = point['c'];
      int p = point['p'];
      int n = point['n'];
      int r = point['r'];
      
      int maxVal = [c, p, n, r].reduce((curr, next) => curr > next ? curr : next);
      
      if (c == maxVal) counts['c'] = counts['c']! + 1;
      else if (p == maxVal) counts['p'] = counts['p']! + 1;
      else if (n == maxVal) counts['n'] = counts['n']! + 1;
      else if (r == maxVal) counts['r'] = counts['r']! + 1;
    }

    return Column(
      children: [
        _buildCountRow("自信 (Confidence)", counts['c']!, total, Colors.blue),
        _buildCountRow("熱忱 (Passion)", counts['p']!, total, Colors.red),
        _buildCountRow("緊張 (Nervous)", counts['n']!, total, Colors.orange),
        _buildCountRow("沈穩 (Relaxed)", counts['r']!, total, Colors.green),
      ],
    );
  }

  Widget _buildCountRow(String label, int count, int total, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
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
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("主導了 $count 秒", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(
            "${count}s", 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ★★★ 新增：影片同步進度條 ★★★
  Widget _buildVideoSyncProgress() {
    // 取得時間軸最大秒數
    double maxSeconds = 10;
    try {
      String rawData = widget.record.timelineData ?? '';
      if (rawData.isNotEmpty) {
        List<dynamic> timeline;
        try {
          timeline = jsonDecode(rawData);
        } catch (_) {
          String cleanJson = rawData.replaceAll("'", '"');
          if (!cleanJson.startsWith('[')) cleanJson = '[$cleanJson]';
          timeline = jsonDecode(cleanJson);
        }
        if (timeline.isNotEmpty) {
          maxSeconds = (timeline.last['t'] as num).toDouble();
        }
      }
    } catch (_) {}
    
    if (maxSeconds == 0) maxSeconds = 10;
    
    // 計算當前進度比例
    double currentSeconds = _videoPosition.inMilliseconds / 1000.0;
    double progress = (currentSeconds / maxSeconds).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.only(left: 40, right: 24), // 對齊曲線圖
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 進度條
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 背景條
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 已播放進度
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // 當前位置指示器
              Positioned(
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(width: (MediaQuery.of(context).size.width - 64) * progress - 8),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 時間顯示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentSeconds.toStringAsFixed(1)} 秒',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.play_circle_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '影片同步進度',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
              Text(
                '${maxSeconds.toStringAsFixed(1)} 秒',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // fileName: lib/screens/interview_screens.dart

  // ==========================================
  // 1. 這是上面的函式：_buildTimelineChart (負責畫圖框)
  // ==========================================
  Widget _buildTimelineChart() {
    List<dynamic> timeline = [];
    try {
      String rawData = widget.record.timelineData;
      print("📊 解析 TimelineData: ${rawData.length > 100 ? rawData.substring(0, 100) + '...' : rawData}");
      
      // 嘗試直接解析 (原始 JSON 格式)
      try {
        timeline = jsonDecode(rawData);
      } catch (_) {
        // 如果失敗，嘗試把單引號換成雙引號 (舊格式相容)
        String cleanJson = rawData.replaceAll("'", '"');
        
        // ★ 修正：如果數據缺少陣列括號，加上它
        if (!cleanJson.startsWith('[')) {
          cleanJson = '[$cleanJson]';
        }
        
        timeline = jsonDecode(cleanJson);
      }
    } catch (e) {
      print("⚠️ 解析 timelineData 失敗: $e");
      print("   原始數據: ${widget.record.timelineData}");
      return const Center(child: Text("無法解析時間軸數據"));
    }
    
    if (timeline.isEmpty) return const Center(child: Text("無時間軸數據"));

    double maxSeconds = 0;
    if (timeline.isNotEmpty) {
      maxSeconds = (timeline.last['t'] as num).toDouble();
    }
    // 防呆
    if (maxSeconds == 0) maxSeconds = 10;
    
    // 計算間隔 (維持您原本喜歡的 "只切中間和後面" 風格)
    double interval = maxSeconds / 2;

    return Container(
      height: 250,
      // ★★★ 修正點：調整 Padding，讓左邊貼齊一點 ★★★
      padding: const EdgeInsets.only(right: 24, left: 0, top: 24, bottom: 12),
      child: LineChart(
        LineChartData(
          // ★★★ 需求 4：X 軸從 0 開始，完全貼齊 Y 軸 ★★★
          minX: 0, 
          maxX: maxSeconds,
          minY: 0,
          maxY: 100,

          // ★★★ 點擊曲線跳轉影片功能 ★★★
          lineTouchData: LineTouchData(
            enabled: true,
            // 點擊事件：跳轉到影片對應時間點
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              // 只在點擊放開時觸發 (避免重複)
              if (event is FlTapUpEvent) {
                if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                  final spot = touchResponse.lineBarSpots!.first;
                  final timestamp = spot.x; // 取得圖表上的秒數
                  
                  // 如果影片有初始化，就跳轉
                  if (_isVideoInitialized && _videoController != null) {
                    _videoController!.seekTo(Duration(milliseconds: (timestamp * 1000).toInt()));
                    _videoController!.play(); // 跳轉後自動播放
                    
                    // 顯示提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('跳轉到 ${timestamp.toStringAsFixed(1)} 秒'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } else {
                    // 如果沒有影片，顯示提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('此紀錄未儲存影片，無法跳轉播放'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            touchTooltipData: LineTouchTooltipData(
              // 提示框背景色
              getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  // 顯示時間和數值
                  return LineTooltipItem(
                    "${spot.x.toStringAsFixed(1)}秒\n${spot.y.toInt()}%",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList();
              },
            ),
            // 顯示觸碰指示線
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(color: Colors.red, strokeWidth: 2, dashArray: [5, 5]),
                  FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.red,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }),
                );
              }).toList();
            },
          ),
          
          // 網格設定
          gridData: FlGridData(
            show: true, 
            verticalInterval: interval, 
            horizontalInterval: 20, 
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),

          // 標題設定
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Align(
                alignment: Alignment.centerRight,
                child: Text("單位: 秒", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  // 隱藏 0，只顯示中間和最後
                  if (val == 0) return const SizedBox.shrink();
                  
                  // 避免太靠近右邊界被切掉
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text("${val.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 40,
                getTitlesWidget: (val, meta) => Text("${val.toInt()}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
          
          lineBarsData: [
            _buildLine(timeline, 'c', Colors.blue),
            _buildLine(timeline, 'p', Colors.red),
            _buildLine(timeline, 'n', Colors.orange),
            _buildLine(timeline, 'r', Colors.green),
          ],
        ),
      ),
    );
  } 

  // ==========================================
  // 2. 這是下面的函式：_buildLine
  // ==========================================
  LineChartBarData _buildLine(List<dynamic> data, String key, Color color) {
    return LineChartBarData(
      spots: data.map((e) => FlSpot((e['t'] as num).toDouble(), (e[key] as num).toDouble())).toList(),
      isCurved: true, 
      preventCurveOverShooting: true, // 防止爆框
      color: color,
      barWidth: 3, 
      isStrokeCapRound: true,
      
      // ★★★ 需求 3：移除所有圓點 (show: false) ★★★
      dotData: FlDotData(show: false),
      
      belowBarData: BarAreaData(show: false),
    );
  }
}