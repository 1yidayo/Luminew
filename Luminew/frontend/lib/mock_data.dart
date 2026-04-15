import 'dart:async';
import 'models.dart';

class ForumPost {
  final String id;
  final String title;
  final String content;
  final String author;
  final DateTime timestamp;
  final List<String> tags;
  final int replyCount;
  bool isFavorite;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.timestamp,
    required this.tags,
    this.replyCount = 0,
    this.isFavorite = false,
  });
}

class MockDataService {
  final Map<String, List<String>> _chatMessages = {
    'public': ["系統公告：歡迎來到 Luminew！", "老師：記得上傳學習歷程喔！"],
  };

  final List<ForumPost> _forumPosts = [
    ForumPost(
      id: '1',
      title: 'Luminew模擬面試心得分享',
      content: '今天跟Luminew AI練了三場，感覺對於行為問題的回答流暢很多...',
      author: '學長小明',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      tags: ['#面試心得', '#Luminew'],
      replyCount: 12,
      isFavorite: true,
    ),
    ForumPost(
      id: '2',
      title: '如何優化自己的學習歷程 PDF？',
      content: 'AI 給我的分析建議非常中肯，特別是關於字體大小與排版的建議...',
      author: '設計系多多',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      tags: ['#學習歷程', '#排版建議'],
      replyCount: 5,
    ),
    ForumPost(
      id: '3',
      title: 'Vue vs React：面試時該怎麼選？',
      content: '最近很多同學在問這個問題，我整理了一些面試官會關注的重點...',
      author: '小花',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      tags: ['#技術請益', '#職涯規劃'],
      replyCount: 28,
    ),
  ];

  final List<InterviewRecord> _records = [];

  // 論壇相關方法
  List<ForumPost> getForumPosts() => _forumPosts;

  void toggleFavorite(String postId) {
    final post = _forumPosts.firstWhere((p) => p.id == postId);
    post.isFavorite = !post.isFavorite;
  }

  // 聊天相關方法
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
