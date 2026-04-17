import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pyngrok import ngrok, conf
from dotenv import load_dotenv
from app.api.interview import router as interview_router
from app.api.db_routes import router as db_router
from app.api.emotion import router as emotion_router
import torch
import datetime

# 載入 .env 變數
load_dotenv()

# 建立 FastAPI 實體
app = FastAPI(title="Luminew AI Interview Backend")

# 設定 CORS 允許任何前端 (Flutter / React 等) 呼叫
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 準備公開的音檔與影片落腳處，並掛載靜態路由
os.makedirs(os.path.join("app", "public", "audio"), exist_ok=True)
VIDEO_STORAGE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "videos")
os.makedirs(VIDEO_STORAGE_DIR, exist_ok=True)

app.mount("/audio", StaticFiles(directory=os.path.join("app", "public", "audio")), name="audio")
app.mount("/static/videos", StaticFiles(directory=VIDEO_STORAGE_DIR), name="videos")

# 引入面試的 Router 與 Database Router
app.include_router(interview_router, prefix="/api/interview", tags=["Interview"])
app.include_router(db_router, prefix="/api/db", tags=["Database"])

@app.get("/health")
async def health_check():
    """
    【內測診斷工具】
    回傳伺服器健康狀況與 GPU 負載情形
    """
    gpu_data = {"status": "Not Available"}
    if torch.cuda.is_available():
        gpu_data = {
            "status": "Available",
            "name": torch.cuda.get_device_name(0),
            "vram_total_mb": int(torch.cuda.get_device_properties(0).total_memory / (1024**2)),
            "vram_allocated_mb": int(torch.cuda.memory_allocated(0) / (1024**2)),
            "time": datetime.datetime.now().isoformat()
        }
    return {
        "status": "online",
        "server": "Luminew-GPU-Workstation (Root)",
        "gpu": gpu_data
    }

app.include_router(emotion_router, prefix="/emotion", tags=["Emotion"])

@app.on_event("startup")
async def startup_event():
    """伺服器啟動時，自動建立 Ngrok 隧道"""
    print("\n" + "="*50)
    print("[WAIT] 正在啟動伺服器與 Ngrok 隧道...")
    try:
        # 強制結束舊的 ngrok 進程 (防止 ERR_NGROK_334)
        print("[FIX] 正在清理舊的 Ngrok 連線...")
        ngrok.kill() 
        
        # 檢查並設定 authtoken
        auth_token = os.getenv("NGROK_AUTHTOKEN")
        if auth_token and auth_token.strip():
            ngrok.set_auth_token(auth_token.strip())
            print("[KEY] Ngrok Authtoken 已載入")
        
        # ngrok 預設開啟 port 8000
        # 如果有固定域名，ngrok 會自動捕捉設定檔中的 domain
        public_url = ngrok.connect(8000).public_url
        print(f"[URL] 外部公開網址 (Flutter 用): {public_url}")
        print("="*50 + "\n")
        # 存進狀態中讓 API 拿得到
        app.state.public_url = public_url
    except Exception as e:
        print(f"[ERROR] Ngrok 啟動失敗 ({e})")
        # 即使 Ngrok 失敗，也嘗試抓取看看是否有既存的隧道 URL
        try:
            tunnels = ngrok.get_tunnels()
            if tunnels:
                app.state.public_url = tunnels[0].public_url
                print(f"[REUSE] 偵測到既存隧道，正在沿用: {app.state.public_url}")
        except:
            pass

if __name__ == "__main__":
    # 使用 uvicorn 啟動
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
