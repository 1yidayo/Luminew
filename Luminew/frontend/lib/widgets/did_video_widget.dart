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
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.black, // 如果還沒連線，背景是黑色
        shape: BoxShape.circle, // 讓畫面變成圓形的外觀，就像一個面試官的大頭照
        border: Border.all(color: Colors.blueAccent, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // (已移除預設大頭照，保持黑畫面等待視訊流)
            RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, 
            ),
          ],
        ),
      ),
    );
  }
}
