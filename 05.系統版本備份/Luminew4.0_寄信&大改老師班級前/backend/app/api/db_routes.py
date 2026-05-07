from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import random
import json
from app.database.db import execute_read, execute_write

router = APIRouter()

# --- 1. 使用者驗證 ---
class LoginReq(BaseModel): email: str; password: str
@router.post("/login")
def login(req: LoginReq):
    print(f"📥 [Login] 收到登入請求: Email='{req.email}'") # ★ 加入追蹤日誌
    sql = f"SELECT * FROM Users WHERE Email = '{req.email}' AND PasswordHash = '{req.password}'"
    res = execute_read(sql)
    if res:
        print(f"✅ [Login] 驗證成功: {req.email}")
    else:
        print(f"⚠️ [Login] 驗證失敗: {req.email}")
    return res[0] if res else None

class RegisterReq(BaseModel): email: str; password: str; name: str; role: str
@router.post("/registerUser")
def registerUser(req: RegisterReq):
    sql = f"INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES ('{req.email}', '{req.password}', N'{req.name}', '{req.role}')"
    execute_write(sql)
    return {"status": "ok"}

# --- 新增：更新個人資料 ---
class UpdateProfileReq(BaseModel):
    email: str
    name: str

@router.post("/updateUserProfile")
def updateUserProfile(req: UpdateProfileReq):
    """
    實作個人資料更新，目前支援姓名修改
    """
    sql = f"UPDATE Users SET Name = N'{req.name}' WHERE Email = '{req.email}'"
    execute_write(sql)
    return {"status": "ok"}

# --- 2. 班級管理 ---
class EmailReq(BaseModel): email: str
@router.post("/getTeacherClasses")
def getTeacherClasses(req: EmailReq):
    sql = f"SELECT * FROM Classes WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '{req.email}')"
    return execute_read(sql)

class CreateClassReq(BaseModel): name: str; teacherEmail: str
@router.post("/createClass")
def createClass(req: CreateClassReq):
    idRes = execute_read(f"SELECT UserID FROM Users WHERE Email = '{req.teacherEmail}'")
    if not idRes: raise HTTPException(404, "User not found")
    code = str(random.randint(100000, 999999))
    sql = f"INSERT INTO Classes (ClassName, TeacherID, InvitationCode) VALUES (N'{req.name}', {idRes[0]['UserID']}, '{code}')"
    execute_write(sql)
    return {"status": "ok"}

class ClassIdReq(BaseModel): classId: str
@router.post("/getClassStudents")
def getClassStudents(req: ClassIdReq):
    sql = f"SELECT u.UserID as id, u.Name as name FROM Users u JOIN ClassMembers cm ON u.UserID = cm.StudentID WHERE cm.ClassID = {req.classId}"
    return execute_read(sql)

@router.post("/getStudentClasses")
def getStudentClasses(req: EmailReq):
    sql = f"SELECT c.* FROM Classes c JOIN ClassMembers cm ON c.ClassID = cm.ClassID WHERE cm.StudentID = (SELECT UserID FROM Users WHERE Email = '{req.email}')"
    return execute_read(sql)

class JoinClassReq(BaseModel): code: str; email: str
@router.post("/joinClass")
def joinClass(req: JoinClassReq):
    res = execute_read(f"SELECT * FROM Classes WHERE InvitationCode = '{req.code}'")
    if not res: raise HTTPException(404, "找不到班級")
    cls = res[0]
    check = execute_read(f"SELECT * FROM ClassMembers WHERE ClassID = {cls['ClassID']} AND StudentID = (SELECT UserID FROM Users WHERE Email = '{req.email}')")
    if check: raise HTTPException(400, "您已加入此班級")
    execute_write(f"INSERT INTO ClassMembers (ClassID, StudentID) VALUES ({cls['ClassID']}, (SELECT UserID FROM Users WHERE Email = '{req.email}'))")
    return cls

