# app/api/interview.py
import asyncio
import base64
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.services.minimax_tts import MinimaxTTSWS
from app.services.yating_stt import YatingSTT
from app.services.InterviewManager import InterviewManager
from app.services.professor_persona import get_professor_persona
from fastapi import APIRouter
from app.services.InterviewManager import InterviewManager

router = APIRouter()

manager = InterviewManager()

@router.post("/start")
def start_interview():
    manager.start()
    return {"status": "started"}
app = FastAPI(title="Luminew Interview API")

# 連接 WebSocket 的每個 client 都會有自己的 InterviewManager
clients = {}


@router.websocket("/ws/{client_id}")
async def interview_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    persona = get_professor_persona("warm_industry_professor")  # 可以由前端指定 persona
    stt = YatingSTT()
    tts = MinimaxTTSWS(api_key=None)
    manager = InterviewManager(professor_type=persona.name)
    manager.stt = stt
    manager.tts = tts
    clients[client_id] = manager
    manager.interview_running = True

    # callback：tts chunk 直接傳回前端
    async def on_tts_chunk(chunk: bytes):
        await websocket.send_bytes(chunk)

    manager.tts.on_audio_chunk = on_tts_chunk

    try:
        while True:
            data = await websocket.receive_bytes()
            if not manager.interview_running:
                break
            # 前端傳 audio chunk
            manager.feed_audio_chunk(data)
    except WebSocketDisconnect:
        manager.interview_running = False
        print(f"Client {client_id} disconnected")
    finally:
        if client_id in clients:
            del clients[client_id]