// lib/did_interview_service.dart
// D-ID Interview Service - Clean & Robust Version
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DidInterviewService {
  final String backendUrl;

  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  WebSocketChannel? _wsChannel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<int> _audioBuffer = [];

  bool isRecording = false;
  String? _sessionId;
  bool _isAnswerSubmitted = false;
  final List<RTCIceCandidate> _iceBuffer = [];

  Function(String role, String text)? onTranscript;
  Function()? onTtsDone;
  Function(String error)? onError;
  Function()? onVideoTrack;
  Function(String state)? onConnectionState;

  DidInterviewService({required this.backendUrl});

  Future<void> init() async {
    await remoteRenderer.initialize();
    await _forceSpeakerOn();
    _audioPlayer.onPlayerComplete.listen((_) {
      print('✅ [DEBUG] WAV 語音播放完畢');
      onTtsDone?.call();
    });
  }

  Future<void> _forceSpeakerOn() async {
    try {
      await Helper.setSpeakerphoneOn(true);
      print('🔊 [Audio] setSpeakerphoneOn(true)');
    } catch (e) {
      print('⚠️ [Audio] setSpeakerphoneOn 失敗: $e');
    }
  }

  Future<void> dispose() async {
    await stopInterview();
    await remoteRenderer.dispose();
    await _audioRecorder.dispose();
    await _audioPlayer.dispose();
  }

  Future<void> startInterview(String professorType) async {
    try {
      print('🚀 [DEBUG] 正在呼叫後端 /start API (教授: $professorType)...');
      final startRes = await http
          .post(
            Uri.parse('$backendUrl/api/interview/start'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true', // 跳過 Ngrok 警告
            },
            body: jsonEncode({'professor_type': professorType}),
          )
          .timeout(const Duration(seconds: 30));

      final startData = jsonDecode(startRes.body);
      if (startData['status'] == 'error') throw Exception(startData['message']);

      _sessionId = startData['session_id'];
      final offerMap = startData['offer'];

      final configuration = {
        'iceServers':
            (offerMap['ice_servers'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [
              {'urls': 'stun:stun.l.google.com:19302'},
              {'urls': 'stun:stun1.l.google.com:19302'},
              {'urls': 'stun:stun.cloudflare.com:3478'},
            ],
        'sdpSemantics': 'unified-plan',
      };
      _peerConnection = await createPeerConnection(configuration);

      // 強制建立 DataChannel 以滿足 D-ID 的 SDP 結構需求
      await _peerConnection!.createDataChannel("chat", RTCDataChannelInit());

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        // [Trickle ICE] 抓到就送，不再緩衝
        _sendIceCandidate(candidate);
      };

      _peerConnection!.onIceConnectionState = (state) {
        final stateStr = state.toString().split('.').last;
        print('📡 [WebRTC] ICE 狀態: $stateStr');
        onConnectionState?.call(stateStr);
        if (stateStr == 'connected' || stateStr == 'completed') {
          _forceSpeakerOn();
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('📡 [WebRTC] 接收軌道: ${event.track.kind}');
        if (event.track.kind == 'video') {
          if (event.streams.isNotEmpty) {
            remoteRenderer.srcObject = event.streams[0];
            print('📺 [WebRTC] 視訊流已掛載至 renderer');
          }
          event.track.enabled = true;
          onVideoTrack?.call();
        } else if (event.track.kind == 'audio') {
          event.track.enabled = true;
          _forceSpeakerOn();
        }
      };

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          offerMap['offer']['sdp'],
          offerMap['offer']['type'],
        ),
      );

      // ★ 核心穩定點：明確告知 WebRTC 我們只要接收影像與音訊，即使沒有本地攝像頭
      var transceivers = await _peerConnection!.getTransceivers();
      for (var t in transceivers) {
        if (t.receiver.track?.kind == 'video' ||
            t.receiver.track?.kind == 'audio') {
          t.setDirection(TransceiverDirection.RecvOnly);
        }
      }

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // [優化] 移除人為緩衝期，直接進入 SDP 處理

      final localSdp = await _peerConnection!.getLocalDescription();
      String sdpString = localSdp?.sdp ?? '';

      // ★ 輕量級修正：將 127.0.0.1 換成虛擬公網 IP，避免部分設備內部路由衝突
      sdpString = sdpString.replaceAll('127.0.0.1', '1.1.1.1');

      // 修正連線角色為 active
      if (sdpString.contains('a=setup:actpass')) {
        sdpString = sdpString.replaceAll('a=setup:actpass', 'a=setup:active');
      }

      // 連接 WebSocket
      final wsUrl = backendUrl
          .replaceFirst('http', 'ws')
          .replaceFirst('https', 'wss');
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/api/interview/ws/$_sessionId'),
      );
      _wsChannel!.stream.listen((message) {
        if (message is String) {
          final data = jsonDecode(message);
          final event = data['event'];
          if (event == 'transcript') {
            onTranscript?.call(data['role'] ?? '', data['text'] ?? '');
          } else if (event == 'tts_start') {
            print('🔊 [DEBUG] 啟動備援音訊播放...');
            _playBufferedAudio();
          } else if (event == 'did_ice') {
            _peerConnection?.addCandidate(
              RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              ),
            );
          }
        } else if (message is Uint8List) {
          _audioBuffer.addAll(message);
        }
      }, onError: (e) => onError?.call("WS Error: $e"));

      // [優化] 移除送出 Answer 前的等待期

      print('📡 [DEBUG] 傳送 Answer SDP...');
      await http.post(
        Uri.parse('$backendUrl/api/interview/webrtc-answer'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // 跳過 Ngrok 警告
        },
        body: jsonEncode({
          'session_id': _sessionId,
          'answer': {'type': 'answer', 'sdp': sdpString},
        }),
      );

      _isAnswerSubmitted = true;
      print('✅ [DEBUG] 握手完成');
    } catch (e) {
      print('❌ 初始化失敗: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;

    // 如果 WebRTC 穩定連線，則捨棄備援音訊，避免雙重回音！
    final iceState = _peerConnection?.iceConnectionState;
    if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      print('✅ [DEBUG] WebRTC 已接管音訊，捨棄 WebSocket 備援音檔');
      _audioBuffer.clear();
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/temp_tts_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(_audioBuffer);
      _audioBuffer.clear();
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      print('❌ TTS 播放失敗: $e');
      _audioBuffer.clear();
      onTtsDone?.call();
    }
  }

  Future<void> startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      isRecording = true;
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _audioStreamSubscription = stream.listen(
        (data) => _wsChannel?.sink.add(data),
      );
    }
  }

  Future<void> stopRecording() async {
    isRecording = false;
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
    _wsChannel?.sink.add(jsonEncode({'event': 'speech_end'}));
  }

  Future<void> stopInterview() async {
    _wsChannel?.sink.add(jsonEncode({'event': 'stop_interview'}));
    _wsChannel?.sink.close();
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
    await _peerConnection?.close();
    _peerConnection = null;
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/api/interview/webrtc-ice'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // 跳過 Ngrok 警告
        },
        body: jsonEncode({
          'session_id': _sessionId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    } catch (e) {
      print('ICE Error: $e');
    }
  }

  // [已廢棄] 改為 Trickle ICE 即時傳輸
  Future<void> _flushIceCandidates() async {
    _iceBuffer.clear();
  }
}
