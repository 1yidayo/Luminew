// web_recorder.dart - 僅在 Flutter Web 使用
// 利用瀏覽器原生 MediaRecorder，每 5 秒分塊，不累積大 buffer

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

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
        // 克隆影片軌道並加上限制，以防部分瀏覽器（例如 Safari/iOS）忽略 videoBitsPerSecond 設定。
        // 將克隆軌道限制在 480x360, 15 FPS，這既保證人臉偵測準確度，也能強制瀏覽器降低硬體編碼碼率。
        final clonedTrack = track.clone();
        try {
          final constraints = js_util.newObject();
          js_util.setProperty(constraints, 'width', js_util.jsify({'max': 480}));
          js_util.setProperty(constraints, 'height', js_util.jsify({'max': 360}));
          js_util.setProperty(constraints, 'frameRate', js_util.jsify({'max': 15}));
          js_util.callMethod(clonedTrack, 'applyConstraints', [constraints]);
        } catch (e) {
          print('⚠️ [WebRecorder] 無法為克隆的影片軌道套用限制: $e');
        }
        videoOnlyStream.addTrack(clonedTrack);
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

      // 避開 dart:html constructor 對 Map 轉換的限制，直接使用 js_util 建立原生 JS 物件作為 options，
      // 以確保瀏覽器能正確讀取 videoBitsPerSecond 設定，從而啟用 500 kbps 錄影壓縮。
      final rawOptions = js_util.newObject();
      js_util.setProperty(rawOptions, 'mimeType', selectedMime);
      js_util.setProperty(rawOptions, 'videoBitsPerSecond', 500000);

      final mediaRecorderConstructor = js_util.getProperty(html.window, 'MediaRecorder');
      _recorder = js_util.callConstructor(mediaRecorderConstructor, [videoOnlyStream, rawOptions]) as html.MediaRecorder;

      _recorder!.addEventListener('dataavailable', (event) {
        final e = event as html.BlobEvent;
        if (e.data != null && e.data!.size > 0) {
          _chunks.add(e.data!);
          print('📦 [WebRecorder] 收到分塊 #${_chunks.length}, 大小: ${e.data!.size} bytes');
        }
      });

      _recorder!.addEventListener('stop', (event) {
        // 停止並釋放所有克隆的影片軌道，防記憶體洩漏與鏡頭燈殘留
        try {
          for (final track in videoOnlyStream.getVideoTracks()) {
            track.stop();
          }
        } catch (e) {
          print('⚠️ [WebRecorder] 釋放克隆軌道失敗: $e');
        }
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

  StreamSubscription? progressSub;
  if (onProgress != null) {
    progressSub = xhr.upload.onProgress.listen((html.ProgressEvent e) {
      if (e.lengthComputable) {
        final loaded = e.loaded ?? 0;
        final total = e.total ?? 1;
        final percent = loaded / (total > 0 ? total : 1);
        onProgress(percent);
      }
    });
  }

  final completer = Completer<String>();
  StreamSubscription? loadSub;
  StreamSubscription? errorSub;
  StreamSubscription? timeoutSub;

  loadSub = xhr.onLoad.listen((_) {
    print('📥 [WebUpload] 收到回應 status=${xhr.status}');
    if (xhr.status == 200) {
      completer.complete(xhr.responseText ?? '');
    } else {
      completer.completeError(
        'Server error: ${xhr.status} ${xhr.responseText}',
      );
    }
  });
  errorSub = xhr.onError.listen((_) {
    print('❌ [WebUpload] 網路錯誤');
    completer.completeError('網路錯誤，請確認伺服器連線');
  });
  timeoutSub = xhr.onTimeout.listen((_) {
    print('⏱ [WebUpload] 上傳逾時');
    completer.completeError('上傳逾時（300 秒）');
  });

  xhr.send(formData);

  try {
    return await completer.future;
  } finally {
    progressSub?.cancel();
    loadSub?.cancel();
    errorSub?.cancel();
    timeoutSub?.cancel();
  }
}

/// 將 blobUrl 上的影片切分成 1MB 分塊，循序上傳至 /emotion/upload_chunk
Future<String> uploadVideoWebChunked(
  String blobUrl,
  String fileName,
  String url,
  Map<String, String> fields, {
  void Function(double progress)? onProgress,
}) async {
  // 從 blob URL 取得 Blob 物件參考
  final req = await html.HttpRequest.request(blobUrl, responseType: 'blob');
  final blob = req.response as html.Blob;
  final totalSize = blob.size;
  
  // 每個分塊設為 2 MB (2,097,152 bytes)
  const int chunkSize = 2 * 1024 * 1024;
  final totalChunks = (totalSize / chunkSize).ceil();
  final sessionId = 'web_${DateTime.now().millisecondsSinceEpoch}_${(totalSize % 10000)}';
  
  print('📤 [WebUploadChunked] 開始分塊上傳, 總大小: $totalSize bytes, 共 $totalChunks 個分塊, Session: $sessionId');

  String lastResponse = "";

  for (int i = 0; i < totalChunks; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize < totalSize) ? start + chunkSize : totalSize;
    final chunkBlob = blob.slice(start, end);

    final formData = html.FormData();
    formData.appendBlob('video', chunkBlob, fileName);
    formData.append('session_id', sessionId);
    formData.append('chunk_index', i.toString());
    formData.append('total_chunks', totalChunks.toString());
    
    // 將其他欄位（save_video, interviewer, transcript, baseline 等）附加於分塊中
    fields.forEach((key, value) => formData.append(key, value));

    final xhr = html.HttpRequest();
    xhr.open('POST', url);
    xhr.timeout = 60000; // 每個分塊超時設為 60 秒

    final completer = Completer<String>();
    StreamSubscription? progressSub;
    StreamSubscription? loadSub;
    StreamSubscription? errorSub;
    StreamSubscription? timeoutSub;

    if (onProgress != null) {
      progressSub = xhr.upload.onProgress.listen((html.ProgressEvent e) {
        if (e.lengthComputable) {
          final loadedInChunk = e.loaded ?? 0;
          final currentTotalProgress = (start + loadedInChunk) / totalSize;
          onProgress(currentTotalProgress.clamp(0.0, 1.0));
        }
      });
    }

    loadSub = xhr.onLoad.listen((_) {
      if (xhr.status == 200) {
        completer.complete(xhr.responseText ?? '');
      } else {
        completer.completeError('Server error status: ${xhr.status} - ${xhr.responseText}');
      }
    });

    errorSub = xhr.onError.listen((_) {
      completer.completeError('網路錯誤，分塊上傳失敗');
    });

    timeoutSub = xhr.onTimeout.listen((_) {
      completer.completeError('上傳分塊逾時');
    });

    xhr.send(formData);

    try {
      lastResponse = await completer.future;
      print('📦 [WebUploadChunked] 成功上傳分塊 [${i + 1}/$totalChunks]');
    } catch (e) {
      print('❌ [WebUploadChunked] 上傳分塊 [${i + 1}/$totalChunks] 失敗: $e');
      rethrow;
    } finally {
      progressSub?.cancel();
      loadSub?.cancel();
      errorSub?.cancel();
      timeoutSub?.cancel();
    }
  }

  return lastResponse;
}