# --- 3. 面試紀錄 ---
class GetRecordsReq(BaseModel): userId: str; filter: str
@router.post("/getRecords")
def getRecords(req: GetRecordsReq):
    print(f"🔍 [GetRecords] 診斷模式啟動: UserID='{req.userId}'")
    safeSelect = "RecordID, StudentID, Date, DurationSeconds, Type, Interviewer, Language, OverallScore, CAST(ScoresDetail AS NVARCHAR(4000)) as ScoresDetail, Privacy, CAST(AIComment AS NVARCHAR(4000)) as AIComment, CAST(AISuggestion AS NVARCHAR(4000)) as AISuggestion, CAST(TimelineData AS NVARCHAR(4000)) as TimelineData, VideoUrl, CAST(Questions AS NVARCHAR(4000)) as Questions, InterviewName"
    
    # [診斷日誌 1] 掃描全表前 10 筆數據，看看到底存了什麼
    try:
        full_scan = execute_read("SELECT TOP 10 RecordID, StudentID FROM InterviewRecords ORDER BY Date DESC")
        print(f"📊 [診斷] 全表最近 10 筆 StudentID: {[(r['RecordID'], r['StudentID']) for r in full_scan]}")
    except: pass

    try:
        # 單一 SQL：同時比對 StudentID 是 ID 數字、Email 字串，或是對應 Email 的 UserID
        sql = f"""
        SELECT {safeSelect} FROM InterviewRecords 
        WHERE StudentID = '{req.userId}'
        OR StudentID = '{req.userId.strip()}'
        OR StudentID = (SELECT CAST(UserID AS NVARCHAR) FROM Users WHERE Email = '{req.userId}')
        OR (ISNUMERIC('{req.userId}') = 1 AND StudentID = CAST('{req.userId}' AS INT))
        ORDER BY Date DESC
        """
        res = execute_read(sql)
        print(f"✅ [GetRecords] 查詢成功，找到 {len(res)} 筆紀錄")
        return res
    except Exception as e:
        print(f"❌ [GetRecords] 查詢失敗: {e}")
        return []

class RecordIdReq(BaseModel): recordId: str
@router.post("/deleteRecord")
def deleteRecord(req: RecordIdReq):
    try: execute_write(f"DELETE FROM RecordComments WHERE RecordID = '{req.recordId}'")
    except: pass
    execute_write(f"DELETE FROM InterviewRecords WHERE RecordID = '{req.recordId}'")
    return {"status": "ok"}

class SaveRecordReq(BaseModel):
    studentId: str; durationSec: int; type: str; interviewer: str; language: str; overallScore: int; scores: dict; privacy: str; aiComment: str; aiSuggestion: str; timelineData: str; videoUrl: str; questions: list; interviewName: str
@router.post("/saveRecord")
def saveRecord(req: SaveRecordReq):
    # 1. 先確認使用者是否存在，並取得 UserID
    safeEmail = req.studentId.replace("'", "''")
    userRes = execute_read(f"SELECT UserID FROM Users WHERE Email = '{safeEmail}'")
    if not userRes:
        print(f"⚠️ [SaveRecord] 找不到使用者 Email: {req.studentId}")
        raise HTTPException(
            status_code=404, 
            detail=f"資料庫中找不到帳號 {req.studentId}，請確認是否已註冊或正確登入。"
        )
    
    userId = userRes[0]['UserID']
    print(f"✅ [SaveRecord] 準備為 UserID: {userId} ({req.studentId}) 儲存紀錄")

    # 2. 準備安全數據
    scoresJson = json.dumps(req.scores).replace("'", "''")
    safeComment = req.aiComment.replace("'", "''")
    safeSuggestion = req.aiSuggestion.replace("'", "''")
    safeTimeline = req.timelineData.replace("'", "''")
    questionsJson = json.dumps(req.questions).replace("'", "''")
    safeType = req.type.replace("'", "''")
    safeInterviewer = req.interviewer.replace("'", "''")
    safeLang = req.language.replace("'", "''")
    safePrivacy = req.privacy.replace("'", "''")
    safeVideoUrl = req.videoUrl.replace("'", "''")
    safeName = req.interviewName.replace("'", "''")

    # 3. 執行插入 (使用剛剛取得的 userId)
    sql = f"""
    INSERT INTO InterviewRecords (
        StudentID, Date, DurationSeconds, Type, Interviewer, Language, 
        OverallScore, ScoresDetail, Privacy, AIComment, AISuggestion, 
        TimelineData, VideoUrl, Questions, InterviewName
    )
    OUTPUT INSERTED.RecordID
    VALUES (
        {userId}, GETDATE(), {req.durationSec}, N'{safeType}', N'{safeInterviewer}', 
        N'{safeLang}', {req.overallScore}, '{scoresJson}', N'{safePrivacy}', 
        N'{safeComment}', N'{safeSuggestion}', '{safeTimeline}', 
        N'{safeVideoUrl}', N'{questionsJson}', N'{safeName}'
    )
    """
    
    try:
        res = execute_read(sql)
        if res:
            newId = res[0]['RecordID']
            print(f"✨ [SaveRecord] 成功建立紀錄 ID: {newId}")
            # UI Refinement: Radar Chart configuration
            # radarShape: RadarShape.circle, 
            # radarBorderData: const BorderSide(color: Colors.transparent),
            # radarBackgroundColor: Colors.transparent, // 強制全透明
            # titlePositionPercentageOffset: 0.1, 
            return {"status": "ok", "recordId": str(newId)}
        else:
            raise Exception("SQL 執行成功但未傳回 RecordID (INSERTED.RecordID)")
    except Exception as e:
        print(f"❌ [SaveRecord] 資料庫寫入異常: {e}")
        raise HTTPException(status_code=500, detail=f"伺服器資料庫寫入失敗: {e}")

