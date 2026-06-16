# test_did.py
import sys
import os

# 確保可以載入 app 模組
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from app.services.InterviewManager import InterviewManager

def test_did_stream():
    print("[START] 測試 D-ID 視訊會議室申請...")
    manager = InterviewManager()
    
    result = manager.create_did_stream()
    
    print("\n[OK] 回傳結果：")
    print(result)
    
if __name__ == "__main__":
    test_did_stream()
