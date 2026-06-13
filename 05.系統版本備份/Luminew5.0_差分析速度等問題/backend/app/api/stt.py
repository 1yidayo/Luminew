#暫時用不到 沒有在維護
from fastapi import APIRouter

router = APIRouter()

# 目前的錄音狀態
is_recording = False

# 前端可呼叫的開麥 API
@router.post("/start")
def api_start_recording():
    global is_recording
    start_recording()
    is_recording = True
    return {"status": "recording_started"}

# 前端可呼叫的關麥 API
@router.post("/stop")
def api_stop_recording():
    global is_recording
    stop_recording()
    is_recording = False
    return {"status": "recording_stopped"}

# 啟動 ASR WebSocket（暫時禁用 - 移到手動啟動）
# @router.on_event("startup")
# def startup_asr():
#     def handle_final(text):
#         print("[ASR final]", text)
#     start_asr_background(handle_final)
