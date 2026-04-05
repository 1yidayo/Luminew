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
    sql = f"SELECT * FROM Users WHERE Email = '{req.email}' AND PasswordHash = '{req.password}'"
    res = execute_read(sql)
    return res[0] if res else None

class RegisterReq(BaseModel): email: str; password: str; name: str; role: str
@router.post("/registerUser")
def registerUser(req: RegisterReq):
    sql = f"INSERT INTO Users (Email, PasswordHash, Name, Role) VALUES ('{req.email}', '{req.password}', N'{req.name}', '{req.role}')"
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
    safeSelect = "RecordID, StudentID, Date, DurationSeconds, Type, Interviewer, Language, OverallScore, REPLACE(CAST(ScoresDetail AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as ScoresDetail, Privacy, REPLACE(CAST(AIComment AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as AIComment, REPLACE(CAST(AISuggestion AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as AISuggestion, REPLACE(CAST(TimelineData AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as TimelineData, VideoUrl, REPLACE(CAST(Questions AS NVARCHAR(4000)), CHAR(34), CHAR(39)) as Questions, InterviewName"
    if '@' in req.userId:
        sql = f"SELECT {safeSelect} FROM InterviewRecords WHERE StudentID = (SELECT UserID FROM Users WHERE Email = '{req.userId}') ORDER BY Date DESC"
    else:
        sql = f"SELECT {safeSelect} FROM InterviewRecords WHERE StudentID = '{req.userId}' ORDER BY Date DESC"
    return execute_read(sql)

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
    scoresJson = json.dumps(req.scores).replace("'", "''")
    safeComment = req.aiComment.replace("'", "''")
    safeSuggestion = req.aiSuggestion.replace("'", "''")
    safeTimeline = req.timelineData.replace("'", "''")
    questionsJson = json.dumps(req.questions).replace("'", "''")
    safeName = req.interviewName.replace("'", "''")
    sql = f"""INSERT INTO InterviewRecords (StudentID, Date, DurationSeconds, Type, Interviewer, Language, OverallScore, ScoresDetail, Privacy, AIComment, AISuggestion, TimelineData, VideoUrl, Questions, InterviewName)
    OUTPUT INSERTED.RecordID
    VALUES ((SELECT UserID FROM Users WHERE Email = '{req.studentId}'), GETDATE(), {req.durationSec}, N'{req.type}', N'{req.interviewer}', N'{req.language}', {req.overallScore}, '{scoresJson}', '{req.privacy}', N'{safeComment}', N'{safeSuggestion}', '{safeTimeline}', '{req.videoUrl}', N'{questionsJson}', N'{safeName}')"""
    res = execute_read(sql)
    return {"status": "ok", "recordId": str(res[0]['RecordID'])} if res else {"status": "ok"}

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
