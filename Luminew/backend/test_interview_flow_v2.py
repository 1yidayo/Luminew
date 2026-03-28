# test_interview_flow_v2.py
import time
import threading
import uvicorn
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pyngrok import ngrok
from pydantic import BaseModel
from typing import Any
from app.services.InterviewManager import InterviewManager

# ==========================================
# 搭建給瀏覽器用的 WebRTC 微型橋樑伺服器
# ==========================================
bridge_app = FastAPI()
bridge_app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_headers=["*"], allow_methods=["*"])

bridge_data = {"manager": None, "offer_info": None}

class AnswerPayload(BaseModel): answer: Any
class ICEPayload(BaseModel): candidate: str; sdpMid: str; sdpMLineIndex: int

@bridge_app.get("/get_offer")
def get_offer():
    return bridge_data["offer_info"] if bridge_data["offer_info"] else {"error": "尚未準備好房間"}

@bridge_app.post("/send_answer")
def send_answer(p: AnswerPayload):
    mgr = bridge_data["manager"]
    return mgr.submit_did_sdp_answer(p.answer, mgr.did_session_id)

@bridge_app.post("/send_ice")
def send_ice(p: ICEPayload):
    mgr = bridge_data["manager"]
    return mgr.submit_did_ice_candidate(p.candidate, p.sdpMid, p.sdpMLineIndex, mgr.did_session_id)

def start_backend_bridge():
    # 建立 publicly accessible 的資料夾
    os.makedirs(os.path.join("app", "public", "audio"), exist_ok=True)
    bridge_app.mount("/audio", StaticFiles(directory=os.path.join("app", "public", "audio")), name="audio")
    
    # 啟動 ngrok
    print("⏳ 啟動 ngrok 隧道中 (請稍候)...")
    public_url = ngrok.connect(8008).public_url
    print(f"🌍 Ngrok 公開網址: {public_url}")
    bridge_data["public_url"] = public_url
    
    uvicorn.run(bridge_app, host="127.0.0.1", port=8008, log_level="error")

# ==========================================
# 終端機主程式
# ==========================================
def run_interview_v2():
    # 啟動微型橋樑伺服器
    threading.Thread(target=start_backend_bridge, daemon=True).start()

    # 等待 ngrok 啟動
    print("⏳ 等待伺服器與 Ngrok 隧道連線建立...")
    time.sleep(4)
    
    # 1. 初始化面試官 (啟用 D-ID)
    manager = InterviewManager(professor_type="warm_industry_professor", use_did=True)
    manager.public_url = bridge_data.get("public_url")
    bridge_data["manager"] = manager
    
    print("\n" + "="*60)
    print("🎓 AI 面試流程 V2 測試 (含 D-ID 視訊整合)")
    print("="*60)
    print("教授角色:", manager.professor_persona.name)
    print("\n[流程說明]:")
    print("1. 程式啟動後，教授會先說開場白。")
    print("2. 開場白結束後，麥克風會【自動開啟】（綠色提示）。")
    print("3. 當您講完後，請按一次 [Enter] 鍵進行【手動關麥】。")
    print("4. 教授會思考並回答，回答完後麥克風會【再次自動開啟】。")
    print("5. 持續循環，直到按下 Ctrl+C 結束。")
    print("="*60 + "\n")
    
    # 2. 先建立 D-ID 房間
    print("⏳ 正在向 D-ID 申請視訊會議室，請稍候...")
    offer_info = manager.create_did_stream()
    bridge_data["offer_info"] = offer_info

    print("\n" + "⭐"*30)
    print("👉 房間已準備好！請現在點開 [test_view_did.html] 👈")
    print("👉 確認網頁上出現教授畫面後，請回到這裡按下 Enter 繼續！👈")
    print("⭐"*30 + "\n")
    input("按下 [Enter] 開始面試流程...")

    # 啟動面試 (會包含：ASR準備 -> 開場白TTS -> 自動開麥)
    manager.start_interview()

    try:
        round_count = 1
        while True:
            print(f"\n" + "="*20)
            print(f"   [對話第 {round_count} 輪]   ")
            print("="*20)
            print("💡 提示：現在麥克風是開啟的，您可以開始說話。")
            input(f"🎤 如果您講完了，請按 [Enter] 鍵結束錄音並送出...")
            
            print("\n🚀 [動作] 偵測到 Enter，正在請求教授回應...")
            # 手動觸發關麥與生成回應
            manager.process_speech_end()
            
            # 程式碼走到這裡時，教授的回應已經播完了，且內部已經自動 call 了 start_recording
            time.sleep(0.5)
            round_count += 1

    except KeyboardInterrupt:
        print("\n⏹ 外力介入，面試終止。")
    finally:
        manager.stop_interview()
        time.sleep(1) # 等待一些背景執行緒關閉

if __name__ == "__main__":
    run_interview_v2()
