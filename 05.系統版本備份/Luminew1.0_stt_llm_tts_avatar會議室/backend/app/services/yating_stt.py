# yating_stt.py
# 封裝 Yating 語音轉文字 (STT) 成類別，方便後端統一管理
import asyncio
import websockets
import json
import sounddevice as sd
import numpy as np
import requests
import threading
from queue import Queue
from dotenv import load_dotenv
import os

# 讀取 .env
load_dotenv()

YATING_API_KEY = os.getenv("YATING_API_KEY")
ASR_TOKEN_URL = os.getenv("ASR_TOKEN_URL")
ASR_WS_URL = os.getenv("ASR_WS_URL")

SAMPLE_RATE = 16000
CHUNK_BYTES = 2000  # 每塊 2000 bytes (~1/16 秒)

class YatingSTT:
    def __init__(self, pipeline="asr-zh-en-std"):
        self.pipeline = pipeline
        self.audio_queue = Queue()
        self.stream = None
        self.ws_connection = None
        self.recording_enabled = False
        self.on_final_text_handler = None
        self.token = None

    # 取得一次性 token
    def get_one_time_token(self):
        headers = {"key": YATING_API_KEY, "Content-Type": "application/json"}
        body = {"pipeline": self.pipeline}
        r = requests.post(ASR_TOKEN_URL, json=body, headers=headers)
        r.raise_for_status()
        return r.json()["auth_token"]

    # 開始錄音
    def start_recording(self):
        self.recording_enabled = True
        print("🎤 開始錄音...")

    # 停止錄音
    def stop_recording(self):
        self.recording_enabled = False
        print("⏹ 已停止錄音，等待辨識結果...")

    # 音訊 callback
    def audio_callback(self, indata, frames, time, status):
        if not self.recording_enabled:
            return
        pcm16 = (indata * 32767).astype(np.int16).tobytes()
        self.audio_queue.put(pcm16)

    # WebSocket 流程
    async def asr_stream_loop(self, on_final_text):
        self.on_final_text_handler = on_final_text
        self.token = self.get_one_time_token()
        uri = f"{ASR_WS_URL}{self.token}"

        async with websockets.connect(uri) as ws:
            self.ws_connection = ws
            print("ASR WebSocket 已連線")

            self.stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=1,
                dtype='float32',
                callback=self.audio_callback
            )
            self.stream.start()

            async def sender():
                while True:
                    chunk = await asyncio.get_event_loop().run_in_executor(None, self.audio_queue.get)
                    await ws.send(chunk)

            asyncio.create_task(sender())

            async for message in ws:
                try:
                    data = json.loads(message)
                except:
                    continue
                pipe = data.get("pipe", {})
                if pipe.get("asr_final") is True:
                    final_text = pipe.get("asr_sentence", "")
                    print("[ASR final]", final_text)
                    threading.Thread(target=self.on_final_text_handler, args=(final_text,)).start()

    # 後台啟動 ASR
    def start_asr_background(self, on_final_text):
        def run_asyncio():
            asyncio.run(self.asr_stream_loop(on_final_text))
        threading.Thread(target=run_asyncio, daemon=True).start()


# --- 測試 ---
if __name__ == "__main__":
    def handle(text):
        print("收到 ASR：", text)

    stt = YatingSTT()
    stt.start_asr_background(handle)

    while True:
        cmd = input("按 1 開麥, 2 關麥：")
        if cmd == "1":
            stt.start_recording()
        elif cmd == "2":
            stt.stop_recording()