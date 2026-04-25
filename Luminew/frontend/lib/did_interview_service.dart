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
import 'package:flutter/material.dart';

class DidInterviewService {
  String? backendUrl;

  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  WebSocketChannel? _wsChannel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<int> _audioBuffer = [];

  bool isRecording = false;
  String? _sessionId;
  final List<RTCIceCandidate> _iceBuffer = [];

  Function(String role, String text)? onTranscript;
  Function()? onTtsDone;
  Function(String error)? onError;
  Function()? onVideoTrack;
  Function(String state)? onConnectionState;
  Function(RTCIceCandidate candidate)? onIceCandidate;

  DidInterviewService({this.backendUrl});

  Future<void> init() async {
    await remoteRenderer.initialize();
  }

  Future<void> dispose() async {
    await stopInterview();
    await remoteRenderer.dispose();
    await _audioRecorder.dispose();
    await _audioPlayer.dispose();
  }

  Future<bool> startInterview({
    required String type,
    required String interviewer,
    required String language,
    required String department,
  }) async {
    try {
      if (backendUrl == null) throw Exception("backendUrl is not set");
      
      final startRes = await http.post(
        Uri.parse('$backendUrl/api/interview/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'professor_type': interviewer,
          'type': type,
          'language': language,
          'department': department
        }),
      ).timeout(const Duration(seconds: 30));

      final startData = jsonDecode(startRes.body);
      _sessionId = startData['session_id'];
      final offerMap = startData['offer'];

      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ],
        'sdpSemantics': 'unified-plan',
      };
      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _sendIceCandidate(candidate);
      };

      _peerConnection!.onIceConnectionState = (state) {
        onConnectionState?.call(state.toString().split('.').last);
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          onVideoTrack?.call();
        }
      };

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerMap['offer']['sdp'], offerMap['offer']['type']),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // WebSocket
      final wsUrl = backendUrl!.replaceFirst('http', 'ws');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/api/interview/ws/$_sessionId'));
      _wsChannel!.stream.listen((message) {
        if (message is String) {
          final data = jsonDecode(message);
          if (data['event'] == 'transcript') {
            onTranscript?.call(data['role'], data['text']);
          } else if (data['event'] == 'tts_done' || data['event'] == 'talk_completed') {
            onTtsDone?.call();
          }
        }
      });

      await http.post(
        Uri.parse('$backendUrl/api/interview/webrtc-answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'answer': {'type': 'answer', 'sdp': answer.sdp},
        }),
      );

      return true;
    } catch (e) {
      print('❌ D-ID 連線失敗: $e');
      return false;
    }
  }

  void startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final stream = await _audioRecorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );
      _audioStreamSubscription = stream.listen((data) => _wsChannel?.sink.add(data));
    }
  }

  void sendInterviewAction(String action) {
    _wsChannel?.sink.add(jsonEncode({'event': action}));
  }

  Future<void> stopInterview() async {
    _wsChannel?.sink.close();
    await _audioStreamSubscription?.cancel();
    await _peerConnection?.close();
    _peerConnection = null;
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (backendUrl == null) return;
    try {
      await http.post(
        Uri.parse('$backendUrl/api/interview/webrtc-ice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    } catch (_) {}
  }
}

class DidVideoWidget extends StatelessWidget {
  final RTCVideoRenderer renderer;
  const DidVideoWidget({super.key, required this.renderer});

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}
