// fileName: lib/sql_service.dart
import 'dart:convert';
import 'dart:math'; // ★ 必須引入，用於生成 6 位數代碼
import 'package:sql_conn/sql_conn.dart';
import 'models.dart';

/// ★ 將 sql_conn 2.0 的回傳值統一轉成 JSON 字串
/// 新版可能回傳 List<Map> 而非 JSON String，需要統一格式
String _toJsonString(dynamic result) {
  if (result == null) return "[]";
  if (result is String) return result.isEmpty ? "[]" : result;
  if (result is List) return jsonEncode(result);
  return result.toString();
}

class SqlService {
  // ★ 請確認您的 IP (模擬器通常是 10.0.2.2)
  static const String _host = "10.0.2.2";
  static const int _port = 1433;
  static const String _dbName = "LuminewDB";
  static const String _user = "sa";
  static const String _pass = "112233";

  // ★ 新版 sql_conn 2.0 需要 connectionId
  static const String _connId = "mainDB";

  // ★ 自行管理連線狀態 (新版沒有 isConnected)
  static bool _connected = false;

  // 連線與重連機制
  static Future<void> connect({bool force = false}) async {
    try {
      if (force) {
        try {
          await SqlConn.disconnect(_connId);
          _connected = false;
        } catch (_) {}
      }
      if (!_connected || force) {
        await SqlConn.connect(
          connectionId: _connId,
          host: _host,
          port: _port,
          database: _dbName,
          username: _user,
          password: _pass,
        );
        _connected = true;
        print("✅ SQL 連線成功");
      }
    } catch (e) {
      _connected = false;
      print("❌ 連線失敗: $e");
      throw e;
    }
  }

  static Future<String> _safeRead(String sql) async {
    try {
      if (!_connected) await connect();
      var result = await SqlConn.read(_connId, sql);
      return _toJsonString(result);
    } catch (e) {
      print("⚠️ 讀取異常，嘗試重連: $e");
      await connect(force: true);
      var result = await SqlConn.read(_connId, sql);
      return _toJsonString(result);
    }
  }

  static Future<void> _safeWrite(String sql) async {
    try {
      if (!_connected) await connect();
      await SqlConn.write(_connId, sql);
    } catch (e) {
      print("⚠️ 寫入異常，嘗試重連: $e");
      await connect(force: true);
      await SqlConn.write(_connId, sql);
    }
  }

  // 除錯用工具
  static Future<String> readDataDebug(String sql) async {
    try {
      if (!_connected) await connect();
      var result = await SqlConn.read(_connId, sql);
      return _toJsonString(result);
    } catch (e) {
      return "Error: $e";
    }
  }

