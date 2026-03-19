import 'dart:async';
import 'models.dart';

class MockDataService {
  final Map<String, List<String>> _chatMessages = {
    'public': ["系統公告：歡迎來到 Luminew！", "老師：記得上傳學習歷程喔！"],
  };

  final List<InterviewRecord> _records = [];

  Stream<List<String>> getChatStream(String chatKey) async* {
    if (!_chatMessages.containsKey(chatKey)) _chatMessages[chatKey] = [];
    while (true) {
      yield List.from(_chatMessages[chatKey]!);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void sendMessage(String msg, String user, String key) {
    if (!_chatMessages.containsKey(key)) _chatMessages[key] = [];
    _chatMessages[key]!.add("${user.split('@')[0]}：$msg");
  }

  void addRecord(InterviewRecord r) => _records.add(r);

  List<InterviewRecord> getRecords(String email) =>
      _records.where((r) => r.studentId == email).toList();
}

final mockService = MockDataService();
