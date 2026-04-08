// lib/widgets/did_video_widget.dart
// 這是一個隨插即用的積木，只要塞進 UI 裡面就可以出教授的畫面了！
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DidVideoWidget extends StatelessWidget {
  // 從 Service 那邊傳過來的 renderer 核心
  final RTCVideoRenderer renderer;

  const DidVideoWidget({Key? key, required this.renderer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}
