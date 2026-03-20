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

    # 使用同學的架構：InterviewManager 透過 sounddevice 錄音/播放
    persona = get_professor_persona("warm_industry_professor")
    manager = InterviewManager(professor_type=persona.name)
    clients[client_id] = manager
    manager.interview_running = True

    # ★★★ 新增：建立 asyncio Queue 來橋接 thread → WebSocket ★★★
    event_queue = asyncio.Queue()
    main_loop = asyncio.get_event_loop()

    def send_event_from_thread(event_data):
        """從背景線程安全地發送事件到 asyncio 主迴圈"""
        main_loop.call_soon_threadsafe(event_queue.put_nowait, event_data)

    # ★ 設定回呼：讓 InterviewManager 的事件能傳到 WebSocket
    manager.on_transcript = lambda role, text: send_event_from_thread({
        "type": "json",
        "data": {"event": "transcript", "role": role, "text": text}
    })
    manager.on_audio_chunk = lambda chunk_bytes: send_event_from_thread({
        "type": "binary",
        "data": chunk_bytes
    })
    manager.on_tts_done = lambda: send_event_from_thread({
        "type": "json",
        "data": {"event": "tts_done"}
    })

    # 在背景線程啟動面試（包含 sounddevice 錄音 + STT + AI 打招呼）
    def run_interview():
        try:
            manager.start_interview()
        except Exception as e:
            print(f"❌ 面試啟動失敗: {e}")
            import traceback
            traceback.print_exc()

    interview_thread = threading.Thread(target=run_interview, daemon=True)
    interview_thread.start()

    # 通知前端面試已開始
    await websocket.send_text(json.dumps({
        "event": "interview_started",
        "professor": manager.professor_persona.name
    }))

    # ★★★ 新增：背景任務 — 從 event_queue 讀取事件並轉發到 WebSocket ★★★
    async def forward_events():
        """持續從 event_queue 讀取事件並發送到 WebSocket"""
        try:
            while True:
                event = await event_queue.get()
                if event is None:
                    break  # 結束信號
                try:
                    if event["type"] == "json":
                        await websocket.send_text(json.dumps(event["data"]))
                    elif event["type"] == "binary":
                        await websocket.send_bytes(event["data"])
                except Exception as e:
                    print(f"⚠️ 發送事件失敗: {e}")
                    break
        except asyncio.CancelledError:
            pass

    forward_task = asyncio.create_task(forward_events())

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
                    threading.Thread(
                        target=manager.process_speech_end,
                        daemon=True
                    ).start()

            elif "bytes" in message:
                # 預留介面（同學的架構用電腦麥克風，暫不處理前端音訊）
                pass

    except WebSocketDisconnect:
        print(f"❌ Client {client_id} 斷線")
    except Exception as e:
        print(f"❌ WebSocket 錯誤: {e}")
    finally:
        manager.interview_running = False
        manager.stop_interview()
        # 停止事件轉發任務
        event_queue.put_nowait(None)
        forward_task.cancel()
        if client_id in clients:
            del clients[client_id]
        print(f"🧹 Client {client_id} 清理完成")