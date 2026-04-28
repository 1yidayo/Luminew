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

# 不同類型的預設題庫
DEFAULT_BANKS = {
    "通用型": [
        "請簡單自我介紹，並說明你為什麼對這個領域有興趣？",
        "你認為自己最大的優點和需要改進的地方是什麼？",
        "請分享一個你克服困難的經驗，你從中學到了什麼？",
        "談談你對未來的規劃，以及這個目標對你的意義。",
        "在高中階段，你有遇過什麼印象深刻的團隊合作經驗嗎？"
    ],
    "資管專業": [
        "為什麼選擇資訊管理系，而不是純資訊工程或企管系？",
        "你有寫過程式或參與開發專案的經驗嗎？請描述其中的挑戰。",
        "你如何看待 AI 人工智慧對未來職場的影響？",
        "請解釋一個你熟悉的資訊科技概念（例如雲端、區塊鏈或大數據）。",
        "如果你要設計一個解決校園生活問題的 App，你會怎麼規劃？"
    ],
    "學習歷程": [
        "這份學習歷程中，哪一個部分是你投入心力最多、感到最自豪的？",
        "在準備學習歷程檔案的過程中，你對自己的專業興趣有新的發現嗎？",
        "如果你有機會重新做一次檔案中的某個專案，你會做什麼樣的調整？",
        "這份檔案如何展現你除了課業之外的批判性思考或問題解決能力？",
        "你認為這份檔案最能代表你哪一方面的個人特質？"
    ]
}

def get_default_questions(interview_type: str):
    return DEFAULT_BANKS.get(interview_type, DEFAULT_BANKS["通用型"])

# ★★★ 建立共用的 ThreadPoolExecutor ★★★
executor = ThreadPoolExecutor(max_workers=4)


def _process_pdf_and_call_openai_sync(pdf_path: str, interview_type: str) -> dict:
    """
    同步處理 PDF 並呼叫 OpenAI (在獨立線程中執行)
    這樣即使出錯也不會影響主程式
    """
    try:
        print(f" [SYMBOL]  [Worker] 開始處理: {pdf_path}")
        print(f" [SYMBOL]  類型: {interview_type}")
        
        if not os.path.exists(pdf_path):
            print("[ERROR] 檔案不存在")
            return {"success": True, "questions": get_default_questions(interview_type)}
        
        # 讀取 PDF
        print("[FILE] 讀取 PDF...")
        try:
            from PyPDF2 import PdfReader
            reader = PdfReader(pdf_path)
            text = ""
            for page in reader.pages:
                t = page.extract_text()
                if t:
                    text += t + "\n"
            print(f"[FILE] 提取 {len(text)} 字")
        except Exception as e:
            print(f"[WARN] PDF 讀取失敗: {e}")
            traceback.print_exc()
            return {"success": True, "questions": get_default_questions(interview_type)}
        
        if not text.strip():
            print("[WARN] PDF 無文字")
            return {"success": True, "questions": get_default_questions(interview_type)}
        
        # 檢查 API Key
        if not OPENAI_API_KEY or len(OPENAI_API_KEY) < 10:
            print("[WARN] 無 API Key")
            return {"success": True, "questions": get_default_questions(interview_type)}
        
        # 限制長度
        if len(text) > 5000:
            text = text[:5000]
        
        # ★★★ 使用 httpx 同步模式呼叫 OpenAI ★★★
        print("[AI] 呼叫 OpenAI (同步，在獨立線程中)...")
        
        prompt = f"""你是專業的大學面試官。請根據以下學生的學習歷程內容，生成 10 個針對這位學生具體經歷的個人化面試問題。

【面試類型】{interview_type}

【學習歷程內容】
{text}

【要求】
1. 問題必須針對學生提到的具體經驗、專案、活動來深入提問
2. 不要問泛泛的問題，必須客製化
3. 提問風格必須自然、口語化，並且自帶「承接式語氣」，例如：「我看到你的備審資料中提到...，想請你分享...」或是「對於你參加的...活動，你覺得...」
4. 用繁體中文

【輸出格式】
只回傳 JSON 陣列：["問題1", "問題2", "問題3", "問題4", "問題5", "問題6", "問題7", "問題8", "問題9", "問題10"]"""
        
        # 使用同步 httpx（在線程中執行所以不會阻塞主程式）
        with httpx.Client(timeout=60.0) as client:
            resp = client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-4o-mini",
                    "messages": [
                        {"role": "system", "content": "你是專業的大學面試官，只回傳 JSON 陣列。"},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 1024
                }
            )
        
        print(f" [SYMBOL]  OpenAI 回應: {resp.status_code}")
        
        if resp.status_code == 200:
            content = resp.json()["choices"][0]["message"]["content"]
            clean = content.replace("```json", "").replace("```", "").strip()
            questions = json.loads(clean)
            print(f"[OK] 生成 {len(questions)} 個個人化問題！")
            return {"success": True, "questions": questions}
        else:
            print(f"[WARN] API 錯誤: {resp.status_code} - {resp.text}")
            return {"success": True, "questions": get_default_questions(interview_type)}
            
    except Exception as e:
        print(f"[ERROR] [Worker] 錯誤: {e}")
        traceback.print_exc()
        return {"success": True, "questions": get_default_questions(interview_type)}


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
