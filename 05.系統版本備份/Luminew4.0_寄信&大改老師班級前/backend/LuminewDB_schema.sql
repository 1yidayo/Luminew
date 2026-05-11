-- ============================================================
-- LuminewDB 完整資料庫建立腳本
-- 產生日期：2026-02-22
-- 說明：在 SQL Server Management Studio (SSMS) 中一次執行即可
-- ============================================================

-- ★ 1. 建立資料庫（如果已存在則跳過）
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'LuminewDB')
BEGIN
    CREATE DATABASE LuminewDB;
END
GO

USE LuminewDB;
GO

-- ============================================================
-- ★ 2. Users 使用者表（核心表，必須最先建立）
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
CREATE TABLE Users (
    UserID          INT IDENTITY(1,1) PRIMARY KEY,
    Email           NVARCHAR(255)   NOT NULL UNIQUE,
    PasswordHash    NVARCHAR(255)   NOT NULL,
    Name            NVARCHAR(100)   NOT NULL,
    Role            NVARCHAR(20)    NOT NULL CHECK (Role IN ('student', 'teacher')),
    Subscription    NVARCHAR(20)    DEFAULT 'Free',
    CreatedAt       DATETIME        DEFAULT GETDATE()
);
GO

-- ============================================================
-- ★ 3. Classes 班級表
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Classes' AND xtype='U')
CREATE TABLE Classes (
    ClassID         INT IDENTITY(1,1) PRIMARY KEY,
    ClassName       NVARCHAR(100)   NOT NULL,
    TeacherID       INT             NOT NULL,
    InvitationCode  NVARCHAR(10)    NOT NULL UNIQUE,
    CreatedAt       DATETIME        DEFAULT GETDATE(),
    FOREIGN KEY (TeacherID) REFERENCES Users(UserID)
);
GO

-- ============================================================
-- ★ 4. ClassMembers 班級成員表（學生加入班級的關聯表）
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ClassMembers' AND xtype='U')
CREATE TABLE ClassMembers (
    MemberID        INT IDENTITY(1,1) PRIMARY KEY,
    ClassID         INT             NOT NULL,
    StudentID       INT             NOT NULL,
    JoinedAt        DATETIME        DEFAULT GETDATE(),
    FOREIGN KEY (ClassID)   REFERENCES Classes(ClassID),
    FOREIGN KEY (StudentID) REFERENCES Users(UserID),
    UNIQUE (ClassID, StudentID)  -- 防止重複加入
);
GO

-- ============================================================
-- ★ 5. InterviewRecords 面試紀錄表
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='InterviewRecords' AND xtype='U')
CREATE TABLE InterviewRecords (
    RecordID        INT IDENTITY(1,1) PRIMARY KEY,
    StudentID       INT             NOT NULL,
    Date            DATETIME        DEFAULT GETDATE(),
    DurationSeconds INT             DEFAULT 0,
    Type            NVARCHAR(50)    DEFAULT N'通用型',
    Interviewer     NVARCHAR(100)   DEFAULT N'AI 面試官',
    Language        NVARCHAR(20)    DEFAULT N'中文',
    OverallScore    INT             DEFAULT 0,
    ScoresDetail    NVARCHAR(MAX)   NULL,          -- JSON 格式的各項分數
    Privacy         NVARCHAR(20)    DEFAULT 'Private',
    AIComment       NVARCHAR(MAX)   NULL,          -- AI 評語
    AISuggestion    NVARCHAR(MAX)   NULL,          -- AI 建議
    TimelineData    NVARCHAR(MAX)   NULL,          -- 情緒時間軸 JSON
    VideoUrl        NVARCHAR(500)   NULL,          -- 影片路徑
    Questions       NVARCHAR(MAX)   NULL,          -- 面試題目 JSON
    InterviewName   NVARCHAR(200)   NULL,          -- 面試名稱
    FOREIGN KEY (StudentID) REFERENCES Users(UserID)
);
GO

-- ============================================================
-- ★ 6. RecordComments 面試紀錄留言表
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='RecordComments' AND xtype='U')
CREATE TABLE RecordComments (
    CommentID       INT IDENTITY(1,1) PRIMARY KEY,
    RecordID        INT             NOT NULL,
    SenderID        INT             NOT NULL,
    Content         NVARCHAR(MAX)   NOT NULL,
    SentAt          DATETIME        DEFAULT GETDATE(),
    FOREIGN KEY (RecordID)  REFERENCES InterviewRecords(RecordID),
    FOREIGN KEY (SenderID)  REFERENCES Users(UserID)
);
GO

-- ============================================================
-- ★ 7. Invitations 面試邀請表
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Invitations' AND xtype='U')
CREATE TABLE Invitations (
    InvitationID    INT IDENTITY(1,1) PRIMARY KEY,
    TeacherID       INT             NOT NULL,
    StudentID       INT             NOT NULL,
    Message         NVARCHAR(MAX)   NULL,
    SentAt          DATETIME        DEFAULT GETDATE(),
    Status          NVARCHAR(20)    DEFAULT 'Pending',
    FOREIGN KEY (TeacherID) REFERENCES Users(UserID),
    FOREIGN KEY (StudentID) REFERENCES Users(UserID)
);
GO

-- ============================================================
-- ★ 8. InterviewSlots 面試時段表
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='InterviewSlots' AND xtype='U')
CREATE TABLE InterviewSlots (
    SlotID              INT IDENTITY(1,1) PRIMARY KEY,
    TeacherID           INT             NOT NULL,
    StartTime           DATETIME        NOT NULL,
    EndTime             DATETIME        NOT NULL,
    IsBooked            BIT             DEFAULT 0,
    BookedByStudentID   INT             NULL,
    CreatedAt           DATETIME        DEFAULT GETDATE(),
    FOREIGN KEY (TeacherID)         REFERENCES Users(UserID),
    FOREIGN KEY (BookedByStudentID) REFERENCES Users(UserID)
);
GO

-- ============================================================
-- ★ 9. LearningPortfolios 學習歷程表
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='LearningPortfolios' AND xtype='U')
CREATE TABLE LearningPortfolios (
    PortfolioID     INT IDENTITY(1,1) PRIMARY KEY,
    StudentID       INT             NOT NULL,
    Title           NVARCHAR(200)   NOT NULL,
    UploadDate      DATETIME        DEFAULT GETDATE(),
    FOREIGN KEY (StudentID) REFERENCES Users(UserID)
);
GO

-- ============================================================
-- 完成！所有資料表已建立。
-- ============================================================
PRINT N'✅ LuminewDB 資料庫建立完成！共 8 張資料表。';
GO
