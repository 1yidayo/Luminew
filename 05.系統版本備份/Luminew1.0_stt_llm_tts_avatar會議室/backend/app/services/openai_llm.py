# openai_llm.py
# call_openai.py（把 ASR 的文字送給 gpt-4.1-nano）
import requests
import time
from dotenv import load_dotenv
import os
from app.services.professor_persona import get_professor_persona

# 讀取 .env
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")  # 從 .env 拿
OPENAI_RESPONSES_URL = os.getenv("OPENAI_RESPONSES_URL")

def ask_gpt4_1_nano(conversation_history, professor_type="warm_industry_professor", retry=3):
    persona = get_professor_persona(professor_type)
    system_prompt = persona.prompt

    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "gpt-4.1-nano",
        "input": conversation_history
    }

    for attempt in range(retry):
        try:
            r = requests.post(OPENAI_RESPONSES_URL, json=payload, headers=headers, timeout=20)
            r.raise_for_status()
            data = r.json()
            return data["output"][0]["content"][0]["text"]
        except Exception as e:
            print(f"[GPT] 第 {attempt+1} 次請求失敗：{e}")
            if attempt < retry - 1:
                time.sleep(1)
                continue
            return "(GPT 回應失敗)"

#測試
if __name__ == "__main__":

    from professor_persona import get_professor_prompt

    professor_type = "warm_industry_professor"
    system_prompt = get_professor_prompt(professor_type)

    # 初始化對話歷史
    conversation_history = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "請開始面試我"}  # ← 預設第一句
    ]

    print("=== 模擬面試官開始 ===")
    print("輸入 'exit' 結束模擬")

    while True:

        # GPT 回覆
        reply = ask_gpt4_1_nano(conversation_history, professor_type)
        print(f"教授: {reply}")

        # 把教授回覆加入歷史，方便下次追問
        conversation_history.append({"role": "assistant", "content": reply})

        # 學生輸入
        user_input = input("\n學生: ")
        if user_input.lower() == "exit":
            break

        conversation_history.append({"role": "user", "content": user_input})