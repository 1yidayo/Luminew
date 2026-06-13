#暫時用不到 沒有在維護
from fastapi import APIRouter
from pydantic import BaseModel
from app.services.yating_tts import synthesize_and_play

router = APIRouter()

class TTSRequest(BaseModel):
    text: str

@router.post("/speak")
def speak(request: TTSRequest):
    # 播放語音（阻塞）
    synthesize_and_play(request.text)
    return {"status": "played"}
