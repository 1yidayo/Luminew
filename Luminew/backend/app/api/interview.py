# app/api/interview.py
# 即時語音面試 WebSocket API + D-ID REST API
import asyncio
import json
import threading
import uuid
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request
from pydantic import BaseModel
from typing import Any, Dict
from app.services.InterviewManager import InterviewManager
from app.services.professor_persona import get_professor_persona

router = APIRouter()

# 每個 WebSocket 連線的 client 都有自己的 InterviewManager
clients = {}

# D-ID REST API 工作階段
interview_sessions = {}


# ─────────────────────────────
# D-ID REST API 端點
# ─────────────────────────────

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
            use_did=True
        )
        manager.public_url = public_url
        
        print("⏳ 收到 Flutter 請求，正在申請 D-ID... ")
        offer_info = manager.create_did_stream()
        if "error" in offer_info:
            return {"status": "error", "message": offer_info["error"]}
            
        session_id = str(uuid.uuid4())
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
    result = manager.submit_did_sdp_answer(payload.answer)
    return result

@router.post("/webrtc-ice")
async def receive_webrtc_ice(payload: ICEPayload):
    manager = interview_sessions.get(payload.session_id)
    if not manager: return {"error": "Session not found"}
    result = manager.submit_did_ice_candidate(payload.candidate, payload.sdpMid, payload.sdpMLineIndex)
    return result


# ─────────────────────────────
# WebSocket 即時串流端點
# ─────────────────────────────

@router.websocket("/ws/{client_id}")
async def interview_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    print(f"✅ Client {client_id} 已連線")

    # ★ 取得 D-ID 面試所建立的 manager，避免重新建立一個預設（無 D-ID）的版本
    if client_id in interview_sessions:
        manager = interview_sessions[client_id]
        print(f"✅ 找到對應的 D-ID 面試 session_id: {client_id}")
    else:
        print(f"⚠️ 找不到對應的 D-ID 面試 session_id: {client_id}，建立預設版本...")
        persona = get_professor_persona("warm_industry_professor")
        manager = InterviewManager(professor_type=persona.name)
        
    clients[client_id] = manager
    manager.interview_running = True

    # ★ 設定回呼：讓 InterviewManager 的事件能傳到 WebSocket (非同步呼叫)
    async def _on_transcript(role, text):
        try:
            await websocket.send_text(json.dumps({
                "event": "transcript", "role": role, "text": text
            }))
        except Exception:
            pass
    manager.on_transcript = _on_transcript

    async def _on_audio_chunk(chunk_bytes):
        await websocket.send_bytes(chunk_bytes)
    manager.on_audio_chunk = _on_audio_chunk

    async def _on_tts_done():
        try:
            await websocket.send_text(json.dumps({"event": "tts_done"}))
        except Exception:
            pass
    manager.on_tts_done = _on_tts_done

    # 在背景非同步啟動面試（包含 STT + AI 打招呼）
    async def run_interview():
        try:
            await manager.start_interview()
        except Exception as e:
            print(f"❌ 面試啟動失敗: {e}")
            import traceback
            traceback.print_exc()

    asyncio.create_task(run_interview())

    # 通知前端面試已開始
    await websocket.send_text(json.dumps({
        "event": "interview_started",
        "professor": manager.professor_persona.name
    }))

    try:
        while True:
            message = await websocket.receive()

            if "text" in message:
                data = json.loads(message["text"])
                event = data.get("event", "")

                if event == "stop_interview":
                    manager.stop_interview()
                    await websocket.send_text(json.dumps({
                        "event": "interview_stopped"
                    }))
                    break

                elif event == "speech_end":
                    # 前端告知學生說完話了，觸發 LLM 回覆
                    asyncio.create_task(manager.process_speech_end())

            elif "bytes" in message:
                # 收到前端傳來的音訊串流，直接餵給 STT
                manager.stt.feed_audio(message["bytes"])

    except WebSocketDisconnect:
        print(f"❌ Client {client_id} 斷線")
    except Exception as e:
        print(f"❌ WebSocket 錯誤: {e}")
    finally:
        manager.interview_running = False
        manager.stop_interview()
        if client_id in clients:
            del clients[client_id]
        print(f"🧹 Client {client_id} 清理完成")
