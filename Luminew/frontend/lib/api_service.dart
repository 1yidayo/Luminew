// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// ========================================================
/// 神不知鬼不覺的完美替身：ApiService
/// 直接取代原本危險的 sql_service.dart，轉接所有邏輯到後端伺服器！
/// ========================================================
class ApiService {
  // TODO: 將這裡換成你從 main.py 啟動後拿到的 https://xxxx.ngrok.app
  static String rootUrl = "http://140.136.155.145:8000";
  static String baseUrl = "$rootUrl/api/db";

  static Future<http.Response> _post(String endpoint, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body)
    );
    if (res.statusCode != 200) {
      String detail = 'API Server Error';
      try { detail = jsonDecode(res.body)['detail'] ?? detail; } catch(e) {}
      throw Exception(detail);
    }
    return res;
  }

  // ==========================
  // 使用者驗證
  // ==========================
  static Future<AppUser?> login(String email, String password) async {
    try {
      final res = await _post('/login', {'email': email, 'password': password});
      final data = jsonDecode(res.body);
      if (data == null || (data is List && data.isEmpty)) return null;
      return AppUser.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  static Future<void> registerUser(String email, String password, String name, String role) async {
    await _post('/registerUser', {'email': email, 'password': password, 'name': name, 'role': role});
  }

  // ==========================
  // 班級管理
  // ==========================
  static Future<List<Class>> getTeacherClasses(String email) async {
    final res = await _post('/getTeacherClasses', {'email': email});
    final List list = jsonDecode(res.body);
    return list.map((x) => Class.fromMap(x)).toList();
  }

  static Future<void> createClass(String name, String teacherEmail) async {
    await _post('/createClass', {'name': name, 'teacherEmail': teacherEmail});
  }

  static Future<List<Student>> getClassStudents(String classId) async {
    final res = await _post('/getClassStudents', {'classId': classId});
    final List list = jsonDecode(res.body);
    return list.map((j) => Student(id: j['id'].toString(), name: j['name'])).toList();
  }

  static Future<List<Class>> getStudentClasses(String email) async {
    final res = await _post('/getStudentClasses', {'email': email});
    final List list = jsonDecode(res.body);
    return list.map((x) => Class.fromMap(x)).toList();
  }

  static Future<Class?> joinClass(String code, String email) async {
    final res = await _post('/joinClass', {'code': code, 'email': email});
    return Class.fromMap(jsonDecode(res.body));
  }

  // ==========================
  // 面試紀錄
  // ==========================
  static Future<List<InterviewRecord>> getRecords(String userId, String filter) async {
    final res = await _post('/getRecords', {'userId': userId, 'filter': filter});
    final List list = jsonDecode(res.body);
    return list.map((d) {
      if (d['ScoresDetail'] is String) d['ScoresDetail'] = d['ScoresDetail'];
      return InterviewRecord.fromMap(d);
    }).toList();
  }

  static Future<void> deleteRecord(String recordId) async {
    await _post('/deleteRecord', {'recordId': recordId});
  }

  static Future<String?> saveRecord(InterviewRecord r) async {
    final res = await _post('/saveRecord', {
      'studentId': r.studentId,
      'durationSec': r.durationSec,
      'type': r.type,
      'interviewer': r.interviewer,
      'language': r.language,
      'overallScore': r.overallScore,
      'scores': r.scores,
      'privacy': r.privacy,
      'aiComment': r.aiComment,
      'aiSuggestion': r.aiSuggestion,
      'timelineData': r.timelineData,
      'videoUrl': r.videoUrl,
      'questions': r.questions,
      'interviewName': r.interviewName,
    });
    final data = jsonDecode(res.body);
    return data['recordId']?.toString();
  }

  // ==========================
  // 邀請與時段
  // ==========================
  static Future<void> sendInvitation(String teacherEmail, String studentId, String msg) async {
    await _post('/sendInvitation', {'teacherEmail': teacherEmail, 'studentId': studentId, 'msg': msg});
  }

  static Future<void> sendBulkInvitations(String teacherEmail, List<String> studentIds, String msg) async {
    await _post('/sendBulkInvitations', {'teacherEmail': teacherEmail, 'studentIds': studentIds, 'msg': msg});
  }

  static Future<List<Invitation>> getInvitations(String userId, bool isTeacher) async {
    final res = await _post('/getInvitations', {'userId': userId, 'isTeacher': isTeacher});
    final List list = jsonDecode(res.body);
    return list.map((x) => Invitation(
      id: x['InvitationID'].toString(),
      teacherName: x['TeacherName'] ?? '',
      studentName: x['StudentName'] ?? '',
      message: x['Message'],
      status: x['Status'],
      date: x['SentAt'].toString(),
    )).toList();
  }

  static Future<void> updateInvitation(String id, String status) async {
    await _post('/updateInvitation', {'id': id, 'status': status});
  }

  static Future<void> addInterviewSlot(String teacherEmail, DateTime start, DateTime end) async {
    await _post('/addInterviewSlot', {
      'teacherEmail': teacherEmail,
      'start': start.toIso8601String(),
      'end': end.toIso8601String()
    });
  }

  static Future<List<InterviewSlot>> getTeacherSlots(String teacherEmail) async {
    final res = await _post('/getTeacherSlots', {'email': teacherEmail});
    return (jsonDecode(res.body) as List).map((x) => InterviewSlot.fromMap(x)).toList();
  }

  static Future<void> deleteSlot(String slotId) async {
    await _post('/deleteSlot', {'slotId': slotId});
  }

  static Future<List<InterviewSlot>> getAvailableSlots(String teacherEmail) async {
    final res = await _post('/getAvailableSlots', {'email': teacherEmail});
    return (jsonDecode(res.body) as List).map((x) => InterviewSlot.fromMap(x)).toList();
  }

  static Future<void> bookSlot(String slotId, String studentEmail) async {
    await _post('/bookSlot', {'slotId': slotId, 'studentEmail': studentEmail});
  }

  // ==========================
  // 評論與學習歷程
  // ==========================
  static Future<List<Comment>> getComments(String recordId) async {
    final res = await _post('/getComments', {'recordId': recordId});
    return (jsonDecode(res.body) as List).map((x) => Comment(
      id: x['CommentID'].toString(),
      senderName: x['SenderName'],
      content: x['Content'],
      date: x['SentAt'].toString(),
    )).toList();
  }

  static Future<void> sendComment(String recordId, String userEmail, String content) async {
    await _post('/sendComment', {'recordId': recordId, 'userEmail': userEmail, 'content': content});
  }

  static Future<void> updatePrivacy(String recordId, String privacy) async {
    await _post('/updatePrivacy', {'recordId': recordId, 'privacy': privacy});
  }

  static Future<List<LearningPortfolio>> getPortfolios(String email) async {
    final res = await _post('/getPortfolios', {'email': email});
    return (jsonDecode(res.body) as List).map((x) => LearningPortfolio(
      id: x['PortfolioID'].toString(),
      title: x['Title'],
      uploadDate: x['UploadDate'].toString(),
    )).toList();
  }

  static Future<void> addPortfolio(String email, String title) async {
    await _post('/addPortfolio', {'email': email, 'title': title});
  }
}
