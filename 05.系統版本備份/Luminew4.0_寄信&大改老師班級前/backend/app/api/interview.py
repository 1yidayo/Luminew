# app/api/interview.py
# 即時語音面試 WebSocket API + D-ID REST API
import asyncio
import json
import threading
import uuid
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request
from pydantic import BaseModel
from typing import Any, Dict, List, Optional
from app.services.InterviewManager import InterviewManager
from app.services.professor_persona import get_professor_persona

router = APIRouter()

# 每個 WebSocket 連線的 client 都有自己的 InterviewManager
clients = {}

# D-ID REST API 工作階段
interview_sessions = {}
# ★ D-ID Stream ID 到內部 Session ID 的映射，用於 Webhook 尋人
stream_to_session = {}
# ★ 新增：暫存 D-ID 透過 Webhook 送來的 ICE Candidates (WebSocket 尚未連線時使用)
pending_ice_candidates = {}  # session_id → [ice_data, ...]


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

class StartInterviewPayload(BaseModel):
    professor_type: str = "warm_industry_professor"
    interview_type: str = "im"
    custom_questions: Optional[List[str]] = None

@router.post("/start")
async def start_interview(payload: StartInterviewPayload, request: Request):
    """
    Flutter 呼叫此 API，後端建立 D-ID 房間，並回傳 WebRTC Offer
    """
    try:
        # 從 main.py 的 app.state 取得公開網址
        public_url = getattr(request.app.state, "public_url", None)
        
        professor_type = payload.professor_type
        print(f"[INIT] 正在啟動面試官: {professor_type}")

        # 初始化面試官 (完全無頭模式：啟用 D-ID、關閉本機麥克風)
        manager = InterviewManager(
            professor_type=professor_type, 
            department=payload.interview_type,
            use_did=True,
            custom_questions=payload.custom_questions
        )
        manager.public_url = public_url
        
        print("[WAIT] 收到 Flutter 請求，正在申請 D-ID... ")
        offer_info = await asyncio.to_thread(manager.create_did_stream)
        if "error" in offer_info:
            return {"status": "error", "message": offer_info["error"]}
            
        session_id = str(uuid.uuid4())
        interview_sessions[session_id] = manager
        
        # ★ 註冊映射，讓 Webhook 知道 D-ID 提到的是哪個面試
        if manager.did_stream_id:
            stream_to_session[manager.did_stream_id] = session_id
        
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
    result = await manager.submit_did_sdp_answer(payload.answer)
    return result

@router.post("/webrtc-ice")
async def receive_webrtc_ice(payload: ICEPayload):
    manager = interview_sessions.get(payload.session_id)
    if not manager: return {"error": "Session not found"}
    result = await manager.submit_did_ice_candidate(payload.candidate, payload.sdpMid, payload.sdpMLineIndex)
    return result

@router.post("/did-webhook")
async def did_webhook(request: Request):
    """
    接收來自 D-ID 的 Webhook 通知 (包含 ICE 候選人)
    """
    try:
        data = await request.json()
        print(f" [SYMBOL]  [D-ID Webhook] 收到事件: {json.dumps(data)}")
        
        # D-ID 的事件結構通常包含 stream_id 
        stream_id = data.get("stream_id") or data.get("id")
        if not stream_id:
            return {"status": "ignored"}

        # 找到對應的面試 Session
        session_id = stream_to_session.get(stream_id)
        if not session_id:
            print(f"[WARN] Webhook 找不到對應的 Session: stream_id={stream_id}")
            return {"status": "not_found"}

        event_kind = data.get("kind", "")
        print(f" [SYMBOL]  [D-ID Webhook] session={session_id}, kind={event_kind}")
        print(f"[SIGNAL] [DEBUG Webhook] Payload: {json.dumps(data)}")
        
        if event_kind == "ice":
            ice = data.get("ice", {})
            
            if session_id in clients:
                # [OK] WebSocket 已連線，直接轉發
                manager = clients[session_id]
                print(f"[SIGNAL] [D-ID ICE] 直接轉發給前端 (WebSocket 已連線): {session_id}")
                if hasattr(manager, "on_did_ice") and manager.on_did_ice:
                    await manager.on_did_ice(ice)
            else:
                # [WAIT] WebSocket 尚未連線，先緩存 ICE Candidate
                if session_id not in pending_ice_candidates:
                    pending_ice_candidates[session_id] = []
                pending_ice_candidates[session_id].append(ice)
                print(f" [SYMBOL]  [D-ID ICE] 緩存 ICE Candidate (WebSocket 尚未連線), 累計 {len(pending_ice_candidates[session_id])} 個")
        
        elif event_kind == "talk/completed":
            print(f"[OK] [D-ID Webhook] 偵測到教授說話完畢 (talk/completed): {session_id}")
            if session_id in clients:
                manager = clients[session_id]
                # 觸發 manager 的說話完畢事件
                if hasattr(manager, "handle_did_talk_completed"):
                    await manager.handle_did_talk_completed()

        return {"status": "ok"}
    except Exception as e:
        print(f"[ERROR] Webhook 處理失敗: {e}")
        return {"status": "error"}


