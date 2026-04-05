// lib/did_interview_service.dart
// 這是專門用來跟剛剛寫好的 FastAPI 接界的「黑盒子」
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart'; // ★ 必加
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DidInterviewService {
  // 後端網址 (可以傳入 ngrok 網址，或如果是在 Android 模擬器測本地端請填 'http://10.0.2.2:8000')
  final String backendUrl; 
  
  // ============ 核心元件 ============
  RTCPeerConnection? _peerConnection;
  
  // 提供給 UI 使用的影片渲染器 (把這個變數傳給 DidVideoWidget 就能出畫面)
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  
  WebSocketChannel? _wsChannel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer(); // ★ 用來播放後端傳來的 WAV 片段
  final List<int> _audioBuffer = []; // ★ 集中緩存音檔片段區
  
  // ============ 狀態變數 ============
  bool isRecording = false;
  String? _sessionId;
  
  // ============ UI 的回呼積木 ============
  Function(String role, String text)? onTranscript; // 當生出新字幕時觸發
  Function()? onTtsDone;                            // 當教授這段話講完時觸發
  Function(String error)? onError;                  // 發生錯誤時觸發
  Function()? onVideoTrack;                         // ★ 新增：當視訊軌道掛載成功時通知 UI

  DidInterviewService({required this.backendUrl});

  Future<void> init() async {
    await localRenderer.initialize();
    try {
      await Helper.setSpeakerphoneOn(true); // ★ 強制將 WebRTC 的聲音改從擴音喇叭播出，避免只在聽筒
    } catch(e) {
      print('Speakerphone Error: $e');
    }
    _audioPlayer.onPlayerComplete.listen((_) {
      print('✅ [DEBUG] 語音播放完畢，執行後續動作 (例如開啟麥克風)');
      onTtsDone?.call();
    });
  }

  /// 釋放記憶體 (離開面試頁面時呼叫)
  Future<void> dispose() async {
    await stopInterview();
    await localRenderer.dispose();
    await _audioRecorder.dispose();
    await _audioPlayer.dispose(); // ★ 釋放資源
  }

  /// 1. 第一步：打 API 申請房間、建立視訊、建立字幕通道
  Future<void> startInterview() async {
    try {
      print('🚀 開始初始化 D-ID 面試...');
      
      print('🚀 [DEBUG] 正在呼叫後端 /start API...');
      final startRes = await http.post(Uri.parse('$backendUrl/api/interview/start')).timeout(const Duration(seconds: 10));
      print('🚀 [DEBUG] /start API 回應狀態碼: ${startRes.statusCode}');
      final startData = jsonDecode(startRes.body);
      
      if (startData['status'] == 'error') {
        throw Exception(startData['message']);
      }

      _sessionId = startData['session_id'];
      final offerMap = startData['offer'];

      // 1-2. 建立 WebRTC (視訊) 連線
      _peerConnection = await createPeerConnection({
        'iceServers': offerMap['ice_servers'] ?? [{'urls': 'stun:stun.l.google.com:19302'}],
        'sdpSemantics': 'unified-plan'
      });

      // ★ 核心優化：手動添加收發器 (Transceiver)，主動要求接收視訊與音訊
      // 這能解決某些手機產生的 Answer 中出現 m=video 0 (拒絕媒體流) 的問題
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // 後台處理：把網路尋路資訊(ICE)隨時跟後台報告
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('📡 [DEBUG] 傳送 ICE Candidate 到後端...');
        http.post(
          Uri.parse('$backendUrl/api/interview/webrtc-ice'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'session_id': _sessionId,
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }),
        );
      };

      // 重要：當 D-ID 把影片流傳過來時，接進我們要給 UI 的渲染器內！
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('📡 [DEBUG] 接收到 WebRTC 軌道: ${event.track.kind}');
        if (event.track.kind == 'video') {
          print('✅ 大功告成！接收到 D-ID 影像軌道！');
          localRenderer.srcObject = event.streams[0];
          onVideoTrack?.call(); // ★ 通知 UI 重新整理
        }
      };

      // 1-3. 處理 D-ID 的 Offer 並回傳我們手機產生的 Answer
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerMap['offer']['sdp'], offerMap['offer']['type'])
      );

      // ★ 重要：在使用 Transceiver 的情況下，不要在 createAnswer 中帶參數，避免產生衝突
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // ★ 增加超時時間到 10 秒，確保在手機網路上能收集到足夠的候選人
      print('⏳ 等待 ICE 收集 (Gathering)...');
      int timeout = 0;
      while (_peerConnection!.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete && timeout < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        timeout++;
      }
      print('✅ ICE 收集狀態: ${_peerConnection!.iceGatheringState}');

      final localSdp = await _peerConnection!.getLocalDescription();
      if (localSdp != null && localSdp.sdp != null) {
        print('📡 [DEBUG] 本地產生的 SDP (擷取一部分):\n${localSdp.sdp!.substring(0, 300)}...');
      }

      print('📡 [DEBUG] 正在傳送 WebRTC Answer...');
      final answerRes = await http.post(
        Uri.parse('$backendUrl/api/interview/webrtc-answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'answer': {'type': localSdp?.type ?? answer.type, 'sdp': localSdp?.sdp ?? answer.sdp}
        }),
      );
      print('✅ [DEBUG] WebRTC 視訊握手完成，狀態碼: ${answerRes.statusCode}');

      // 1-4. 建立 WebSocket 連線 (專門處理你講的話，跟即時字幕推播)
      final wsUrl = backendUrl.replaceFirst('http', 'ws').replaceFirst('https', 'wss');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/api/interview/ws/$_sessionId'));
      
      _wsChannel!.stream.listen(
        (message) {
          if (message is String) {
            final data = jsonDecode(message);
            final event = data['event'];
            if (event == 'transcript') {
              print('🎯 [DEBUG] 收到字幕: ${data['role']} - ${data['text']}');
              onTranscript?.call(data['role'] ?? '', data['text'] ?? '');
            } else if (event == 'tts_done') {
              print('✅ [DEBUG] 教授說話 (接收) 完畢');
              _playBufferedAudio();
            }
          } else if (message is Uint8List) {
            // ★ 接收到二進位音訊 (WAV片段)，先存進 buffer 避免直接播放導致解析失敗！
            _audioBuffer.addAll(message);
          }
        },
        onError: (e) {
           print("❌ [DEBUG] WebSocket 發生錯誤: $e");
           onError?.call("WebSocket 斷線: $e");
        },
        onDone: () => print('🔚 [DEBUG] WebSocket 關閉'),
      );
      
      print('🎉 面試水管鋪設完畢，隨時準備大顯身手！');
    } catch (e) {
      print('❌ 面試初始化失敗: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) {
      onTtsDone?.call(); // 保底呼叫
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(_audioBuffer);
      _audioBuffer.clear(); // 存完先清空，準備下一句
      
      await Future.delayed(const Duration(milliseconds: 100)); // 緩解 IO
      print('🔊 [DEBUG] 正在播放合成語音檔: ${file.path}');
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      print('❌ TTS 播放失敗: $e');
      _audioBuffer.clear();
      onTtsDone?.call(); // 若播放失敗，還是得繼續流程
    }
  }

  /// 2. 學生按下「講話按鈕」時呼叫 (這會打開麥克風，光速直傳後台)
  Future<void> startRecording() async {
    try {
      print('🎤 [ASR] 正在嘗試開啟麥克風...');
      final status = await Permission.microphone.request();
      print('🎤 [ASR] 權限狀態: $status');
      
      if (status.isGranted) {
        if (await _audioRecorder.isRecording()) {
          print('⚠️ [ASR] 麥克風已經在錄音中，先關閉舊的...');
          await _audioRecorder.stop();
        }

        isRecording = true;
        // 開啟音訊串流模式
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          )
        );

        print('🎤 [ASR] 串流已成功建立！');

        _audioStreamSubscription = stream.listen((data) {
          if (_wsChannel != null) {
            // print('📤 [ASR] 發送音訊: ${data.length} bytes');
            _wsChannel!.sink.add(data);
          }
        });
      } else {
        print('❌ [ASR] 麥克風權限被拒絕');
        onError?.call('請允許麥克風權限才能開始面試');
      }
    } catch (e) {
      print('❌ [ASR] 啟動錄音噴錯: $e');
      isRecording = false;
    }
  }

  /// 3. 學生放開「講話按鈕」時呼叫 (停止收音，後台 ChatGPT 準備運轉)
  Future<void> stopRecording() async {
    if (!isRecording) return;
    isRecording = false;
    try {
      await _audioStreamSubscription?.cancel();
      await _audioRecorder.stop();
      print('⏹ 錄音結束，通知後端處理');
      
      if (_wsChannel != null) {
        _wsChannel!.sink.add(jsonEncode({'event': 'speech_end'}));
      }
    } catch (e) {
      print('❌ 停止錄音失敗: $e');
    }
  }

  /// 4. 放棄面試或返回上一頁時呼叫
  Future<void> stopInterview() async {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'event': 'stop_interview'}));
      _wsChannel!.sink.close();
    }
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
    await _peerConnection?.close();
    _peerConnection = null;
    localRenderer.srcObject = null;
  }
}