# --- 4. 邀請與時段 ---
class SendInvitationReq(BaseModel): teacherEmail: str; studentId: str; msg: str
@router.post("/sendInvitation")
def sendInvitation(req: SendInvitationReq):
    execute_write(f"INSERT INTO Invitations (TeacherID, StudentID, Message) VALUES ((SELECT UserID FROM Users WHERE Email = '{req.teacherEmail}'), {req.studentId}, N'{req.msg}')")
    return {"status": "ok"}

class SendBulkReq(BaseModel): teacherEmail: str; studentIds: List[str]; msg: str
@router.post("/sendBulkInvitations")
def sendBulkInvitations(req: SendBulkReq):
    if not req.studentIds: return {"status": "ok"}
    for sid in req.studentIds:
        check = execute_read(f"SELECT * FROM Invitations WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '{req.teacherEmail}') AND StudentID = {sid} AND Status = 'Pending'")
        if not check:
            execute_write(f"INSERT INTO Invitations (TeacherID, StudentID, Message, SentAt, Status) VALUES ((SELECT UserID FROM Users WHERE Email = '{req.teacherEmail}'), {sid}, N'{req.msg}', GETDATE(), 'Pending')")
    return {"status": "ok"}

class GetInvitationsReq(BaseModel): userId: str; isTeacher: bool
@router.post("/getInvitations")
def getInvitations(req: GetInvitationsReq):
    if req.isTeacher:
        sql = f"SELECT i.*, u.Name as StudentName FROM Invitations i JOIN Users u ON i.StudentID = u.UserID WHERE i.TeacherID = {req.userId} ORDER BY i.SentAt DESC"
    else:
        sql = f"SELECT i.*, u.Name as TeacherName FROM Invitations i JOIN Users u ON i.TeacherID = u.UserID WHERE i.StudentID = {req.userId} ORDER BY i.SentAt DESC"
    res = execute_read(sql)
    for r in res:
        r['TeacherName'] = r.get('TeacherName', '')
        r['StudentName'] = r.get('StudentName', '')
    return res

class UpdateInvReq(BaseModel): id: str; status: str
@router.post("/updateInvitation")
def updateInvitation(req: UpdateInvReq):
    execute_write(f"UPDATE Invitations SET Status = '{req.status}' WHERE InvitationID = '{req.id}'")
    return {"status": "ok"}

class AddSlotReq(BaseModel): teacherEmail: str; start: str; end: str
@router.post("/addInterviewSlot")
def addInterviewSlot(req: AddSlotReq):
    execute_write(f"INSERT INTO InterviewSlots (TeacherID, StartTime, EndTime, IsBooked) VALUES ((SELECT UserID FROM Users WHERE Email = '{req.teacherEmail}'), '{req.start}', '{req.end}', 0)")
    return {"status": "ok"}

@router.post("/getTeacherSlots")
def getTeacherSlots(req: EmailReq):
    return execute_read(f"SELECT s.*, u.Name as StudentName FROM InterviewSlots s LEFT JOIN Users u ON s.BookedByStudentID = u.UserID WHERE s.TeacherID = (SELECT UserID FROM Users WHERE Email = '{req.email}') ORDER BY s.StartTime ASC")

class SlotIdReq(BaseModel): slotId: str
@router.post("/deleteSlot")
def deleteSlot(req: SlotIdReq):
    execute_write(f"DELETE FROM InterviewSlots WHERE SlotID = '{req.slotId}'")
    return {"status": "ok"}

