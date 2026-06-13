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
async def send_answer(p: AnswerPayload):
    mgr = bridge_data["manager"]
    return await mgr.submit_did_sdp_answer(p.answer, mgr.did_session_id)

@bridge_app.post("/send_ice")
async def send_ice(p: ICEPayload):
    mgr = bridge_data["manager"]
    return await mgr.submit_did_ice_candidate(p.candidate, p.sdpMid, p.sdpMLineIndex, mgr.did_session_id)

def start_backend_bridge():
    # 建立 publicly accessible 的資料夾
    os.makedirs(os.path.join("app", "public", "audio"), exist_ok=True)
    bridge_app.mount("/audio", StaticFiles(directory=os.path.join("app", "public", "audio")), name="audio")
    
    # 啟動 ngrok
    print("[WAIT] 啟動 ngrok 隧道中 (請稍候)...")
    try:
        public_url = ngrok.connect(8012).public_url
        print(f"[URL] Ngrok 公開網址: {public_url}")
        bridge_data["public_url"] = public_url
    except Exception as e:
        print(f"[WARN] Ngrok 啟動失敗，忽略 (這不影響本機 HTML 測試): {e}")
        bridge_data["public_url"] = None
    
    uvicorn.run(bridge_app, host="127.0.0.1", port=8012, log_level="info")

# ==========================================
# 終端機主程式
# ==========================================
async def run_interview_v2():
    # 啟動微型橋樑伺服器
    threading.Thread(target=start_backend_bridge, daemon=True).start()

    # 等待 ngrok/橋樑 啟動
    print("[WAIT] 等待伺服器連線建立...")
    await asyncio.sleep(4)
    
    # 1. 初始化面試官 (啟用 D-ID)
    manager = InterviewManager(professor_type="warm_industry_professor", use_did=True)
    manager.public_url = bridge_data.get("public_url")
    bridge_data["manager"] = manager
    
    print("\n" + "="*60)
    print("[ACAD] AI 面試流程 V2 測試 (含 D-ID 視訊整合)")
    print("="*60)
    print("教授角色:", manager.professor_persona.name)
    
    # 2. 先建立 D-ID 房間
    print("[WAIT] 正在向 D-ID 申請視訊會議室，請稍候...")
    offer_info = await asyncio.to_thread(manager.create_did_stream)
    bridge_data["offer_info"] = offer_info

    print("\n" + "[STAR]"*30)
    print(" [SYMBOL]  房間已準備好！請現在點開 [test_view_did.html]  [SYMBOL] ")
    print(" [SYMBOL]  確認網頁上出現教授畫面後，請回到這裡按下 Enter 繼續！ [SYMBOL] ")
    print("[STAR]"*30 + "\n")
    await asyncio.to_thread(input, "按下 [Enter] 開始面試流程...")

    # 啟動面試
    await manager.start_interview()

    try:
        round_count = 1
        while True:
            print(f"\n" + "="*20)
            print(f"   [對話第 {round_count} 輪]   ")
            print("="*20)
            await asyncio.to_thread(input, f"[MIC] 如果您講完了，請按 [Enter] 鍵結束錄音並送出...")
            
            print("\n[START] [動作] 偵測到 Enter，正在請求教授回應...")
            await manager.process_speech_end()
            
            await asyncio.sleep(0.5)
            round_count += 1

    except KeyboardInterrupt:
        print("\n[STOP] 外力介入，面試終止。")
    finally:
        await manager.stop_interview()
        await asyncio.sleep(1)

if __name__ == "__main__":
    import asyncio
    asyncio.run(run_interview_v2())

