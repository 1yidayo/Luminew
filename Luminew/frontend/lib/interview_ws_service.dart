// lib/interview_ws_service.dart
// WebSocket 即時面試連線管理
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class InterviewWsService {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // 回呼
  Function(String role, String text)? onTranscript; // 學生/教授文字
  Function(Uint8List audioChunk)? onAudioChunk;     // TTS 音訊
  Function()? onTtsDone;                            // TTS 播放結束
  Function()? onInterviewStarted;                   // 面試開始確認
  Function()? onInterviewStopped;                   // 面試結束確認
  Function(String error)? onError;                  // 錯誤

  bool get isConnected => _isConnected;

  /// 連線到後端 WebSocket
  Future<void> connect(String clientId) async {
    try {
      final uri = Uri.parse('ws://10.0.2.2:8000/interview/ws/$clientId');
      _channel = WebSocketChannel.connect(uri);

      // 等待連線建立
      await _channel!.ready;
      _isConnected = true;
      print('✅ WebSocket 已連線: $uri');

      // 監聽訊息
      _channel!.stream.listen(
        (message) {
          if (message is String) {
            // JSON 文字訊息
            _handleTextMessage(message);
          } else if (message is List<int>) {
            // binary 音訊 chunk
            onAudioChunk?.call(Uint8List.fromList(message));
          }
        },
        onError: (error) {
          print('❌ WebSocket 錯誤: $error');
          onError?.call(error.toString());
          _isConnected = false;
        },
        onDone: () {
          print('🔚 WebSocket 已關閉');
          _isConnected = false;
        },
      );
    } catch (e) {
      print('❌ WebSocket 連線失敗: $e');
      onError?.call(e.toString());
      _isConnected = false;
    }
  }

  /// 發送開始面試指令
  void startInterview({String professorType = 'warm_industry_professor'}) {
    _sendJson({
      'event': 'start_interview',
      'professor_type': professorType,
    });
  }

  /// 發送結束面試指令
  void stopInterview() {
    _sendJson({'event': 'stop_interview'});
  }

  /// 發送「我說完了」指令，觸發教授回應
  void sendSpeechEnd() {
    _sendJson({'event': 'speech_end'});
  }

  /// 發送音訊 chunk（麥克風錄音資料）
  void sendAudioChunk(Uint8List audioData) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(audioData);
    }
  }

  /// 斷線
  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  // --- 內部方法 ---

  void _sendJson(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleTextMessage(String message) {
    try {
      final data = jsonDecode(message);
      final event = data['event'] as String? ?? '';

      switch (event) {
        case 'interview_started':
          print('🎓 面試開始: ${data['professor']}');
          onInterviewStarted?.call();
          break;
        case 'transcript':
          final role = data['role'] as String? ?? '';
          final text = data['text'] as String? ?? '';
          print('📝 [$role] $text');
          onTranscript?.call(role, text);
          break;
        case 'tts_done':
          onTtsDone?.call();
          break;
        case 'interview_stopped':
          print('⏹ 面試結束');
          onInterviewStopped?.call();
          break;
        default:
          print('⚠️ 未知事件: $event');
      }
    } catch (e) {
      print('❌ 解析訊息失敗: $e');
    }
  }
}
