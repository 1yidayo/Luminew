import pyodbc

# SQL Server 設定 (與原本 Flutter 的設定相同)
DB_HOST = "140.136.155.145"
DB_PORT = "1433"
DB_NAME = "LuminewDB"
DB_USER = "TeamUser"
DB_PASS = "!%IM43Luminew%!"

def get_db_connection():
    """嘗試不同的 ODBC 驅動程式，以應付不同版本的 Windows 與 SSMS 安裝"""
    drivers = [
        '{ODBC Driver 18 for SQL Server}',
        '{ODBC Driver 17 for SQL Server}',
        '{SQL Server Native Client 11.0}',
        '{SQL Server}'
    ]
    
    for driver in drivers:
        try:
            # 針對 18 版需加上 TrustServerCertificate=yes
            conn_str = f"DRIVER={driver};SERVER={DB_HOST},{DB_PORT};DATABASE={DB_NAME};UID={DB_USER};PWD={DB_PASS};TrustServerCertificate=yes"
            conn = pyodbc.connect(conn_str, timeout=3)
            return conn
        except Exception:
            continue
            
    print(f"❌ [DB] 試過多種驅動仍無法連線到 {DB_HOST}。請檢查 NGROK 到內網 SQL Server 的通道或防火牆。")
    raise Exception("無法連線到 SQL Server，請確認 SQL Server 已啟動、驗證模式為混合認證，且開啟了 TCP/IP。")

def execute_read(sql: str) -> list:
    """執行 SELECT 查詢並回傳 List[Dict] 格式的 JSON 友善結果"""
    try:
        conn = get_db_connection()
    except Exception as e:
        print(f"❌ [DB] 讀取查詢連線失敗: {e}")
        return []
        
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        if not cursor.description:
            return []
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))
        return results
    except Exception as e:
        print(f"❌ [DB] 執行 SELECT 失敗: {e}\nSQL: {sql}")
        return []
    finally:
        conn.close()

def execute_write(sql: str) -> None:
    """執行 INSERT, UPDATE, DELETE 命令"""
    try:
        conn = get_db_connection()
    except Exception as e:
        print(f"❌ [DB] 寫入連線失敗: {e}")
        raise e
        
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
    except Exception as e:
        print(f"❌ [DB] 執行 WRITE 失敗: {e}\nSQL: {sql}")
        raise e
    finally:
        conn.close()
