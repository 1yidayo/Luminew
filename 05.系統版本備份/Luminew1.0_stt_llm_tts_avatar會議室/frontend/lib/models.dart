// fileName: lib/models.dart
import 'dart:convert';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String subscription;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.subscription = 'Free',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['UserID'].toString(),
      name: map['Name'],
      email: map['Email'],
      role: map['Role'],
      subscription: map['Subscription'] ?? 'Free',
    );
  }
}

class Class {
  final String id;
  final String name;
  final String teacherId;
  final String invitationCode;

  Class({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.invitationCode,
  });

  factory Class.fromMap(Map<String, dynamic> map) {
    return Class(
      id: map['ClassID'].toString(),
      name: map['ClassName']?.toString() ?? '',
      teacherId: map['TeacherID'].toString(),
      invitationCode: map['InvitationCode']?.toString() ?? '',
    );
  }
}

class Student {
  final String id;
  final String name;
  final int latestScore;
  final String latestInterviewDate;

  Student({
    required this.id,
    required this.name,
    this.latestScore = 0,
    this.latestInterviewDate = '無紀錄',
  });
}

class InterviewRecord {
  final String id;
  final String studentId;
  final DateTime date;
  final int durationSec;
  final Map<String, int> scores;
  final int _dbOverallScore; // ★ DB 的 OverallScore 欄位 (fallback 用)
  final String type;
  final String interviewer;
  final String language;
  final String privacy;
  final String studentName;
  final String aiComment;
  final String aiSuggestion;
  final String timelineData;
  final String? videoUrl;
  final List<String> questions;
  final String interviewName; // ★ 新增：面試名稱

  InterviewRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.durationSec,
    required this.scores,
    int dbOverallScore = 0,
    required this.type,
    this.timelineData = '[]',
    this.interviewer = 'AI 面試官',
    this.language = '中文',
    this.privacy = 'Private',
    this.studentName = '',
    this.aiComment = '',
    this.aiSuggestion = '',
    this.videoUrl,
    this.questions = const [],
    this.interviewName = '', // ★ 新增：面試名稱
  }) : _dbOverallScore = dbOverallScore;

  // ★ 優先從 ScoresDetail 讀 overall，沒有的話用 DB 的 OverallScore 欄位
  int get overallScore => scores['overall'] ?? _dbOverallScore;

  factory InterviewRecord.fromMap(Map<String, dynamic> map) {
    return InterviewRecord(
      id: map['RecordID']?.toString() ?? '',
      studentId: map['StudentID']?.toString() ?? '',
      date: DateTime.tryParse(map['Date'].toString()) ?? DateTime.now(),
      durationSec: int.tryParse(map['DurationSeconds'].toString()) ?? 0,
      scores: _parseScores(map['ScoresDetail']),
      dbOverallScore: int.tryParse(map['OverallScore']?.toString() ?? '0') ?? 0,
      type: map['Type'] ?? '通用型',
      interviewer: map['Interviewer'] ?? 'AI 面試官',
      language: map['Language'] ?? '中文',
      privacy: map['Privacy'] ?? 'Private',
      studentName: map['StudentName'] ?? '',
      aiComment: map['AIComment'] ?? '',
      aiSuggestion: map['AISuggestion'] ?? '',
      timelineData: map['TimelineData'] ?? '[]',
      videoUrl: map['VideoUrl'],
      questions: _parseQuestions(map['Questions']),
      interviewName: map['InterviewName'] ?? '', // ★ 新增
    );
  }

  // ★ 修正：解析問題列表（先嘗試原始格式，失敗再轉換）
  static List<String> _parseQuestions(dynamic jsonStr) {
    if (jsonStr == null || jsonStr == '') return [];
    if (jsonStr is List) return List<String>.from(jsonStr);
    if (jsonStr is String) {
      // 1. 先嘗試直接解析原始 JSON
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) return List<String>.from(decoded);
      } catch (_) {}
      
      // 2. 失敗的話，嘗試把單引號換成雙引號
      try {
        String clean = jsonStr.replaceAll("'", '"');
        final decoded = jsonDecode(clean);
        if (decoded is List) return List<String>.from(decoded);
      } catch (e) {
        print("⚠️ 解析問題失敗: $e, 原始資料: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}...");
      }
    }
    return [];
  }

  static Map<String, int> _parseScores(dynamic jsonStr) {
    if (jsonStr == null) return {};
    if (jsonStr is Map) {
      return Map<String, int>.from(jsonStr.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0)));
    }
    if (jsonStr is String) {
      if (jsonStr.isEmpty) return {};
      // ★ 修正：如果接到的字串是用單引號包的 (因為 SQL REPLACE 過)，先換回雙引
      String cleanJson = jsonStr.replaceAll("'", '"');
      
      try {
        final decoded = jsonDecode(cleanJson); // 現在應該是標準 JSON 了
        if (decoded is Map) {
           return Map<String, int>.from(decoded.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0)));
        }
        // 如果還是兩層編碼 (有時候會發生)，再解一次
        if (decoded is String) {
           final decoded2 = jsonDecode(decoded);
           if (decoded2 is Map) {
             return Map<String, int>.from(decoded2.map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0)));
           }
        }
      } catch (e) {
        // 如果真的還是壞掉，回傳預設值讓 App 不會當掉
        print("⚠️ 解析分數失敗 (字串: $jsonStr): $e");
        return {'overall': 0};
      }
    }
    return {};
  }
}

class LearningPortfolio {
  final String id;
  final String title;
  final String uploadDate;

  LearningPortfolio({
    required this.id,
    required this.title,
    required this.uploadDate,
  });
}

class Comment {
  final String id;
  final String senderName;
  final String content;
  final String date;

  Comment({
    this.id = '',
    required this.senderName,
    required this.content,
    required this.date,
  });
}

class Invitation {
  final String id;
  final String teacherName;
  final String studentName;
  final String message;
  final String status;
  final String date;

  Invitation({
    this.id = '',
    this.teacherName = '未知老師',
    this.studentName = '未知學生',
    this.message = '',
    this.status = 'Pending',
    this.date = '',
  });
}

class InterviewSlot {
  final String id;
  final String teacherId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;
  final String? bookedByStudentName;

  InterviewSlot({
    required this.id,
    required this.teacherId,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.bookedByStudentName,
  });

  factory InterviewSlot.fromMap(Map<String, dynamic> map) {
    return InterviewSlot(
      id: map['SlotID'].toString(),
      teacherId: map['TeacherID'].toString(),
      startTime: DateTime.parse(map['StartTime'].toString()),
      endTime: DateTime.parse(map['EndTime'].toString()),
      // 相容 SQL Server 的 BIT 類型 (可能回傳 true/false 或 1/0)
      isBooked: map['IsBooked'] == true || map['IsBooked'] == 1,
      bookedByStudentName: map['StudentName'],
    );
  }
}