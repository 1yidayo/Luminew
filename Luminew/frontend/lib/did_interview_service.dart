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
      final startRes = await http.post(
        Uri.parse('$backendUrl/api/interview/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'professor_type': professorType}),
      ).timeout(const Duration(seconds: 30));
      
      final startData = jsonDecode(startRes.body);
      if (startData['status'] == 'error') throw Exception(startData['message']);

      _sessionId = startData['session_id'];
      final offerMap = startData['offer'];

      final configuration = {
        'iceServers': (offerMap['ice_servers'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [{'urls': 'stun:stun.l.google.com:19302'}],
        'sdpSemantics': 'unified-plan',
      };
      _peerConnection = await createPeerConnection(configuration);

      // 強制建立 DataChannel 以滿足 D-ID 的 SDP 結構需求
      await _peerConnection!.createDataChannel("chat", RTCDataChannelInit());

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        if (!_isAnswerSubmitted) {
          _iceBuffer.add(candidate);
          return;
        }
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

      await _peerConnection!.setRemoteDescription(RTCSessionDescription(offerMap['offer']['sdp'], offerMap['offer']['type']));

      // ★ 核心穩定點：明確告知 WebRTC 我們只要接收影像與音訊，即使沒有本地攝像頭
      var transceivers = await _peerConnection!.getTransceivers();
      for (var t in transceivers) {
        if (t.receiver.track?.kind == 'video' || t.receiver.track?.kind == 'audio') {
          t.setDirection(TransceiverDirection.RecvOnly);
        }
      }

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // 收集 ICE 的緩衝期
      await Future.delayed(const Duration(milliseconds: 1000));

      final localSdp = await _peerConnection!.getLocalDescription();
      String sdpString = localSdp?.sdp ?? '';

      // ★ 強力修正：精準定位 a=mid:0 並且補上 Sony 最相容的參數
      if (sdpString.contains('m=video 0')) {
        print('🔧 [SDP Fix] 執行深度 SDP 修復 (Sony/D-ID Compatibility)...');
        sdpString = sdpString.replaceAll('m=video 0 UDP/TLS/RTP/SAVPF 0', 'm=video 9 UDP/TLS/RTP/SAVPF 100');
        
        // 使用更精準的 H.264 宣告，包含 packetization-mode 與 profile-level-id
        String h264Params = 'a=rtpmap:100 H264/90000\r\n'
                          'a=fmtp:100 packetization-mode=1;profile-level-id=42e01f;level-asymmetry-allowed=1\r\n'
                          'a=rtcp-fb:100 nack\r\n'
                          'a=rtcp-fb:100 nack pli\r\n'
                          'a=msid:Luminew-Video-Stream Luminew-Video-Track\r\n';
        
        // 確保在 mid:0 之後插入
        sdpString = sdpString.replaceFirst(RegExp(r'a=mid:0\r?\n'), 'a=mid:0\r\n$h264Params');
      }

      // 修正連線角色為 active
      if (sdpString.contains('a=setup:actpass')) {
        sdpString = sdpString.replaceAll('a=setup:actpass', 'a=setup:active');
      }

      // ★ 全域 IP 洗滌：將 127.0.0.1 換成虛擬公網 IP，避免 D-ID 報錯
      sdpString = sdpString.replaceAll('127.0.0.1', '1.1.1.1');

      // 連接 WebSocket
      final wsUrl = backendUrl.replaceFirst('http', 'ws').replaceFirst('https', 'wss');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/api/interview/ws/$_sessionId'));
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
            _peerConnection?.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        } else if (message is Uint8List) {
          _audioBuffer.addAll(message);
        }
      }, onError: (e) => onError?.call("WS Error: $e"));

      await Future.delayed(const Duration(milliseconds: 300));

      print('📡 [DEBUG] 傳送 Answer SDP...');
      await http.post(
        Uri.parse('$backendUrl/api/interview/webrtc-answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': _sessionId, 'answer': {'type': 'answer', 'sdp': sdpString}}),
      );

      _isAnswerSubmitted = true;
      await _flushIceCandidates();
      print('✅ [DEBUG] 握手完成');
    } catch (e) {
      print('❌ 初始化失敗: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
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
      final stream = await _audioRecorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
      _audioStreamSubscription = stream.listen((data) => _wsChannel?.sink.add(data));
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
      await http.post(Uri.parse('$backendUrl/api/interview/webrtc-ice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    } catch (e) { print('ICE Error: $e'); }
  }

  Future<void> _flushIceCandidates() async {
    if (_iceBuffer.isNotEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      for (var c in _iceBuffer) _sendIceCandidate(c);
      _iceBuffer.clear();
    }
  }
}
