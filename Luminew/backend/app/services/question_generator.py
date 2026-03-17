# question_generator.py
# ★★★ 修正版 - 使用 httpx 同步模式在 executor 中執行 ★★★

import os
import json
import httpx
import asyncio
from concurrent.futures import ThreadPoolExecutor
from dotenv import load_dotenv
import traceback

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

DEFAULT_QUESTIONS = [
    "請簡單自我介紹，並說明你為什麼對這個領域有興趣？",
    "你認為自己最大的優點和需要改進的地方是什麼？",
    "請分享一個你克服困難的經驗，你從中學到了什麼？",
    "談談你對未來的規劃，以及這個目標對你的意義。",
    "如果錄取後，你希望在這裡學到什麼？",
    "在高中階段，你有遇過什麼印象深刻的團隊合作經驗嗎？",
    "在學習過程中，對於較不擅長的科目或領域，你通常是如何應對的？",
    "請分享一個你透過自學達成某個目標的經驗。",
    "除了課業之外，你有什麼特殊的興趣或專長嗎？這對你帶來什麼影響？",
    "未來的大學生活中，除了本科系專業之外，你還有想跨領域學習什麼嗎？"
]

# ★★★ 建立共用的 ThreadPoolExecutor ★★★
executor = ThreadPoolExecutor(max_workers=4)


def _process_pdf_and_call_openai_sync(pdf_path: str, interview_type: str) -> dict:
    """
    同步處理 PDF 並呼叫 OpenAI (在獨立線程中執行)
    這樣即使出錯也不會影響主程式
    """
    try:
        print(f"🔍 [Worker] 開始處理: {pdf_path}")
        print(f"📌 類型: {interview_type}")
        
        if not os.path.exists(pdf_path):
            print("❌ 檔案不存在")
            return {"success": True, "questions": DEFAULT_QUESTIONS}
        
        # 讀取 PDF
        print("📄 讀取 PDF...")
        try:
            from PyPDF2 import PdfReader
            reader = PdfReader(pdf_path)
            text = ""
            for page in reader.pages:
                t = page.extract_text()
                if t:
                    text += t + "\n"
            print(f"📄 提取 {len(text)} 字")
        except Exception as e:
            print(f"⚠️ PDF 讀取失敗: {e}")
            traceback.print_exc()
            return {"success": True, "questions": DEFAULT_QUESTIONS}
        
        if not text.strip():
            print("⚠️ PDF 無文字")
            return {"success": True, "questions": DEFAULT_QUESTIONS}
        
        # 檢查 API Key
        if not OPENAI_API_KEY or len(OPENAI_API_KEY) < 10:
            print("⚠️ 無 API Key")
            return {"success": True, "questions": DEFAULT_QUESTIONS}
        
        # 限制長度
        if len(text) > 5000:
            text = text[:5000]
        
        # ★★★ 使用 httpx 同步模式呼叫 OpenAI ★★★
        print("🤖 呼叫 OpenAI (同步，在獨立線程中)...")
        
        prompt = f"""你是專業的大學面試官。請根據以下學生的學習歷程內容，生成 5 個針對這位學生具體經歷的個人化面試問題。

【面試類型】{interview_type}

【學習歷程內容】
{text}

【要求】
1. 問題必須針對學生提到的具體經驗、專案、活動來深入提問
2. 不要問泛泛的問題，必須客製化
3. 提問風格必須自然、口語化，並且自帶「承接式語氣」，例如：「我看到你的備審資料中提到...，想請你分享...」或是「對於你參加的...活動，你覺得...」
4. 用繁體中文

【輸出格式】
只回傳 JSON 陣列：["問題1", "問題2", "問題3", "問題4", "問題5"]"""
        
        # 使用同步 httpx（在線程中執行所以不會阻塞主程式）
        with httpx.Client(timeout=60.0) as client:
            resp = client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": [
                        {"role": "system", "content": "你是專業的大學面試官，只回傳 JSON 陣列。"},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 1024
                }
            )
        
        print(f"📨 OpenAI 回應: {resp.status_code}")
        
        if resp.status_code == 200:
            content = resp.json()["choices"][0]["message"]["content"]
            clean = content.replace("```json", "").replace("```", "").strip()
            questions = json.loads(clean)
            print(f"✅ 生成 {len(questions)} 個個人化問題！")
            return {"success": True, "questions": questions}
        else:
            print(f"⚠️ API 錯誤: {resp.status_code} - {resp.text}")
            return {"success": True, "questions": DEFAULT_QUESTIONS}
            
    except Exception as e:
        print(f"❌ [Worker] 錯誤: {e}")
        traceback.print_exc()
        return {"success": True, "questions": DEFAULT_QUESTIONS}


async def analyze_pdf_and_generate_questions(pdf_path: str, interview_type: str = "通用型") -> dict:
    """
    非同步入口 - 把實際工作交給 ThreadPoolExecutor
    這樣主程式不會被阻塞，也不會因為一個任務失敗而崩潰
    """
    loop = asyncio.get_event_loop()
    
    # ★★★ 在獨立線程中執行同步任務 ★★★
    result = await loop.run_in_executor(
        executor, 
        _process_pdf_and_call_openai_sync, 
        pdf_path, 
        interview_type
    )
    
    return result
