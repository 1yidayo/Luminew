# emotion.py
# 情緒分析 API 路由

from fastapi import APIRouter, UploadFile, File, Form, Request, BackgroundTasks
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from app.services.emotion_service import (
    analyze_video,
    analyze_portfolio,
    calibrate_baseline,
    get_video_storage_dir,
    flip_video_async
)
from app.services.question_generator import analyze_pdf_and_generate_questions
import uuid
import os
import json
import asyncio

router = APIRouter()

# ★ 全域 Job 狀態儲存（記憶體內，重啟後清空）
_jobs: dict = {}  # job_id -> {"status": "processing"|"done"|"error", "result": {...}}


async def _run_analysis_job(job_id: str, video_path: str, save_flag: bool,
                             baseline_dict, transcript_list, interviewer: str):
    """背景執行情緒分析，完成後更新 _jobs[job_id]"""
    try:
        result = await analyze_video(video_path, save_flag, baseline_dict, transcript_list, interviewer)
        if save_flag and "error" not in result:
            flip_video_async(video_path)
        _jobs[job_id] = {"status": "done", "result": result}
        print(f"✅ [Job {job_id}] 分析完成")
    except Exception as e:
        print(f"❌ [Job {job_id}] 分析失敗: {e}")
        _jobs[job_id] = {"status": "error", "result": {"error": str(e)}}


@router.post("/analyze")
async def api_analyze_video(
    background_tasks: BackgroundTasks,
    request: Request,
    video: UploadFile = File(...),
    save_video: str = Form(default="true"),
    baseline: str = Form(default=""),
    transcript: str = Form(default="[]"),
    interviewer: str = Form(default="warm_industry_professor")
):
    """
    非同步分析影片情緒（立即回傳 job_id，前端輪詢 /emotion/status/{job_id}）
    """
    # 儲存上傳的影片
    video_dir = get_video_storage_dir()
    ext = os.path.splitext(video.filename)[1] if video.filename else ".mp4"
    if not ext:
        ext = ".mp4"
    filename = f"{uuid.uuid4()}{ext}"
    video_path = os.path.join(video_dir, filename)

    content = await video.read()
    with open(video_path, "wb") as f:
        f.write(content)

    print(f"[INPUT] 收到影片，已存檔至: {video_path}")

    # 解析 baseline
    baseline_dict = None
    if baseline and baseline.strip():
        try:
            baseline_dict = json.loads(baseline)
        except json.JSONDecodeError:
            print("[WARN] baseline JSON 解析失敗，忽略")

    # 解析 transcript
    try:
        transcript_list = json.loads(transcript)
    except json.JSONDecodeError:
        transcript_list = []

    save_flag = save_video.lower() == "true"

    # ★ 建立 job，在背景執行分析
    job_id = str(uuid.uuid4())
    _jobs[job_id] = {"status": "processing", "result": None}
    background_tasks.add_task(
        _run_analysis_job, job_id, video_path, save_flag, baseline_dict, transcript_list, interviewer
    )

    # ★ 立刻回傳 job_id（不等分析完成，避免 Cloudflare 524 超時）
    print(f"🚀 [Job {job_id}] 已建立，分析在背景執行中...")
    return JSONResponse({"job_id": job_id, "status": "processing"})


@router.get("/status/{job_id}")
async def api_get_job_status(job_id: str):
    """輪詢分析進度，done 時回傳完整結果"""
    job = _jobs.get(job_id)
    if job is None:
        return JSONResponse(status_code=404, content={"error": "Job not found"})
    return JSONResponse(job)


@router.post("/upload_chunk")
async def api_upload_chunk(
    session_id: str = Form(...),
    chunk_index: int = Form(...),
    total_chunks: int = Form(...),
    video: UploadFile = File(...),
    save_video: str = Form(default="true"),
    baseline: str = Form(default=""),
    transcript: str = Form(default="[]"),
    interviewer: str = Form(default="warm_industry_professor")
):
    video_dir = get_video_storage_dir()
    temp_path = os.path.join(video_dir, f"temp_{session_id}.mp4")
    
    content = await video.read()
    mode = "ab" if chunk_index > 0 else "wb"
    with open(temp_path, mode) as f:
        f.write(content)
        
    print(f"📦 [Chunk Upload] Session: {session_id}, Chunk: {chunk_index + 1}/{total_chunks}")
    
    # If it is the last chunk, perform analysis
    if chunk_index == total_chunks - 1:
        # Generate final file name
        ext = os.path.splitext(video.filename)[1] if video.filename else ".mp4"
        if not ext:
            ext = ".mp4"
        final_filename = f"{uuid.uuid4()}{ext}"
        final_path = os.path.join(video_dir, final_filename)
        os.rename(temp_path, final_path)
        
        print(f"[INPUT] 影片組裝完成，存檔至: {final_path}")
        
        baseline_dict = None
        if baseline and baseline.strip():
            try:
                baseline_dict = json.loads(baseline)
            except json.JSONDecodeError:
                pass

        try:
            transcript_list = json.loads(transcript)
        except json.JSONDecodeError:
            transcript_list = []
        
        save_flag = save_video.lower() == "true"
        result = await analyze_video(final_path, save_flag, baseline_dict, transcript_list, interviewer)
        
        if "error" in result:
            status = 200 if "No face" in result.get("error", "") else 500
            return JSONResponse(status_code=status, content=result)
            
        # [FIX] 使用者要求：還原翻轉處理，以跟 PIP 方向一致
        if save_flag:
            flip_video_async(final_path)
        
        return result
        
    return {"status": "chunk received"}


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
    
    print(f"[TARGET] 收到校準影片，已存檔至: {video_path}")
    
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
    
    print(f"[FILE] 收到 PDF: {pdf.filename}")
    
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
    
    print(f"[FILE] 收到問題生成請求: {pdf.filename} (類型: {interview_type})")
    
    # 分析 PDF 並生成問題
    result = await analyze_pdf_and_generate_questions(pdf_path, interview_type)
    
    # 刪除暫存 PDF
    try:
        os.remove(pdf_path)
    except:
        pass
    
    return result
