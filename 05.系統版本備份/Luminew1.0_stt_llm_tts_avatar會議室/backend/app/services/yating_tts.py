# yating_tts.py（把 GPT 回覆文字送給 Yating TTS，取回音檔並用 sounddevice 播放）
import requests
import io
import base64
import numpy as np
import sounddevice as sd
from pydub import AudioSegment
from dotenv import load_dotenv
import os

# 讀取 .env
load_dotenv()

YATING_API_KEY = os.getenv("YATING_TTS_KEY")
YATING_TTS_URL = os.getenv("YATING_TTS_URL")


def play_audiosegment_sd(audio: AudioSegment):
    """
    使用 sounddevice 播放 AudioSegment
    """
    samples = np.array(audio.get_array_of_samples())

    # 如果是 stereo，要 reshape
    if audio.channels == 2:
        samples = samples.reshape((-1, 2))

    # 正規化到 [-1.0, 1.0]
    samples = samples.astype(np.float32)
    samples /= np.max(np.abs(samples)) + 1e-9

    sd.play(samples, audio.frame_rate)
    sd.wait()  # 阻塞直到播放完成


def synthesize_and_play(text: str):
    headers = {
        "key": YATING_API_KEY,
        "Content-Type": "application/json"
    }

    body = {
        "input": {
            "type": "text",
            "text": text
        },
        "voice": {
            "model": "zh_en_male_1",
            "speed": 0.8,
            "pitch": 1.3,
            "energy": 1.0
        },
        "audioConfig": {
            "encoding": "MP3",
            "sampleRate": "16K"
        }
    }

    r = requests.post(YATING_TTS_URL, json=body, headers=headers)
    r.raise_for_status()

    resp = r.json()
    audio_bytes = base64.b64decode(resp["audioContent"])

    # MP3 → AudioSegment
    audio = AudioSegment.from_file(io.BytesIO(audio_bytes), format="mp3")

    # 播放
    play_audiosegment_sd(audio)


# 測試
if __name__ == "__main__":
    synthesize_and_play("你好，我是你的模擬教授。請問你想先練習哪個主題？")
