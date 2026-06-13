from dotenv import load_dotenv
import os

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
YATING_API_KEY = os.getenv("YATING_API_KEY")

ASR_WS_URL = "wss://asr.api.yating.tw/ws/v1/"
TTS_URL = "https://tts.api.yating.tw/v2/speeches/short"
OPENAI_URL = "https://api.openai.com/v1/responses"
