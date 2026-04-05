import 'package:flutter/material.dart';
import 'did_interview_service.dart';
import 'widgets/did_video_widget.dart';

// 這個獨立的 main 函式讓你可以不用管資料庫，直接在這裡執行測試
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TestInterviewScreen()
  ));
}

class TestInterviewScreen extends StatefulWidget {
  const TestInterviewScreen({super.key});

  @override
  State<TestInterviewScreen> createState() => _TestInterviewScreenState();
}

class _TestInterviewScreenState extends State<TestInterviewScreen> {
  late DidInterviewService _didService;
  String _latestText = "等待連線與面試官開口...";

  @override
  void initState() {
    super.initState();
    // 💡 重要：請把這裡換成你剛剛在終端機看到的 Ngrok 網址
    _didService = DidInterviewService(backendUrl: 'https://你的ngrok網址');
    
    // 當後端有新字幕傳來時，更新畫面
    _didService.onTranscript = (role, text) {
      if (mounted) {
        setState(() {
          _latestText = "${role == 'professor' ? '👨‍🏫 教授' : '🧑‍🎓 你'}:\n$text";
        });
      }
    };

    _didService.onError = (e) {
      if (mounted) {
        setState(() => _latestText = '❌ 錯誤: $e');
      }
    };

    // 初始化並啟動連線
    _didService.init().then((_) {
      _didService.startInterview();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _didService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('獨立面試測試站 (免資料庫)'), backgroundColor: Colors.indigo),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 秀出我們寫的影片積木
            DidVideoWidget(renderer: _didService.localRenderer),
            
            const SizedBox(height: 30),
            
            // 字幕區
            Container(
              padding: const EdgeInsets.all(16.0),
              width: 320,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _latestText, 
                style: const TextStyle(fontSize: 16, height: 1.5), 
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 按下講話，放開送出的按鈕
            GestureDetector(
              onTapDown: (_) {
                setState(() => _latestText = "🎙️ 錄音中...請講話");
                _didService.startRecording();
              },
              onTapUp: (_) {
                setState(() => _latestText = "⏳ 思考中...等待教授回應");
                _didService.stopRecording();
              },
              onTapCancel: () {
                _didService.stopRecording();
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, spreadRadius: 3)
                  ]
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 10),
            const Text('💡 長按麥克風講話，放開送出', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
