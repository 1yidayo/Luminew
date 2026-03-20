# app/services/minimax_tts.py
import os
import json
import asyncio
import websockets
import sounddevice as sd
import numpy as np
import ssl
import queue
from dotenv import load_dotenv

load_dotenv()

class MinimaxTTSWS:
    """
    MiniMax TTS WebSocket / Voice Cloning
    支援即時串流播放 (Streaming Playback)
    """

    def __init__(
        self,
        api_key=None,
        ws_url="wss://api.minimax.io/ws/v1/t2a_v2",
        model="speech-02-turbo",
        default_voice_id=None,
    ):
        self.api_key = api_key or os.getenv("MINIMAX_API_KEY")
        self.ws_url = ws_url or os.getenv("MINIMAX_WS_URL") or "wss://api.minimax.io/ws/v1/t2a_v2"
        self.model = model
        # 預設音色 ID (例如 74 號是 Chinese (Mandarin)_IntellectualGirl)
        self.default_voice_id = default_voice_id or os.getenv("MINIMAX_DEFAULT_VOICE") or "Chinese (Mandarin)_Male_Announcer"

    async def stream_text(self, text: str, voice_id: str = None, on_chunk=None):
        """
        將文字透過 WebSocket 轉成語音，並透過 Queue 實現平滑的串流播放。
        """
        if on_chunk is None:
            on_chunk = lambda chunk: None

        voice_id = voice_id or self.default_voice_id
        headers = {"Authorization": f"Bearer {self.api_key}"}
        
        # SSL 設定
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        # 音訊設定
        sample_rate = 32000
        audio_q = queue.Queue()

        # 內部狀態初始化
        self._audio_buffer = np.array([], dtype=np.int16)
        self._playback_started = False
        self._task_finished_received = False
        self._prebuffer_min_chunks = 3 # 累積幾個 chunk 才開始播

        def audio_callback(outdata, frames, time_info, status):
            """整合所有資料塊，提供平滑無縫播放"""
            if status:
                pass
            
            try:
                # 1. 將 Queue 中所有新到資料加入 buffer
                while not audio_q.empty():
                    chunk_arr = audio_q.get_nowait()
                    self._audio_buffer = np.concatenate((self._audio_buffer, chunk_arr))
                
                # 2. 預緩衝邏輯：還沒開始播且緩衝不夠，就填零退出
                # 但如果是已經收到伺服器完成訊號，就直接開始播
                if not self._playback_started:
                    if self._task_finished_received or len(self._audio_buffer) >= frames * self._prebuffer_min_chunks:
                        self._playback_started = True
                    else:
                        outdata.fill(0)
                        return

                # 3. 根據需求量取出資料
                if len(self._audio_buffer) >= frames:
                    outdata[:, 0] = self._audio_buffer[:frames]
                    self._audio_buffer = self._audio_buffer[frames:]
                else:
                    # 資料見底，填入剩餘部分，其餘補零
                    remaining = len(self._audio_buffer)
                    if remaining > 0:
                        outdata[:remaining, 0] = self._audio_buffer
                        outdata[remaining:, 0] = 0
                        self._audio_buffer = np.array([], dtype=np.int16)
                    else:
                        outdata.fill(0)
            except Exception:
                outdata.fill(0)

        try:
            # 啟動非阻塞播放流
            with sd.OutputStream(samplerate=sample_rate, channels=1, dtype='int16', callback=audio_callback):
                async with websockets.connect(self.ws_url, additional_headers=headers, ssl=ssl_context) as ws:
                    # 1. 握手
                    msg = json.loads(await ws.recv())
                    if msg.get("event") != "connected_success":
                        print("❌ 連線失敗")
                        return

                    # 2. 任務啟動
                    await ws.send(json.dumps({
                        "event": "task_start",
                        "model": self.model,
                        "voice_setting": {"voice_id": voice_id, "speed": 1, "vol": 1, "pitch": 0},
                        "audio_setting": {
                            "sample_rate": sample_rate, 
                            "format": "pcm", 
                            "channel": 1,
                            "bitrate": 128000
                        }
                    }))
                    
                    msg = json.loads(await ws.recv())
                    if msg.get("event") != "task_started":
                        print("❌ 任務啟動失敗")
                        return

                    # 3. 發送文字
                    await ws.send(json.dumps({"event": "task_continue", "text": text}))
                    await ws.send(json.dumps({"event": "task_finish"}))

                    # 4. 接收數據並放入播放隊列
                    while True:
                        try:
                            msg_str = await ws.recv()
                            msg = json.loads(msg_str)
                        except websockets.exceptions.ConnectionClosed:
                            break
                        except Exception as e:
                            if "resume_reading" in str(e): break
                            raise e

                        # 處理音訊數據 (即使是 task_finished 封裝也可能帶有最後一段 data)
                        if "data" in msg and "audio" in msg["data"]:
                            audio_hex = msg["data"]["audio"]
                            if audio_hex:
                                chunk_bytes = bytes.fromhex(audio_hex)
                                on_chunk(chunk_bytes)
                                audio_q.put(np.frombuffer(chunk_bytes, dtype=np.int16))

                        if msg.get("event") == "task_finished":
                            self._task_finished_received = True
                            break
                        if msg.get("event") == "task_failed":
                            print(f"❌ 任務失敗: {msg}")
                            break
                    
                    # 5. 等待播放完畢
                    # 大幅度增加等候時間，避免長難句被截斷。
                    # 設定為 1 分鐘上限 (對於面試回答來說應該足夠)
                    max_wait_loops = 600 # 60 秒 (600 * 0.1s)
                    wait_count = 0
                    while (not audio_q.empty() or len(self._audio_buffer) > 0) and wait_count < max_wait_loops:
                        await asyncio.sleep(0.1)
                        wait_count += 1
                    
                    if wait_count >= max_wait_loops:
                        print("⚠️ [TTS 警告] 播放等待逾時，強制結束播放流。")
                    
                    await asyncio.sleep(0.3) # 給硬體一點緩衝

        except Exception as e:
            if "resume_reading" not in str(e):
                print(f"❌ TTS Error: {e}")
        finally:
            on_chunk(None)

if __name__ == "__main__":
    async def test():
        tts = MinimaxTTSWS()
        await tts.stream_text("你好，我們正在進行一個長一點的測試，確保這段話不會在結束前被無故截斷。")
    asyncio.run(test())
