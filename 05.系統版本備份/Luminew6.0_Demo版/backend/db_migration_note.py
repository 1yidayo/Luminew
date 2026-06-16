import sys
import os

# 將當前路徑加入系統路徑，以利導入 app module
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 避免 Windows 終端機 Unicode 輸出報錯
if sys.platform.startswith("win"):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

from app.database.db import execute_write, execute_read

def migrate():
    print("🚀 [Migration] 檢查 InterviewRecords 表結構中...")
    try:
        # 檢查是否已存在 Note 欄位
        check_sql = """
        SELECT 1 FROM sys.columns 
        WHERE object_id = OBJECT_ID('InterviewRecords') AND name = 'Note'
        """
        res = execute_read(check_sql)
        if not res:
            print("🔧 [Migration] 找不到 Note 欄位，正在建立欄位...")
            # 建立欄位：Note NVARCHAR(MAX) NULL
            alter_sql = "ALTER TABLE InterviewRecords ADD Note NVARCHAR(MAX) NULL"
            execute_write(alter_sql)
            print("✅ [Migration] 建立 Note 欄位成功！")
        else:
            print("⚠️  [Migration] Note 欄位已存在，跳過此步驟。")
    except Exception as e:
        print(f"❌ [Migration] 資料庫 Migration 失敗: {e}")
        sys.exit(1)

if __name__ == "__main__":
    migrate()
