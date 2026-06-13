import requests
from dotenv import load_dotenv
import os

# 1. 填入你的 D-ID API Key
# [WARN] 注意：確保引號裡面完全沒有多餘的空白！

# 讀取 .env
load_dotenv()

D_ID_API_KEY = os.getenv("D_ID_API_KEY")

# 把 Key 自動拆成帳號(username)和密碼(password)
username, password = D_ID_API_KEY.split(':')

# D-ID 的 API 網址
D_ID_URL = os.getenv("D_ID_URL")

# 告訴 D-ID 我們要用哪張照片當教授
payload = {
    "source_url": "https://raw.githubusercontent.com/1yidayo/Luminew/refs/heads/main/Luminew/backend/assets/images/Paul.jpg" 
}

# [WARN] 注意這裡：我們把手動轉換密碼的那行刪掉了，只要這兩行就好
headers = {
    "accept": "application/json",
    "content-type": "application/json"
}

print("正在向 D-ID 申請開啟視訊會議室...")

try:
    # 2. 發送 POST 請求
    # 這裡加入 auth=(username, password)，讓 Python 用最標準、最安全的方式幫我們輸入密碼！
    response = requests.post(
        D_ID_URL, 
        json=payload, 
        headers=headers, 
        auth=(username, password)
    )
    
    # 檢查是否成功 (201 代表成功建立)
    if response.status_code == 201:
        print("[SUCCESS] 成功啦！D-ID 已經為我們準備好串流房間了！")
        data = response.json()
        print("\n--- 這是我們要交給 Flutter 的重要資料 ---")
        print("1. 會議室代碼 (stream_id):", data.get("id"))
        print("2. 視訊入場券 (offer SDP):", data.get("offer", {}).get("sdp")[:50] + "...(後面省略)")
        print("-----------------------------------------")
    else:
        print(f"[ERROR] 失敗了，狀態碼：{response.status_code}")
        print("錯誤訊息：", response.text)

except Exception as e:
    print(f"程式發生錯誤：{e}")