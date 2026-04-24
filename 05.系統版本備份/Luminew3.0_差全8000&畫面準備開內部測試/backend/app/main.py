# main.py
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from app.api import interview, llm, tts, emotion, sql_proxy
from app.services.emotion_service import analyze_video, analyze_portfolio
from app.services.InterviewManager import InterviewManager
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Luminew")

# 設定靜態檔案目錄 (影片存取用)
static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
os.makedirs(os.path.join(static_dir, "videos"), exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

# ★ 設定 Flutter Web 靜態網站目錄
web_build_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "web_build")
os.makedirs(web_build_dir, exist_ok=True)
app.mount("/web", StaticFiles(directory=web_build_dir, html=True), name="web")

# 加入路由
app.include_router(interview.router, prefix="/interview", tags=["Interview"])
app.include_router(llm.router, prefix="/llm", tags=["LLM"])
app.include_router(tts.router, prefix="/tts", tags=["TTS"])
app.include_router(emotion.router, prefix="/emotion", tags=["Emotion"])
app.include_router(sql_proxy.router, prefix="/sql", tags=["SQL Proxy"])

@app.get("/")
def root():
    return {"message": "Luminew 即時語音練習 API 正在運行"}

# ========== ★★★ 統合 API（新增）★★★ ==========

@app.post("/complete_interview")
async def complete_interview(
    video: UploadFile = File(...),
    pdf: UploadFile = File(...),
    professor_type: str = Form(default="warm_industry_professor")
):
    """
    【完整面試流程】
    一次呼叫就能：
    1. 分析學習歷程 PDF
    2. 進行面試 (InterviewManager - 非同步多線程)
    3. 分析面試表現（情緒辨識 - 非同步多線程）
    4. 返回完整反饋
    
    Parameters:
        - video: 面試錄影檔案 (MP4)
        - pdf: 學習歷程 PDF
        - professor_type: 教授人格類型 (預設: warm_industry_professor)
    
    Returns:
        {
            "status": "success",
            "portfolio_analysis": {...},
            "interview_emotions": {...},
            "overall_score": 75,
            "overall_feedback": "..."
        }
    """
    
    try:
        video_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "videos")
        parent_dir = os.path.dirname(video_dir)
        os.makedirs(parent_dir, exist_ok=True)
        os.makedirs(video_dir, exist_ok=True)
        
        # ========== Step 1: 儲存並分析學習歷程 ==========
        pdf_filename = f"{uuid.uuid4()}.pdf"
        pdf_path = os.path.join(parent_dir, pdf_filename)
        
        pdf_content = await pdf.read()
        with open(pdf_path, "wb") as f:
            f.write(pdf_content)
        
        print(f"[FILE] 收到 PDF: {pdf.filename}")
        portfolio_result = await analyze_portfolio(pdf_path)
        
        # ========== Step 2: 進行面試（非同步多線程）==========
        print("[ACAD] 啟動面試流程...")
        manager = InterviewManager(professor_type=professor_type)
        manager.start_interview()
        
        # ========== Step 3: 儲存並分析面試影片（非同步多線程）==========
        video_filename = f"{uuid.uuid4()}.mp4"
        video_path = os.path.join(video_dir, video_filename)
        
        video_content = await video.read()
        with open(video_path, "wb") as f:
            f.write(video_content)
        
        print(f"[INPUT] 收到影片，已存檔至: {video_path}")
        interview_result = await analyze_video(video_path, save_video=True)
        
        # ========== Step 4: 整合所有結果 ==========
        manager.stop_interview()
        
        # 計算綜合分數
        portfolio_score = portfolio_result.get("analysis", {}).get("overall_score", 0) if "analysis" in portfolio_result else 0
        interview_score = interview_result.get("ai_analysis", {}).get("overall_score", 0) if "ai_analysis" in interview_result else 0
        
        overall_score = int((portfolio_score + interview_score) / 2) if portfolio_score and interview_score else 0
        
        return {
            "status": "success",
            "portfolio_analysis": portfolio_result,
            "interview_emotions": interview_result,
            "overall_score": overall_score,
            "overall_feedback": f"恭喜！你的綜合表現評分為 {overall_score} 分。" if overall_score > 0 else "分析完成，請查看詳細結果。"
        }
        
    except Exception as e:
        print(f"[ERROR] 統合面試流程錯誤: {e}")
        import traceback
        traceback.print_exc()
        return {
            "status": "error",
            "message": str(e)
        }