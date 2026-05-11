
import sys
import json
import os

def main():
    try:
        pdf_path = sys.argv[1]
        interview_type = sys.argv[2]
        api_key = sys.argv[3] if len(sys.argv) > 3 else ""
        
        DEFAULT = [
            "請簡單自我介紹，並說明你為什麼對這個領域有興趣？",
            "你認為自己最大的優點和需要改進的地方是什麼？",
            "請分享一個你克服困難的經驗，你從中學到了什麼？",
            "談談你對未來的規劃，以及這個目標對你的意義。",
            "如果錄取後，你希望在這裡學到什麼？"
        ]
        
        # 檢查 API Key
        if not api_key or len(api_key) < 10:
            print(json.dumps({"questions": DEFAULT, "reason": "no_key"}))
            return
        
        # 讀取 PDF
        try:
            from PyPDF2 import PdfReader
            reader = PdfReader(pdf_path)
            text = ""
            for page in reader.pages:
                t = page.extract_text()
                if t:
                    text += t + "\n"
        except Exception as e:
            print(json.dumps({"questions": DEFAULT, "reason": f"pdf_error: {e}"}))
            return
        
        if not text.strip():
            print(json.dumps({"questions": DEFAULT, "reason": "empty_pdf"}))
            return
        
        # 限制長度
        if len(text) > 5000:
            text = text[:5000]
        
        # 呼叫 OpenAI
        import requests
        
        prompt = f"""你是專業的大學面試官。請根據以下學生的學習歷程內容，生成 5 個針對這位學生具體經歷的個人化面試問題。

【面試類型】{interview_type}

【學習歷程內容】
{text}

【要求】
1. 問題必須針對學生提到的具體經驗、專案、活動來提問
2. 不要問泛泛的問題
3. 用繁體中文

【輸出格式】
請只回傳 JSON 陣列：
["問題1", "問題2", "問題3", "問題4", "問題5"]"""
        
        url = "https://api.openai.com/v1/chat/completions"
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {
            "model": "gpt-3.5-turbo",
            "messages": [
                {"role": "system", "content": "你是專業的大學面試官，只回傳 JSON 陣列。"},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 1024
        }
        
        resp = requests.post(url, headers=headers, json=payload, timeout=60)
        
        if resp.status_code == 200:
            content = resp.json()["choices"][0]["message"]["content"]
            clean = content.replace("```json", "").replace("```", "").strip()
            questions = json.loads(clean)
            print(json.dumps({"questions": questions, "ok": True}))
        else:
            print(json.dumps({"questions": DEFAULT, "reason": f"api_{resp.status_code}"}))
            
    except Exception as e:
        print(json.dumps({"questions": [
            "請簡單自我介紹，並說明你為什麼對這個領域有興趣？",
            "你認為自己最大的優點和需要改進的地方是什麼？",
            "請分享一個你克服困難的經驗，你從中學到了什麼？",
            "談談你對未來的規劃，以及這個目標對你的意義。",
            "如果錄取後，你希望在這裡學到什麼？"
        ], "reason": str(e)}))

if __name__ == "__main__":
    main()
