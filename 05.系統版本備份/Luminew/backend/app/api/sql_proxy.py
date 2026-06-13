from fastapi import APIRouter, Request, Response
from pydantic import BaseModel
import pymssql
import json
import datetime

router = APIRouter()

class SqlRequest(BaseModel):
    query: str

class CustomEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime.date, datetime.datetime)):
            return obj.isoformat()
        return super().default(obj)

@router.post("/query")
async def execute_query(req: SqlRequest):
    try:
        conn = pymssql.connect(
            server='localhost',
            port=1433,
            user='sa',
            password='112233',
            database='LuminewDB'
        )
        cursor = conn.cursor(as_dict=True)
        cursor.execute(req.query.encode('utf-8').decode('utf-8'))
        
        # 判斷是否為 SELECT，如果有回傳結果就 fetchall()
        if "SELECT" in req.query.upper() and ("INSERT" not in req.query.upper() or req.query.upper().index("SELECT") < req.query.upper().find("INSERT") if "INSERT" in req.query.upper() else True):
            # 有些 SELECT ... INSERT 比較複雜，簡單防禦
            try:
                result = cursor.fetchall()
            except pymssql.OperationalError:
                result = []
            conn.commit()
            conn.close()
            return Response(content=json.dumps(result, cls=CustomEncoder), media_type="application/json")
        else:
            conn.commit()
            conn.close()
            return Response(content="[]", media_type="application/json")
            
    except Exception as e:
        print(f"SQL Proxy 錯誤: {e}")
        return Response(content=json.dumps({"error": str(e)}), media_type="application/json", status_code=500)