@router.post("/getAvailableSlots")
def getAvailableSlots(req: EmailReq):
    return execute_read(f"SELECT * FROM InterviewSlots WHERE TeacherID = (SELECT UserID FROM Users WHERE Email = '{req.email}') AND IsBooked = 0 AND StartTime > GETDATE() ORDER BY StartTime ASC")

class BookSlotReq(BaseModel): slotId: str; studentEmail: str
@router.post("/bookSlot")
def bookSlot(req: BookSlotReq):
    res = execute_read(f"SELECT IsBooked FROM InterviewSlots WHERE SlotID = {req.slotId}")
    if res and res[0].get('IsBooked') in [True, 1]: raise HTTPException(400, "時段已被搶走")
    execute_write(f"UPDATE InterviewSlots SET IsBooked = 1, BookedByStudentID = (SELECT UserID FROM Users WHERE Email = '{req.studentEmail}') WHERE SlotID = {req.slotId}")
    return {"status": "ok"}

# --- 5. 評論與學習歷程 ---
@router.post("/getComments")
def getComments(req: RecordIdReq):
    return execute_read(f"SELECT c.*, u.Name as SenderName FROM RecordComments c JOIN Users u ON c.SenderID = u.UserID WHERE c.RecordID = '{req.recordId}' ORDER BY c.SentAt ASC")

class SendCommentReq(BaseModel): recordId: str; userEmail: str; content: str
@router.post("/sendComment")
def sendComment(req: SendCommentReq):
    execute_write(f"INSERT INTO RecordComments (RecordID, SenderID, Content) VALUES ('{req.recordId}', (SELECT UserID FROM Users WHERE Email = '{req.userEmail}'), N'{req.content}')")
    return {"status": "ok"}

class UpdatePrivacyReq(BaseModel): recordId: str; privacy: str
@router.post("/updatePrivacy")
def updatePrivacy(req: UpdatePrivacyReq):
    execute_write(f"UPDATE InterviewRecords SET Privacy = '{req.privacy}' WHERE RecordID = '{req.recordId}'")
    return {"status": "ok"}


@router.post("/getPortfolios")
def getPortfolios(req: EmailReq):
    return execute_read(f"SELECT * FROM LearningPortfolios WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '{req.email}') ORDER BY UploadDate DESC")

class AddPortfolioReq(BaseModel): email: str; title: str
@router.post("/addPortfolio")
def addPortfolio(req: AddPortfolioReq):
    execute_write(f"INSERT INTO LearningPortfolios (StudentID, Title) VALUES ((SELECT UserID FROM Users WHERE Email = '{req.email}'), N'{req.title}')")
    return {"status": "ok"}

# --- EMAIL 發送路由 ---
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.image import MIMEImage
import base64

class SendEmailReq(BaseModel):
    recipientEmail: str
    studentName: str
    overallScore: int
    comment: str
    suggestion: str
    timelineText: str
    attachmentBase64: Optional[str] = None

@router.post("/send_email")
def send_email(req: SendEmailReq):
    try:
        sender_email = os.getenv("SMTP_EMAIL")
        sender_pwd = os.getenv("SMTP_PASSWORD")
        if not sender_email or not sender_pwd:
             raise HTTPException(status_code=500, detail="Server SMTP configuration missing")

        subject = f"[Luminew] {req.studentName} 的 AI 面試分析報告"
        body = f"""你好！這是來自 Luminew 系統的面試分析報告：

面試受試者：{req.studentName}
AI 綜合評分：{req.overallScore} 分

【綜合評語】
{req.comment}

【改善建議】
{req.suggestion}

{req.timelineText}

感謝使用 Luminew 平台進行面試模擬，祝你順利錄取！
"""

        msg = MIMEMultipart()
        msg['Subject'] = subject
        msg['From'] = f"Luminew <{sender_email}>"
        msg['To'] = req.recipientEmail

        msg.attach(MIMEText(body, 'plain', 'utf-8'))

        if req.attachmentBase64:
            try:
                img_data = base64.b64decode(req.attachmentBase64)
                img = MIMEImage(img_data, name="interview_result.png")
                msg.attach(img)
            except Exception as img_e:
                print(f"⚠️ [Email] 附加圖片失敗: {img_e}")

        # 連線至 Gmail SMTP
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(sender_email, sender_pwd)
            server.send_message(msg)

        print(f"✅ 信件已成功寄送至 {req.recipientEmail}")
        return {"status": "ok", "message": "Email sent"}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"寄信失敗: {str(e)}")
