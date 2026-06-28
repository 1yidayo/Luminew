# call_openai.py（把 ASR 的文字送給 gpt-4.1-nano）

import requests
import time

OPENAI_API_KEY = "替換"
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"


def ask_gpt4_1_nano(prompt, system_instructions=None, retry=3):
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "gpt-4.1-nano",
        "input": [
            {"role": "system", "content": system_instructions or "你是溫和的台灣教授。"},
            {"role": "user", "content": prompt}
        ]
    }

    for attempt in range(retry):
        try:
            r = requests.post(OPENAI_RESPONSES_URL, json=payload, headers=headers, timeout=10)
            r.raise_for_status()
            data = r.json()

            # 正確解析
            return data["output"][0]["content"][0]["text"]

        except Exception as e:
            print(f"[GPT] 第 {attempt+1} 次請求失敗：{e}")
            if attempt < retry - 1:
                time.sleep(1)  # 等一秒再重試
                continue
            return "(GPT 回應失敗)"


# 測試
if __name__ == "__main__":
    reply = ask_gpt4_1_nano("請用台灣腔說：你好我是教授。")
    print("GPT 回覆：", reply)