# ─────────────────────────────
# WebSocket 即時串流端點
# ─────────────────────────────

@router.websocket("/ws/{client_id}")
async def interview_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    print(f"[OK] Client {client_id} 已連線")

    # ★ 取得 D-ID 面試所建立的 manager，避免重新建立一個預設（無 D-ID）的版本
    if client_id in interview_sessions:
        manager = interview_sessions[client_id]
        print(f"[OK] 找到對應的 D-ID 面試 session_id: {client_id}")
    else:
        print(f"[WARN] 找不到對應的 D-ID 面試 session_id: {client_id}，建立預設版本...")
        persona = get_professor_persona("warm_industry_professor")
        manager = InterviewManager(professor_type=persona.name)
        
    clients[client_id] = manager
    manager.interview_running = True

    # ★ 補送 WebSocket 連線前已緩存的 D-ID ICE Candidates
    if client_id in pending_ice_candidates:
        buffered = pending_ice_candidates.pop(client_id)
        print(f" [SYMBOL]  [ICE 補送] 找到 {len(buffered)} 個緩存的 D-ID ICE Candidates，即將補送...")
        async def _flush_pending_ice():
            for ice in buffered:
                await asyncio.sleep(0.1)  # 小延遲避免前端還沒準備好
                try:
                    await websocket.send_text(json.dumps({
                        "event": "did_ice",
                        "candidate": ice.get("candidate"),
                        "sdpMid": ice.get("sdpMid"),
                        "sdpMLineIndex": ice.get("sdpMLineIndex")
                    }))
                    print(f" [SYMBOL]  [ICE 補送] 已送出 ICE 給前端: {str(ice)[:60]}...")
                except Exception as e:
                    print(f"[ERROR] [ICE 補送] 送出失敗: {e}")
        asyncio.create_task(_flush_pending_ice())
    else:
        print(f"ℹ️ [ICE 補送] 無緩存 ICE (session_id={client_id})")

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

    async def _on_did_ice(ice_data):
        """轉發 D-ID 端的 ICE Candidate 到前端"""
        try:
            await websocket.send_text(json.dumps({
                "event": "did_ice",
                "candidate": ice_data.get("candidate"),
                "sdpMid": ice_data.get("sdpMid"),
                "sdpMLineIndex": ice_data.get("sdpMLineIndex")
            }))
        except Exception:
            pass
    manager.on_did_ice = _on_did_ice

    async def _on_tts_done():
        try:
            await websocket.send_text(json.dumps({"event": "tts_done"}))
        except Exception:
            pass
    manager.on_tts_done = _on_tts_done

    async def _on_tts_start():
        try:
            await websocket.send_text(json.dumps({"event": "tts_start"}))
        except Exception:
            pass
    manager.on_tts_start = _on_tts_start

    # 在背景非同步啟動面試（包含 STT + AI 打招呼）
    async def run_interview():
        try:
            await manager.start_interview()
        except Exception as e:
            print(f"[ERROR] 面試啟動失敗: {e}")
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
                
                elif event == "did_ice":
                    # 前端找到了它的網路路徑，我們必須轉發給 D-ID！
                    if getattr(manager, "use_did", False) and getattr(manager, "did_stream_id", None):
                        candidate_data = {
                            "candidate": data.get("candidate"),
                            "sdpMid": data.get("sdpMid"),
                            "sdpMLineIndex": data.get("sdpMLineIndex"),
                            "session_id": manager.did_session_id
                        }
                        asyncio.create_task(manager.submit_did_ice(candidate_data))

            elif "bytes" in message:
                # 收到前端傳來的音訊串流，直接餵給 STT
                manager.stt.feed_audio(message["bytes"])

    except WebSocketDisconnect:
        print(f"[ERROR] Client {client_id} 斷線")
    except Exception as e:
        print(f"[ERROR] WebSocket 錯誤: {e}")
    finally:
        manager.interview_running = False
        manager.stop_interview()
        if client_id in clients:
            del clients[client_id]
        print(f" [SYMBOL]  Client {client_id} 清理完成")
