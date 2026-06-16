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

  final List<InterviewRecord> _records = [
    InterviewRecord(
      id: 'mock_1',
      studentId: 'Yi', // 這裡是您的使用者名稱
      date: DateTime.now().subtract(const Duration(days: 1)),
      durationSec: 180,
      scores: {
        'overall': 80,
        'confidence': 85,
        'passion': 70,
        'relaxed': 60,
        'nervous': 30,
        'emotion_management': 70, // 100 - 30
        'relevance': 80,
      },
      type: '軟體工程師',
      interviewer: '嚴謹型教授',
      language: '中文',
      aiComment:
          '你在應對技術細節時表現出極高的自信。然而，在談論團隊協作時，語速明顯加快且手勢較多，顯示出稍微的緊張感。整體而言，邏輯非常清晰。',
      aiSuggestion: '建議在談論軟實力時放慢語速，增加眼神接觸；技術題可以多準備一些實際案例的細節。',
      timelineData:
          '[{"t":0.0,"c":80,"n":20,"p":50,"r":50},{"t":1.5,"c":85,"n":15,"p":60,"r":55}]',
      questions: ['請介紹一下你自己', '為什麼選擇我們公司？'],
      interviewName: 'Luminew模擬面試 - 軟體開發',
    ),
    InterviewRecord(
      id: 'mock_2',
      studentId: 'Yi',
      date: DateTime.now().subtract(const Duration(days: 3)),
      durationSec: 120,
      scores: {
        'overall': 72,
        'confidence': 65,
        'passion': 80,
        'relaxed': 40,
        'nervous': 60,
        'emotion_management': 40, // 100 - 60
        'relevance': 72,
      },
      type: '產品經理',
      interviewer: '溫和型業界專家',
      language: '中文',
      aiComment: '表達充滿熱情，對於市場趨勢有獨到見解。但在面對壓力測試題時，放鬆程度降至低點，建議加強應變能力的心理建設。',
      aiSuggestion: '針對挫折經驗題進行更多練習；練習在思考時保持微笑，避免表情過於凝重。',
      timelineData:
          '[{"t":0.0,"c":60,"n":40,"p":70,"r":30},{"t":2.0,"c":65,"n":35,"p":80,"r":40}]',
      questions: ['你遇過最大的挫折是什麼？', '如何處理團隊衝突？'],
      interviewName: '蝦皮 PM 實習面試',
    ),
  ];

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

  List<InterviewRecord> getRecords(String email, {String filter = 'all'}) =>
      _records.where((r) => r.studentId == email).toList();
}

final mockService = MockDataService();
