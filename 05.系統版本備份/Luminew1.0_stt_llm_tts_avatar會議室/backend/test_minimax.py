import asyncio 
import numpy as np
import sounddevice as sd
from app.services.minimax_tts import MinimaxTTSWS

async def main():
    tts = MinimaxTTSWS()

    print("🎵 正在播放語音...")
    def on_chunk(chunk):
        if not chunk:
            print("✅ TTS 播放完成")

    await tts.stream_text(
        "你好，這是語音串流播放測試。我們已經切換到了即時播放模式。如果你能聽到這段話，代表系統運作正常並且正在使用 74 號音色。祝你有個美好的一天！",
        voice_id="Chinese (Mandarin)_Male_Announcer",
        on_chunk=on_chunk
    )

if __name__ == "__main__":
    asyncio.run(main())
