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

app.mount("/public", StaticFiles(directory=os.path.join("app", "public")), name="public")
app.mount("/audio", StaticFiles(directory=os.path.join("app", "public", "audio")), name="audio")
app.mount("/static/videos", StaticFiles(directory=VIDEO_STORAGE_DIR), name="videos")



# 引入面試的 Router 與 Database Router
app.include_router(interview_router, prefix="/api/interview", tags=["Interview"])
app.include_router(db_router, prefix="/api/db", tags=["Database"])

@app.get("/health")
async def health_check():
    """
    【內測診斷工具 V2】
    檢查主機、GPU 以及最重要的「資料庫連線」
    """
    # 1. GPU 檢查
    gpu_data = {"status": "Not Available"}
    if torch.cuda.is_available():
        gpu_data = {
            "status": "Available",
            "name": torch.cuda.get_device_name(0),
            "vram_total_mb": int(torch.cuda.get_device_properties(0).total_memory / (1024**2))
        }

    # 2. 資料庫檢查
    db_status = "Checking..."
    try:
        from app.database.db import execute_read
        res = execute_read("SELECT 1 as test")
        db_status = "Connected" if res else "Connection Failed (Empty Result)"
    except Exception as e:
        db_status = f"Connection Error: {str(e)}"

    return {
        "status": "online",
        "server": "Luminew-GPU-Workstation (Root)",
        "db": db_status,
        "gpu": gpu_data,
        "time": datetime.datetime.now().isoformat()
    }

app.include_router(emotion_router, prefix="/emotion", tags=["Emotion"])

@app.on_event("startup")
async def startup_event():
    """伺服器啟動時的初始化 (支援固定 IP 與 Ngrok 備援切換)"""
    print("\n" + "="*50)
    
    # 從 .env 讀取開關，預設為 False (使用固定 IP)
    use_ngrok = os.getenv("USE_NGROK", "False").lower() == "true"
    
    if use_ngrok:
        print("[MODE] 備援模式：啟動 Ngrok 隧道...")
        try:
            print("[FIX] 正在清理舊的 Ngrok 連線...")
            ngrok.kill() 
            auth_token = os.getenv("NGROK_AUTHTOKEN")
            if auth_token and auth_token.strip():
                ngrok.set_auth_token(auth_token.strip())
                print("[KEY] Ngrok Authtoken 已載入")
            
            public_url = ngrok.connect(8000).public_url
            print(f"[URL] 外部公開網址 (Flutter 用): {public_url}")
            app.state.public_url = public_url
        except Exception as e:
            print(f"[ERROR] Ngrok 啟動失敗 ({e})，切換回預設固定 IP")
            app.state.public_url = "http://140.136.155.145:8000"
    else:
        print("[MODE] 正式營運模式：優先使用環境變數中的 PUBLIC_URL")
        public_url = os.getenv("PUBLIC_URL")
        if public_url:
            app.state.public_url = public_url
        else:
            app.state.public_url = "http://140.136.155.145:8000"
        
    print(f"[FINAL] 目前對外 API 位址: {app.state.public_url}")
    print("="*50 + "\n")

if __name__ == "__main__":
    # 在生產環境 (學校電腦) 務必將 reload 設為 False 
    # 這樣才不會因為寫入日誌導致 Ngrok 無限重啟
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)

# ★ Flutter Web 根路徑掛載（必須在所有 API route 之後）
# base href="/" 要求靜態檔在根路徑，這樣 flutter_bootstrap.js 才能被正確載入
web_build_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web_build")
os.makedirs(web_build_dir, exist_ok=True)

from fastapi.responses import HTMLResponse
@app.get("/app")
async def get_app_bypass_cache():
    """提供一個全新的路徑來繞過 Cloudflare HTML 快取"""
    html_path = os.path.join(web_build_dir, "index.html")
    with open(html_path, "r", encoding="utf-8") as f:
        content = f.read()
    # 動態注入時間戳確保絕對不會被快取
    import time
    content = content.replace("flutter_bootstrap.js", f"flutter_bootstrap.js?t={int(time.time())}")
    return HTMLResponse(content=content, headers={
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
        "Expires": "0"
    })

app.mount("/", StaticFiles(directory=web_build_dir, html=True), name="web")
