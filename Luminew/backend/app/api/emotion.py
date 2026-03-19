# emotion.py
# 情緒分析 API 路由

from fastapi import APIRouter, UploadFile, File, Form, Request
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from app.services.emotion_service import (
    analyze_video, 
    analyze_portfolio, 
    calibrate_baseline,
    get_video_storage_dir
)
from app.services.question_generator import analyze_pdf_and_generate_questions
import uuid
import os
import json

router = APIRouter()


@router.post("/analyze")
async def api_analyze_video(
    video: UploadFile = File(...),
    save_video: str = Form(default="true"),
    baseline: str = Form(default="")
):
    """
    分析影片情緒
    
    - **video**: 上傳的影片檔案 (MP4)
    - **save_video**: 是否保存影片 ("true" / "false")
    - **baseline**: 個人校準基線 JSON（可選，由 /emotion/calibrate 取得）
    
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
    
    # ★ 解析 baseline（如果有的話）
    baseline_dict = None
    if baseline and baseline.strip():
        try:
            baseline_dict = json.loads(baseline)
            print(f"🎯 收到個人基線: {baseline_dict}")
        except json.JSONDecodeError:
            print("⚠️ baseline JSON 解析失敗，忽略")
    
    # 分析影片（帶上 baseline）
    save_flag = save_video.lower() == "true"
    result = await analyze_video(video_path, save_flag, baseline_dict)
    
    if "error" in result:
        status = 400 if "No face" in result.get("error", "") else 500
        return JSONResponse(content=result, status_code=status)
    
    return result


@router.post("/calibrate")
async def api_calibrate(
    video: UploadFile = File(...)
):
    """
    個人化校準：掃描自然表情，建立情緒基線
    
    - **video**: 5-10 秒的短影片（自然表情）
    
    Returns:
        {"success": true, "baseline": {"confidence": 35.2, "nervous": 25.1, ...}, "frames_analyzed": 50}
    """
    video_dir = get_video_storage_dir()
    filename = f"calibrate_{uuid.uuid4()}.mp4"
    video_path = os.path.join(video_dir, filename)
    
    content = await video.read()
    with open(video_path, "wb") as f:
        f.write(content)
    
    print(f"🎯 收到校準影片，已存檔至: {video_path}")
    
    result = await calibrate_baseline(video_path)
    
    if "error" in result:
        return JSONResponse(content=result, status_code=400)
    
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
        return JSONResponse(content=result, status_code=400)
    
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
