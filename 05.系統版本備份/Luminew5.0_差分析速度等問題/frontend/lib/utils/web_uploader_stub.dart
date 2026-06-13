// web_recorder_stub.dart - 非 Web 平台的空殼
import 'dart:async';

class WebVideoRecorder {
  Future<void> start() async =>
      throw UnsupportedError('WebVideoRecorder only supported on web');
  Future<String?> stop() async =>
      throw UnsupportedError('WebVideoRecorder only supported on web');
  void dispose() {}
}

Future<String> uploadVideoWeb(
  String blobUrl,
  String fileName,
  String url,
  Map<String, String> fields, {
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('uploadVideoWeb only supported on web');
}