  // ==========================
  // 使用者驗證
  // ==========================
  static Future<AppUser?> login(String email, String password) async {
    String sql =
        "SELECT * FROM Users WHERE Email = '$email' AND PasswordHash = '$password'";
    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return null;
      return AppUser.fromMap(jsonDecode(res)[0]);
    } catch (e) {
      return null;
    }
  }

  static Future<void> registerUser(
    String email,
    String password,
    String name,
    String role,
  ) async {
    String sql =
        "INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES ('$email', '$password', N'$name', '$role')";
    await _safeWrite(sql);
  }

  // ==========================
  // 班級管理 (重點修正)
  // ==========================
  static Future<List<Class>> getTeacherClasses(String email) async {
    String sql =
        "SELECT * FROM Classes WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '$email')";
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List).map((x) => Class.fromMap(x)).toList();
  }

  // ★ 修正版：建立班級 (先查 ID 再寫入，避免 Foreign Key 錯誤)
  static Future<void> createClass(String name, String teacherEmail) async {
    // 1. 先確認使用者存在
    String idSql = "SELECT UserID FROM Users WHERE Email = '$teacherEmail'";
    var idRes = await _safeRead(idSql);

    if (idRes == "[]" || idRes.isEmpty) {
      throw Exception("找不到您的帳號資料 ($teacherEmail)，請嘗試重新登入");
    }

    // 2. 取得 ID
    var teacherId = jsonDecode(idRes)[0]['UserID'];

    // 3. 生成 6 位數亂數代碼
    String code = (Random().nextInt(900000) + 100000).toString();

    // 4. 寫入班級
    String sql =
        "INSERT INTO Classes (ClassName, TeacherID, InvitationCode) VALUES (N'$name', $teacherId, '$code')";
    await _safeWrite(sql);
  }

  static Future<List<Student>> getClassStudents(String classId) async {
    String sql =
        "SELECT u.UserID, u.Name FROM Users u JOIN ClassMembers cm ON u.UserID = cm.StudentID WHERE cm.ClassID = $classId";
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map((j) => Student(id: j['UserID'].toString(), name: j['Name']))
        .toList();
  }

  static Future<List<Class>> getStudentClasses(String email) async {
    String sql =
        "SELECT c.* FROM Classes c JOIN ClassMembers cm ON c.ClassID = cm.ClassID WHERE cm.StudentID = (SELECT UserID FROM Users WHERE Email = '$email')";
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List).map((x) => Class.fromMap(x)).toList();
  }

  static Future<Class?> joinClass(String code, String email) async {
    String findSql = "SELECT * FROM Classes WHERE InvitationCode = '$code'";
    var res = await _safeRead(findSql);
    if (res == "[]" || res.isEmpty) throw Exception("找不到班級，請確認代碼是否正確");
    Class cls = Class.fromMap(jsonDecode(res)[0]);

    String check = await _safeRead(
      "SELECT * FROM ClassMembers WHERE ClassID = ${cls.id} AND StudentID = (SELECT UserID FROM Users WHERE Email = '$email')",
    );
    if (check != "[]" && check.isNotEmpty) throw Exception("您已加入此班級");

    await _safeWrite(
      "INSERT INTO ClassMembers (ClassID, StudentID) VALUES (${cls.id}, (SELECT UserID FROM Users WHERE Email = '$email'))",
    );
    return cls;
  }

  // ==========================
  // 面試紀錄
  // ==========================
  static Future<List<InterviewRecord>> getRecords(
    String userId,
    String filter,
  ) async {
    // ★ 修改：jTDS 會把 NVARCHAR(MAX) 當成 CLOB 物件回傳
    // 解法：先 CAST 成 NVARCHAR(4000)，再 REPLACE 引號避免 JSON 解析失敗
    String safeSelect = "RecordID, StudentID, Date, DurationSeconds, Type, Interviewer, Language, OverallScore, "
        "REPLACE(CAST(ScoresDetail AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as ScoresDetail, "
        "Privacy, "
        "REPLACE(CAST(AIComment AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as AIComment, "
        "REPLACE(CAST(AISuggestion AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as AISuggestion, "
        "REPLACE(CAST(TimelineData AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as TimelineData, "
        "VideoUrl, "
        "REPLACE(CAST(Questions AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as Questions, "
        "InterviewName";

    String sql = userId.contains('@')
        ? "SELECT $safeSelect FROM InterviewRecords WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '$userId') ORDER BY Date DESC"
        : "SELECT $safeSelect FROM InterviewRecords WHERE StudentID = '$userId' ORDER BY Date DESC";

    var res = await _safeRead(sql);
    if (res.isEmpty || res == "[]") return [];
    List<dynamic> list = jsonDecode(res);
    return list.map((d) => InterviewRecord.fromMap(d)).toList();
  }

  // ★ 新增：刪除面試紀錄
  static Future<void> deleteRecord(String recordId) async {
    // 先刪除相關留言 (避免外鍵衝突)，如果 Comments 表不存在就跳過
    try {
      await _safeWrite("DELETE FROM RecordComments WHERE RecordID = $recordId");
    } catch (e) {
      print("⚠️ 刪除留言時出錯 (可能表不存在): $e");
      // 繼續執行，不中斷
    }
    // 再刪除紀錄本身
    await _safeWrite("DELETE FROM InterviewRecords WHERE RecordID = $recordId");
  }

  static Future<void> saveRecord(InterviewRecord r) async {
    String scoresJson = jsonEncode(r.scores);
    String safeComment = r.aiComment.replaceAll("'", "''");
    String safeSuggestion = r.aiSuggestion.replaceAll("'", "''");
    String safeTimeline = r.timelineData.replaceAll("'", "''");
    String questionsJson = jsonEncode(r.questions);
    String safeName = r.interviewName.replaceAll("'", "''"); // ★ 新增
    String sql = 
        "INSERT INTO InterviewRecords ("
        "  StudentID, "
        "  Date, "
        "  DurationSeconds, "
        "  Type, "
        "  Interviewer, "
        "  Language, "
        "  OverallScore, "
        "  ScoresDetail, "
        "  Privacy, "
        "  AIComment, "
        "  AISuggestion, "
        "  TimelineData, "
        "  VideoUrl, "
        "  Questions, "
        "  InterviewName" // ★ 新增
        ") "
        "VALUES ("
        "  (SELECT UserID FROM Users WHERE Email = '${r.studentId}'), " // StudentID (子查詢)
        "  GETDATE(), "           // Date
        "  ${r.durationSec}, "    // DurationSeconds
        "  N'${r.type}', "        // Type (注意 N 前綴)
        "  N'${r.interviewer}', " // Interviewer
        "  N'${r.language}', "    // Language
        "  ${r.overallScore}, "   // OverallScore
        "  '$scoresJson', "       // ScoresDetail
        "  '${r.privacy}', "      // Privacy
        "  N'$safeComment', "     // AIComment
        "  N'$safeSuggestion', "  // AISuggestion
        "  '$safeTimeline', "     // TimelineData
        "  '${r.videoUrl}', "     // VideoUrl
        "  N'$questionsJson', "   // Questions
        "  N'$safeName'"          // ★ 新增 InterviewName
        ")";
    await _safeWrite(sql);
  }


  // ==========================
  // 邀請與時段
  // ==========================
  static Future<void> sendInvitation(
    String teacherEmail,
    String studentId,
    String msg,
  ) async {
    String sql =
        "INSERT INTO Invitations (TeacherID, StudentID, Message) VALUES ((SELECT UserID FROM Users WHERE Email = '$teacherEmail'), $studentId, N'$msg')";
        await _safeWrite(sql);
  }

  static Future<void> sendBulkInvitations(
    String teacherEmail,
    List<String> studentIds,
    String msg,
  ) async {
    if (studentIds.isEmpty) return;
    String teacherIdSql =
        "(SELECT UserID FROM Users WHERE Email = '$teacherEmail')";
    for (String sid in studentIds) {
      String checkSql =
          "SELECT * FROM Invitations WHERE TeacherID = $teacherIdSql AND StudentID = $sid AND Status = 'Pending'";
      var check = await _safeRead(checkSql);
      if (check == "[]" || check.isEmpty) {
        String sql =
            "INSERT INTO Invitations (TeacherID, StudentID, Message, SentAt, Status) VALUES ($teacherIdSql, $sid, N'$msg', GETDATE(), 'Pending')";
        await _safeWrite(sql);
      }
    }
  }

  static Future<List<Invitation>> getInvitations(
    String userId,
    bool isTeacher,
  ) async {
    String sql;
    if (isTeacher) {
      sql =
          "SELECT i.*, u.Name as StudentName FROM Invitations i JOIN Users u ON i.StudentID = u.UserID WHERE i.TeacherID = $userId ORDER BY i.SentAt DESC";
    } else {
      sql =
          "SELECT i.*, u.Name as TeacherName FROM Invitations i JOIN Users u ON i.TeacherID = u.UserID WHERE i.StudentID = $userId ORDER BY i.SentAt DESC";
    }
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map(
          (x) => Invitation(
            id: x['InvitationID'].toString(),
            teacherName: x['TeacherName'] ?? '',
            studentName: x['StudentName'] ?? '',
            message: x['Message'],
            status: x['Status'],
            date: x['SentAt'].toString(),
          ),
        )
        .toList();
  }

  static Future<void> updateInvitation(String id, String status) async {
    await _safeWrite(
      "UPDATE Invitations SET Status = '$status' WHERE InvitationID = $id",
    );
  }

  static Future<void> addInterviewSlot(
    String teacherEmail,
    DateTime start,
    DateTime end,
  ) async {
    String sql =
        "INSERT INTO InterviewSlots (TeacherID, StartTime, EndTime, IsBooked) VALUES ((SELECT UserID FROM Users WHERE Email = '$teacherEmail'), '${start.toIso8601String()}', '${end.toIso8601String()}', 0)";
    await _safeWrite(sql);
  }

  static Future<List<InterviewSlot>> getTeacherSlots(
    String teacherEmail,
  ) async {
    String sql =
        "SELECT s.*, u.Name as StudentName FROM InterviewSlots s LEFT JOIN Users u ON s.BookedByStudentID = u.UserID WHERE s.TeacherID = (SELECT UserID FROM Users WHERE Email = '$teacherEmail') ORDER BY s.StartTime ASC";
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map((x) => InterviewSlot.fromMap(x))
        .toList();
  }

  static Future<void> deleteSlot(String slotId) async {
    await _safeWrite("DELETE FROM InterviewSlots WHERE SlotID = $slotId");
  }

  static Future<List<InterviewSlot>> getAvailableSlots(
    String teacherEmail,
  ) async {
    String sql =
        "SELECT * FROM InterviewSlots WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '$teacherEmail') AND IsBooked = 0 AND StartTime > GETDATE() ORDER BY StartTime ASC";
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map((x) => InterviewSlot.fromMap(x))
        .toList();
  }

  static Future<void> bookSlot(String slotId, String studentEmail) async {
    String checkSql =
        "SELECT IsBooked FROM InterviewSlots WHERE SlotID = $slotId";
    var res = await _safeRead(checkSql);
    if (res.contains("true") || res.contains(":1") || res.contains(": 1")) {
      throw Exception("時段已被搶走");
    }
    String sql =
        "UPDATE InterviewSlots SET IsBooked = 1, BookedByStudentID = (SELECT UserID FROM Users WHERE Email = '$studentEmail') WHERE SlotID = $slotId";
    await _safeWrite(sql);
  }

  // 評論與學習歷程
  static Future<List<Comment>> getComments(String recordId) async {
    String sql =
        "SELECT c.*, u.Name as SenderName FROM RecordComments c JOIN Users u ON c.SenderID = u.UserID WHERE c.RecordID = $recordId ORDER BY c.SentAt ASC";
    try {
      var res = await _safeRead(sql);
      if (res.isEmpty || res == "[]") return [];
      return (jsonDecode(res) as List)
          .map(
            (x) => Comment(
              id: x['CommentID'].toString(),
              senderName: x['SenderName'],
              content: x['Content'],
              date: x['SentAt'].toString(),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> sendComment(
    String recordId,
    String userEmail,
    String content,
  ) async {
    String userIdSql = "(SELECT UserID FROM Users WHERE Email = '$userEmail')";
    String sql =
        "INSERT INTO RecordComments (RecordID, SenderID, Content) VALUES ($recordId, $userIdSql, N'$content')";
    await _safeWrite(sql);
  }

  static Future<void> updatePrivacy(String recordId, String privacy) async {
    await _safeWrite(
      "UPDATE InterviewRecords SET Privacy = '$privacy' WHERE RecordID = $recordId",
    );
  }

  static Future<List<LearningPortfolio>> getPortfolios(String email) async {
    String sql =
        "SELECT * FROM LearningPortfolios WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '$email') ORDER BY UploadDate DESC";
    var res = await _safeRead(sql);
    if (res == "[]" || res.isEmpty) return [];
    return (jsonDecode(res) as List)
        .map(
          (x) => LearningPortfolio(
            id: x['PortfolioID'].toString(),
            title: x['Title'],
            uploadDate: x['UploadDate'].toString(),
          ),
        )
        .toList();
  }

  static Future<void> addPortfolio(String email, String title) async {
    await _safeWrite(
      "INSERT INTO LearningPortfolios (StudentID, Title) VALUES ((SELECT UserID FROM Users WHERE Email = '$email'), N'$title')",
    );
  }
}