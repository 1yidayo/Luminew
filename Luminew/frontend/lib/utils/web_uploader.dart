// web_recorder.dart - 僅在 Flutter Web 使用
// 利用瀏覽器原生 MediaRecorder，每 5 秒分塊，不累積大 buffer

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

class WebVideoRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];
  Completer<String?>? _completer;

  bool get isRecording => _recorder?.state == 'recording';

  /// 開始錄影
  /// 嘗試重用瀏覽器已存在的視訊 track（避免申請第二個攝影機權限）
  Future<void> start() async {
    _chunks.clear();
    _completer = Completer<String?>();

    try {
      // 先嘗試從 DOM 中抓取現有的 video element 的 stream（Flutter CameraPreview 用的）
      final videoElements = html.document.querySelectorAll('video');
      html.MediaStream? existingStream;
      for (final el in videoElements) {
        final video = el as html.VideoElement;
        final stream = video.srcObject;
        if (stream != null && stream is html.MediaStream) {
          final videoTracks = stream.getVideoTracks();
          if (videoTracks.isNotEmpty) {
            existingStream = stream;
            break;
          }
        }
      }

      if (existingStream != null) {
        // 重用已有的 stream（只有 video track，不含音訊）
        _stream = existingStream;
        print('✅ [WebRecorder] 重用現有相機 stream');
      } else {
        // 備用：申請新的 stream
        _stream = await html.window.navigator.mediaDevices?.getUserMedia({
          'video': {'facingMode': 'user', 'width': 640, 'height': 480},
          'audio': false,
        });
        print('✅ [WebRecorder] 申請新的相機 stream');
      }

      if (_stream == null) throw Exception('無法取得相機串流');

      // 建立一個只含 video tracks 的新 stream（避免帶入音訊）
      final videoOnlyStream = html.MediaStream();
      for (final track in _stream!.getVideoTracks()) {
        videoOnlyStream.addTrack(track);
      }

      // 決定支援的 mimeType
      final mimeTypes = [
        'video/webm;codecs=vp9',
        'video/webm;codecs=vp8',
        'video/webm',
        'video/mp4',
      ];
      String selectedMime = 'video/webm';
      for (final mime in mimeTypes) {
        if (html.MediaRecorder.isTypeSupported(mime)) {
          selectedMime = mime;
          break;
        }
      }
      print('✅ [WebRecorder] 使用 mimeType: $selectedMime');

      final options = {'mimeType': selectedMime, 'videoBitsPerSecond': 500000};
      _recorder = html.MediaRecorder(videoOnlyStream, options as Map<String, dynamic>);

      _recorder!.addEventListener('dataavailable', (event) {
        final e = event as html.BlobEvent;
        if (e.data != null && e.data!.size > 0) {
          _chunks.add(e.data!);
          print('📦 [WebRecorder] 收到分塊 #${_chunks.length}, 大小: ${e.data!.size} bytes');
        }
      });

      _recorder!.addEventListener('stop', (event) {
        final blob = html.Blob(_chunks, selectedMime);
        final url = html.Url.createObjectUrlFromBlob(blob);
        print('✅ [WebRecorder] 錄影結束，總分塊: ${_chunks.length}, 合併後大小: ${blob.size} bytes');
        if (!(_completer?.isCompleted ?? true)) _completer!.complete(url);
      });

      _recorder!.addEventListener('error', (event) {
        print('❌ [WebRecorder] 錄影錯誤: $event');
        if (!(_completer?.isCompleted ?? true)) {
          _completer!.completeError('MediaRecorder error');
        }
      });

      // timeslice = 5000ms：每 5 秒觸發一次 dataavailable，保持 buffer 小
      _recorder!.start(5000);
      print('🎬 [WebRecorder] 開始錄影（每 5 秒分塊）');
    } catch (e) {
      _completer?.completeError(e);
      rethrow;
    }
  }

  /// 停止錄影，回傳 blob URL
  Future<String?> stop() async {
    if (_recorder == null) return null;
    if (_recorder!.state == 'recording') {
      _recorder!.stop();
    }
    return _completer?.future;
  }

  void dispose() {
    try {
      if (_recorder?.state == 'recording') _recorder?.stop();
    } catch (_) {}
    _chunks.clear();
  }
}

/// 上傳 blobUrl 到伺服器（使用 XHR FormData，不把 blob 載入 Dart 記憶體）
Future<String> uploadVideoWeb(
  String blobUrl,
  String fileName,
  String url,
  Map<String, String> fields, {
  void Function(double progress)? onProgress,
}) async {
  // 從 blob URL 取得 Blob 物件的參考（不複製記憶體，瀏覽器直接持有）
  final req = await html.HttpRequest.request(blobUrl, responseType: 'blob');
  final blob = req.response as html.Blob;
  print('📤 [WebUpload] 開始上傳, 檔案大小: ${blob.size} bytes → $url');

  final formData = html.FormData();
  formData.appendBlob('video', blob, fileName);
  fields.forEach((key, value) => formData.append(key, value));

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  xhr.timeout = 300000; // 300 秒

  if (onProgress != null) {
    xhr.upload.onProgress.listen((html.ProgressEvent e) {
      if (e.lengthComputable) {
        final loaded = e.loaded ?? 0;
        final total = e.total ?? 1;
        final percent = loaded / (total > 0 ? total : 1);
        onProgress(percent);
      }
    });
  }

  final completer = Completer<String>();
  xhr.onLoad.listen((_) {
    print('📥 [WebUpload] 收到回應 status=${xhr.status}');
    if (xhr.status == 200) {
      completer.complete(xhr.responseText ?? '');
    } else {
      completer.completeError(
        'Server error: ${xhr.status} ${xhr.responseText}',
      );
    }
  });
  xhr.onError.listen((_) {
    print('❌ [WebUpload] 網路錯誤');
    completer.completeError('網路錯誤，請確認伺服器連線');
  });
  xhr.onTimeout.listen((_) {
    print('⏱ [WebUpload] 上傳逾時');
    completer.completeError('上傳逾時（300 秒）');
  });

  xhr.send(formData);
  return completer.future;
}
