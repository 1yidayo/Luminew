-- ============================================================
-- LuminewDB Migration: 老師查看學生面試紀錄功能
-- 執行方式：在 SSMS 中開啟此檔案，選擇 LuminewDB，然後 F5 執行
-- ============================================================

USE LuminewDB;
GO

-- ============================================================
-- Step 1: 在 Users 表新增老師邀請碼欄位
-- 說明：每位老師有一組唯一代碼，學生輸入此代碼加入老師
-- ============================================================
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('Users') AND name = 'TeacherCode'
)
BEGIN
    ALTER TABLE Users ADD TeacherCode NVARCHAR(10) NULL;
    PRINT N'✅ Step 1 完成：Users 表新增 TeacherCode 欄位';
END
ELSE
BEGIN
    PRINT N'⚠️  Step 1 跳過：TeacherCode 欄位已存在';
END
GO

-- 為現有老師自動產生邀請碼（若為 NULL）
UPDATE Users 
SET TeacherCode = CAST(ABS(CHECKSUM(NEWID())) % 900000 + 100000 AS NVARCHAR(10))
WHERE Role = 'teacher' AND TeacherCode IS NULL;
GO

PRINT N'✅ Step 1b 完成：已為現有老師產生 TeacherCode';
GO

-- ============================================================
-- Step 2: 建立 TeacherStudents 老師學生關聯表
-- 說明：學生加入老師後建立關聯，類似原本的 ClassMembers
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='TeacherStudents' AND xtype='U')
BEGIN
    CREATE TABLE TeacherStudents (
        RelationID  INT IDENTITY(1,1) PRIMARY KEY,
        TeacherID   INT NOT NULL,
        StudentID   INT NOT NULL,
        JoinedAt    DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (TeacherID) REFERENCES Users(UserID),
        FOREIGN KEY (StudentID) REFERENCES Users(UserID),
        UNIQUE (TeacherID, StudentID)
    );
    PRINT N'✅ Step 2 完成：建立 TeacherStudents 表';
END
ELSE
BEGIN
    PRINT N'⚠️  Step 2 跳過：TeacherStudents 表已存在';
END
GO

-- ============================================================
-- Step 3: 建立 RecordTeacherAccess 面試紀錄老師授權表
-- 說明：記錄學生將哪些紀錄公開給哪些老師
-- ============================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='RecordTeacherAccess' AND xtype='U')
BEGIN
    CREATE TABLE RecordTeacherAccess (
        AccessID    INT IDENTITY(1,1) PRIMARY KEY,
        RecordID    INT NOT NULL,
        TeacherID   INT NOT NULL,
        GrantedAt   DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (RecordID)  REFERENCES InterviewRecords(RecordID),
        FOREIGN KEY (TeacherID) REFERENCES Users(UserID),
        UNIQUE (RecordID, TeacherID)
    );
    PRINT N'✅ Step 3 完成：建立 RecordTeacherAccess 表';
END
ELSE
BEGIN
    PRINT N'⚠️  Step 3 跳過：RecordTeacherAccess 表已存在';
END
GO

-- ============================================================
-- Step 4: 在 RecordComments 新增 TeacherChannelID 欄位
-- 說明：區分不同老師的評語頻道，NULL = 舊有公共頻道
-- ============================================================
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('RecordComments') AND name = 'TeacherChannelID'
)
BEGIN
    ALTER TABLE RecordComments ADD TeacherChannelID INT NULL;
    ALTER TABLE RecordComments ADD FOREIGN KEY (TeacherChannelID) REFERENCES Users(UserID);
    PRINT N'✅ Step 4 完成：RecordComments 表新增 TeacherChannelID 欄位';
END
ELSE
BEGIN
    PRINT N'⚠️  Step 4 跳過：TeacherChannelID 欄位已存在';
END
GO

-- ============================================================
-- 驗證結果
-- ============================================================
PRINT N'';
PRINT N'==== 驗證結果 ====';
SELECT 'Users.TeacherCode' AS 欄位, COUNT(*) AS 老師數量 
FROM Users WHERE Role = 'teacher' AND TeacherCode IS NOT NULL;

SELECT 'TeacherStudents' AS 表名, COUNT(*) AS 筆數 FROM TeacherStudents;
SELECT 'RecordTeacherAccess' AS 表名, COUNT(*) AS 筆數 FROM RecordTeacherAccess;

SELECT 
    COLUMN_NAME AS 欄位名稱,
    DATA_TYPE AS 資料類型,
    IS_NULLABLE AS 可為空
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'RecordComments'
ORDER BY ORDINAL_POSITION;

PRINT N'';
PRINT N'✅ Migration 完成！共新增/修改 4 個資料庫物件。';
GO
