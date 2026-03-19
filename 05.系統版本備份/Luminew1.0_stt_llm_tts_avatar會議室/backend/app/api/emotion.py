# emotion.py
# 情緒分析 API 路由

from fastapi import APIRouter, UploadFile, File, Form, Request
from fastapi.responses import FileResponse, StreamingResponse
from app.services.emotion_service import (
    analyze_video, 
    analyze_portfolio, 
    get_video_storage_dir
)
from app.services.question_generator import analyze_pdf_and_generate_questions
import uuid
import os

router = APIRouter()


@router.post("/analyze")
async def api_analyze_video(
    video: UploadFile = File(...),
    save_video: str = Form(default="true")
):
    """
    分析影片情緒
    
    - **video**: 上傳的影片檔案 (MP4)
    - **save_video**: 是否保存影片 ("true" / "false")
    
    Returns:
        情緒分析結果，包含 emotions, timeline, ai_analysis, video_url
    """
    # 儲存上傳的影片
    video_dir = get_video_storage_dir()
    filename = f"{uuid.uuid4()}.mp4"
    video_path = os.path.join(video_dir, filename)
    
    content = await video.read()
    with open(video_path, "wb") as f:
        f.write(content)
    
    print(f"📥 收到影片，已存檔至: {video_path}")
    
    # 分析影片
    save_flag = save_video.lower() == "true"
    result = await analyze_video(video_path, save_flag)
    
    if "error" in result:
        return result, 400 if "No face" in result.get("error", "") else 500
    
    return result


@router.post("/analyze_portfolio")
async def api_analyze_portfolio(pdf: UploadFile = File(...)):
    """
    分析學習歷程 PDF
    
    - **pdf**: 上傳的 PDF 檔案
    
    Returns:
        學習歷程分析結果
    """
    # 儲存上傳的 PDF
    video_dir = get_video_storage_dir()
    parent_dir = os.path.dirname(video_dir)
    pdf_filename = f"{uuid.uuid4()}.pdf"
    pdf_path = os.path.join(parent_dir, pdf_filename)
    
    content = await pdf.read()
    with open(pdf_path, "wb") as f:
        f.write(content)
    
    print(f"📄 收到 PDF: {pdf.filename}")
    
    # 分析 PDF
    result = await analyze_portfolio(pdf_path)
    
    if "error" in result:
        return result, 400
    
    return result


@router.post("/generate_questions")
async def api_generate_questions(
    pdf: UploadFile = File(...),
    interview_type: str = Form(default="通用型")
):
    """
    分析 PDF 並生成個人化面試問題
    
    - **pdf**: 上傳的 PDF 檔案（學習歷程/履歷）
    - **interview_type**: 面試類型（通用型/科系專業/學經歷）
    
    Returns:
        生成的面試問題列表
    """
    # 儲存上傳的 PDF
    video_dir = get_video_storage_dir()
    parent_dir = os.path.dirname(video_dir)
    pdf_filename = f"questions_{uuid.uuid4()}.pdf"
    pdf_path = os.path.join(parent_dir, pdf_filename)
    
    content = await pdf.read()
    with open(pdf_path, "wb") as f:
        f.write(content)
    
    print(f"📄 收到問題生成請求: {pdf.filename} (類型: {interview_type})")
    
    # 分析 PDF 並生成問題
    result = await analyze_pdf_and_generate_questions(pdf_path, interview_type)
    
    # 刪除暫存 PDF
    try:
        os.remove(pdf_path)
    except:
        pass
    
    return result
