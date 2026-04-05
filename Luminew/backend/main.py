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
app.include_router(emotion_router, prefix="/emotion", tags=["Emotion"])

@app.on_event("startup")
async def startup_event():
    """伺服器啟動時，自動建立 Ngrok 隧道"""
    print("\n" + "="*50)
    print("⏳ 正在啟動伺服器與 Ngrok 隧道...")
    try:
        # 檢查並設定 authtoken
        auth_token = os.getenv("NGROK_AUTHTOKEN")
        if auth_token and auth_token.strip():
            ngrok.set_auth_token(auth_token.strip())
            print("🔑 Ngrok Authtoken 已載入")
        
        # 設定區域 (日本)
        conf.get_default().region = "jp"
        
        # ngrok 預設開啟 port 8000
        public_url = ngrok.connect(8000).public_url
        print(f"🌍 外部公開網址 (Flutter 用): {public_url}")
        print("="*50 + "\n")
        # 存進狀態中讓 API 拿得到
        app.state.public_url = public_url
    except Exception as e:
        print(f"❌ Ngrok 啟動失敗 ({e})\n請確認是否已註冊 Authtoken。")

if __name__ == "__main__":
    # 使用 uvicorn 啟動
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
