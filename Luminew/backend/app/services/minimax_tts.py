# app/services/minimax_tts.py
import os
import json
import asyncio
import websockets
import ssl
from dotenv import load_dotenv

load_dotenv()

class MinimaxTTSWS:
    """
    MiniMax TTS WebSocket / Voice Cloning
    被解耦的串流播放 (只提供 on_chunk 回呼，不再依賴本機喇叭)
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
        self.default_voice_id = default_voice_id or os.getenv("MINIMAX_DEFAULT_VOICE") or "Chinese (Mandarin)_Male_Announcer"

    async def stream_text(self, text: str, voice_id: str = None, speed: float = 1.0, on_chunk=None, mute: bool = False):
        """
        將文字透過 WebSocket 轉成語音，直接將二進位資料交給 on_chunk。
        等待遠端伺服器全部播放完畢才退出該函數。
        """
        if on_chunk is None:
            on_chunk = lambda chunk: None

        voice_id = voice_id or self.default_voice_id
        headers = {"Authorization": f"Bearer {self.api_key}"}
        
        # SSL 設定
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        try:
            async with websockets.connect(self.ws_url, additional_headers=headers, ssl=ssl_context) as ws:
                # 1. 握手
                msg = json.loads(await ws.recv())
                if msg.get("event") != "connected_success":
                    print("[ERROR] 連線失敗")
                    return

                # 2. 任務啟動
                sample_rate = 32000
                await ws.send(json.dumps({
                    "event": "task_start",
                    "model": self.model,
                    "voice_setting": {"voice_id": voice_id, "speed": speed, "vol": 1, "pitch": 0},
                    "audio_setting": {
                        "sample_rate": sample_rate, 
                        "format": "pcm", 
                        "channel": 1,
                        "bitrate": 128000
                    }
                }))
                
                msg = json.loads(await ws.recv())
                if msg.get("event") != "task_started":
                    print("[ERROR] 任務啟動失敗")
                    return

                # 3. 發送文字
                await ws.send(json.dumps({"event": "task_continue", "text": text}))
                await ws.send(json.dumps({"event": "task_finish"}))

                # 4. 接收數據
                while True:
                    try:
                        msg_str = await ws.recv()
                        msg = json.loads(msg_str)
                    except websockets.exceptions.ConnectionClosed:
                        break
                    except Exception as e:
                        if "resume_reading" in str(e): break
                        raise e

                    if "data" in msg and "audio" in msg["data"]:
                        audio_hex = msg["data"]["audio"]
                        if audio_hex:
                            chunk_bytes = bytes.fromhex(audio_hex)
                            if not mute:
                                on_chunk(chunk_bytes)

                    if msg.get("event") == "task_finished":
                        break
                    if msg.get("event") == "task_failed":
                        print(f"[ERROR] 任務失敗: {msg}")
                        break

        except Exception as e:
            if "resume_reading" not in str(e):
                print(f"[ERROR] TTS Error: {e}")
        finally:
            on_chunk(None)

    async def generate_audio_bytes(self, text: str, voice_id: str = None, speed: float = 1.0) -> bytes:
        """
        將文字轉為語音，但不進行串流播放，而是收集所有字節後一次回傳。
        這對於需要將音訊存成檔案傳給 D-ID 的場景非常有用。
        """
        all_bytes = bytearray()
        def collect_chunk(chunk):
            if chunk:
                all_bytes.extend(chunk)
        
        await self.stream_text(text, voice_id=voice_id, speed=speed, on_chunk=collect_chunk)
        return bytes(all_bytes)

if __name__ == "__main__":
    async def test():
        tts = MinimaxTTSWS()
        await tts.stream_text("你好，測試解耦的 WebSocket")
    asyncio.run(test())
