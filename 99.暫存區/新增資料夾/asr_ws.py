# asr_ws.py（把麥克風音訊丟給 Yating，並把 final text 呼叫回處理函式）
import asyncio, websockets, json, sounddevice as sd, numpy as np, requests, threading
from queue import Queue

YATING_API_KEY = "6aa8c608b8541c2886a0e0222aa57ff2090b2b8e" 
ASR_TOKEN_URL = "https://asr.api.yating.tw/v1/token"
ASR_WS_URL = "wss://asr.api.yating.tw/ws/v1/"

SAMPLE_RATE = 16000
CHUNK_BYTES = 2000

# --- 全域狀態 ---
audio_queue = Queue()
stream = None               # 麥克風 stream
ws_connection = None        # WebSocket 連線
recording_enabled = False   # 是否正在錄音
on_final_text_handler = None


def get_one_time_token(pipeline="asr-zh-en-std"):
    headers = {"key": YATING_API_KEY, "Content-Type": "application/json"}
    body = {"pipeline": pipeline}
    r = requests.post(ASR_TOKEN_URL, json=body, headers=headers)
    r.raise_for_status()
    return r.json()["auth_token"]


# --- 開麥 ---
def start_recording():
    global recording_enabled
    recording_enabled = True
    print("🎤 開始錄音...")


# --- 關麥 ---
def stop_recording():
    global recording_enabled
    recording_enabled = False
    print("⏹ 已停止錄音，等待辨識結果...")


def audio_callback(indata, frames, time, status):
    """只有 recording_enabled 時才送音訊"""
    if not recording_enabled:
        return
    pcm16 = (indata * 32767).astype(np.int16).tobytes()
    audio_queue.put(pcm16)


async def asr_stream_loop(on_final_text):
    global ws_connection, stream, on_final_text_handler
    on_final_text_handler = on_final_text

    token = get_one_time_token()
    uri = f"{ASR_WS_URL}?token={token}"

    async with websockets.connect(uri) as ws:
        ws_connection = ws
        print("ASR WebSocket 已連線")

        # 啟動錄音器（但初始不錄音）
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype='float32',
            callback=audio_callback
        )
        stream.start()

        # Sender Task (背景送音訊)
        async def sender():
            while True:
                chunk = await asyncio.get_event_loop().run_in_executor(None, audio_queue.get)
                await ws.send(chunk)

        asyncio.create_task(sender())

        # Receiver：處理結果
        async for message in ws:
            try:
                data = json.loads(message)
            except:
                continue

            pipe = data.get("pipe", {})
            if pipe.get("asr_final") is True:
                final_text = pipe.get("asr_sentence", "")
                print("[ASR final]", final_text)

                # 開 thread 處理（避免封鎖）
                threading.Thread(
                    target=on_final_text_handler, 
                    args=(final_text,)
                ).start()


# 讓外部可以啟動整個 ASR WebSocket 背景跑
def start_asr_background(on_final_text):
    def run_asyncio():
        asyncio.run(asr_stream_loop(on_final_text))
    threading.Thread(target=run_asyncio, daemon=True).start()


# 測試
if __name__ == "__main__":
    def handle(text):
        print("收到 ASR：", text)

    start_asr_background(handle)

    import time
    while True:
        cmd = input("按 1 開麥, 2 關麥：")
        if cmd == "1":
            start_recording()
        elif cmd == "2":
            stop_recording()
