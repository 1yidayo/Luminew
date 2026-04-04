# app/api/interview.py
# 即時語音面試 WebSocket API
import asyncio
import json
import threading
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.services.InterviewManager import InterviewManager
from app.services.professor_persona import get_professor_persona

router = APIRouter()

# 每個連線的 client 都有自己的 InterviewManager
clients = {}

@router.websocket("/ws/{client_id}")
async def interview_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    print(f"✅ Client {client_id} 已連線")

    persona = get_professor_persona("warm_industry_professor")
    manager = InterviewManager(professor_type=persona.name)
    clients[client_id] = manager
    manager.interview_running = True

    # ★ 設定回呼：讓 InterviewManager 的事件能傳到 WebSocket (非同步呼叫)
    async def _on_transcript(role, text):
        await websocket.send_text(json.dumps({
            "event": "transcript", "role": role, "text": text
        }))
    manager.on_transcript = _on_transcript

    async def _on_audio_chunk(chunk_bytes):
        await websocket.send_bytes(chunk_bytes)
    manager.on_audio_chunk = _on_audio_chunk

    async def _on_tts_done():
        await websocket.send_text(json.dumps({"event": "tts_done"}))
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