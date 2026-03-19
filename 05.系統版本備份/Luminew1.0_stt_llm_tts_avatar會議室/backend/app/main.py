# main.py
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.api import interview, llm, tts, emotion  # 不 import stt
import os
from dotenv import load_dotenv
load_dotenv()

app = FastAPI(title="Luminew")

# 設定靜態檔案目錄 (影片存取用)
static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
os.makedirs(os.path.join(static_dir, "videos"), exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

# 加入路由
app.include_router(interview.router, prefix="/interview", tags=["Interview"])
app.include_router(llm.router, prefix="/llm", tags=["LLM"])
app.include_router(tts.router, prefix="/tts", tags=["TTS"])
app.include_router(emotion.router, prefix="/emotion", tags=["Emotion"])
app.include_router(interview.router, prefix="/interview", tags=["Interview"])

@app.get("/")
def root():
    return {"message": "Luminew 即時語音練習 API 正在運行"}