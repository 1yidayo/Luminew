# app/api/interview.py
# 完整 FastAPI / Flutter 面試接接端點
import asyncio
import json
import threading
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request
from pydantic import BaseModel
from typing import Any, Dict
from app.services.InterviewManager import InterviewManager

router = APIRouter()

# 儲存全域的面試管理員實例 (Key: session_id, Value: manager)
interview_sessions: Dict[str, InterviewManager] = {}

class AnswerPayload(BaseModel):
    answer: Any
    session_id: str

class ICEPayload(BaseModel):
    candidate: str
    sdpMid: str
    sdpMLineIndex: int
    session_id: str

@router.post("/start")
async def start_interview(request: Request):
    """
    Flutter 呼叫此 API，後端建立 D-ID 房間，並回傳 WebRTC Offer
    """
    try:
        # 從 main.py 的 app.state 取得公開網址
        public_url = getattr(request.app.state, "public_url", None)
        
        # 初始化面試官 (完全無頭模式：啟用 D-ID、關閉本機麥克風)
        manager = InterviewManager(
            professor_type="warm_industry_professor", 
            use_did=True, 
            use_microphone=False
        )
        manager.public_url = public_url
        
        print("⏳ 收到 Flutter 請求，正在申請 D-ID... ")
        offer_info = manager.create_did_stream()
        if "error" in offer_info:
            return {"status": "error", "message": offer_info["error"]}
            
        session_id = manager.did_session_id
        interview_sessions[session_id] = manager
        
        return {
            "status": "success",
            "session_id": session_id,
            "offer": offer_info
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@router.post("/webrtc-answer")
async def receive_webrtc_answer(payload: AnswerPayload):
    manager = interview_sessions.get(payload.session_id)
    if not manager: return {"error": "Session not found"}
    result = manager.submit_did_sdp_answer(payload.answer, payload.session_id)
    return result

@router.post("/webrtc-ice")
async def receive_webrtc_ice(payload: ICEPayload):
    manager = interview_sessions.get(payload.session_id)
    if not manager: return {"error": "Session not found"}
    result = manager.submit_did_ice_candidate(payload.candidate, payload.sdpMid, payload.sdpMLineIndex, payload.session_id)
    return result

@router.websocket("/ws/{session_id}")
async def interview_websocket(websocket: WebSocket, session_id: str):
    """
    處理即時推播與音訊串流的 WebSocket 長連線
    """
    await websocket.accept()
    manager = interview_sessions.get(session_id)
    if not manager:
        await websocket.close(code=1008)
        return
        
    print(f"✅ Flutter 成功連線到 WebSocket 房間: {session_id}")
    
    event_queue = asyncio.Queue()
    main_loop = asyncio.get_event_loop()

    def send_event_from_thread(event_data):
        main_loop.call_soon_threadsafe(event_queue.put_nowait, event_data)

    # 將事件推入佇列準備送給 Flutter
    manager.on_transcript = lambda role, text: send_event_from_thread({
        "type": "json", "data": {"event": "transcript", "role": role, "text": text}
    })
    manager.on_audio_chunk = lambda chunk_bytes: send_event_from_thread({
        "type": "binary", "data": chunk_bytes
    })
    manager.on_tts_done = lambda: send_event_from_thread({
        "type": "json", "data": {"event": "tts_done"}
    })

    # 在背景啟動面試流程 (開場白)
    threading.Thread(target=manager.start_interview, daemon=True).start()

    async def forward_events():
        """發送任務到 Flutter"""
        try:
            while True:
                event = await event_queue.get()
                if event is None: break
                if event["type"] == "json":
                    await websocket.send_text(json.dumps(event["data"]))
                elif event["type"] == "binary":
                    await websocket.send_bytes(event["data"])
        except asyncio.CancelledError:
            pass

    forward_task = asyncio.create_task(forward_events())

    try:
        while True:
            message = await websocket.receive()
            if "text" in message:
                data = json.loads(message["text"])
                if data.get("event") == "speech_end":
                    # 前端告知斷句了，啟動 LLM
                    threading.Thread(target=manager.process_speech_end, daemon=True).start()
                elif data.get("event") == "stop_interview":
                    break
                    
            elif "bytes" in message:
                # 接收 Flutter 每秒鐘傳來的一片音訊 (PCM 16-bit)
                manager.feed_audio(message["bytes"])
                
    except WebSocketDisconnect:
        print(f"❌ Flutter 裝置已斷線: {session_id}")
    finally:
        manager.stop_interview()
        event_queue.put_nowait(None)
        forward_task.cancel()
        if session_id in interview_sessions:
            del interview_sessions[session_id]
        print(f"🧹 房間 {session_id} 記憶體清理完畢。")