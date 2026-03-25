# app/services/InterviewManager.py
import asyncio
import io
import struct
import time
import requests
import os
from concurrent.futures import ThreadPoolExecutor
from app.services.yating_stt import YatingSTT
from app.services.openai_llm import ask_gpt4_1_nano
from app.services.minimax_tts import MinimaxTTSWS
from app.services.professor_persona import get_professor_persona
from app.services.question_loader import get_random_questions

class InterviewManager:
    """
    管理整場模擬面試流程（非同步多線程版本）：
    1. 教授開場白 (TTS) - 在獨立線程
    2. 自動開啟麥克風 (學生思考/回答)
    3. 學生手動關閉麥克風 -> LLM 生成教授回答（在獨立線程）
    4. 教授回答 (TTS) -> 播放完後自動開啟麥克風（在獨立線程）
    """

    def __init__(self, professor_type="warm_industry_professor", department="im"):
        self.professor_persona = get_professor_persona(professor_type)
        self.department = department
        
        # 取得隨機題庫
        selected_questions = get_random_questions(department=self.department)
        questions_text = "\n".join([f"{i+1}. {q}" for i, q in enumerate(selected_questions)])
        
        # 把題庫偷偷塞進系統提示詞
        self.system_prompt = self.professor_persona.prompt + f"\n\n【本次面試核心任務】\n請擔任主考官，自然地將以下題目融入對話中（不需要一次問完，也不要照稿念，可根據學生回答動態調整、追問）：\n{questions_text}"

        # 初始化服務
        self.stt = YatingSTT()
        self.tts = MinimaxTTSWS(
            default_voice_id=self.professor_persona.voice_id
        )

        # 對話歷史
        self.conversation_history = []
        # 收集學生語音轉文字後的暫存 (ASR 背景收集)
        self.pending_student_texts = []
        # 面試運作狀態
        self.interview_running = False
        
        # ★★★ 多線程執行器 ★★★
        self.executor = ThreadPoolExecutor(max_workers=2)
        self.loop = None

        #  --- 新增 D-ID 專用的設定 --- 
        self.did_api_key = os.getenv("D_ID_API_KEY", "")
        self.did_stream_id = None  # 用來記住 D-ID 的會議室代碼
        self.did_session_id = None # 用來記住通話的 Session
        #  ---------------------------- 

        # ★★★ 新增：WebSocket 事件回呼 ★★★
        # 由 interview.py 設定，讓 TTS 音訊和文字能傳回 Flutter
        self.on_transcript = None      # (role, text) → void
        self.on_audio_chunk = None     # (bytes) → void
        self.on_tts_done = None        # () → void

    # ======================== 工具方法 ========================

    @staticmethod
    def _pcm_to_wav(pcm_data: bytes, sample_rate: int = 32000, channels: int = 1, sample_width: int = 2) -> bytes:
        """將 PCM raw bytes 轉換為 WAV 格式 bytes"""
        data_size = len(pcm_data)
        wav_buf = io.BytesIO()
        # RIFF header
        wav_buf.write(b'RIFF')
        wav_buf.write(struct.pack('<I', 36 + data_size))
        wav_buf.write(b'WAVE')
        # fmt chunk
        wav_buf.write(b'fmt ')
        wav_buf.write(struct.pack('<I', 16))                    # chunk size
        wav_buf.write(struct.pack('<H', 1))                     # PCM format
        wav_buf.write(struct.pack('<H', channels))              # channels
        wav_buf.write(struct.pack('<I', sample_rate))            # sample rate
        wav_buf.write(struct.pack('<I', sample_rate * channels * sample_width))  # byte rate
        wav_buf.write(struct.pack('<H', channels * sample_width))               # block align
        wav_buf.write(struct.pack('<H', sample_width * 8))      # bits per sample
        # data chunk
        wav_buf.write(b'data')
        wav_buf.write(struct.pack('<I', data_size))
        wav_buf.write(pcm_data)
        return wav_buf.getvalue()

    # ======================== 同步版本（WebSocket 使用）========================
    def start_interview(self):
        """
        啟動面試：
        1. 準備 ASR 背景監聽
        2. 由教授進行開場白 (TTS)
        3. 開場白結束後自動啟動錄音
        """
        self.interview_running = True
        print(f"🎓 面試啟動（教授: {self.professor_persona.name}）")
        
        # 啟動 ASR 背景監聽 (但不一定馬上 start_recording，等 TTS 完)
        self.stt.start_asr_background(self._on_student_text)
        
        # 執行開場白
        self._play_opening_greeting()

    def _play_opening_greeting(self):
        """生成並播放面試開場白，播放完畢後自動開麥"""
        opening_prompt = self.system_prompt + "\n\n現在面試剛開始，請你作為面試官，主動向學生打招呼並開始這場面試。請簡短一些。"
        
        print("🤔 教授正在準備開場白...")
        greeting = ask_gpt4_1_nano(opening_prompt, professor_type=self.professor_persona.name)
        print(f"👨‍🏫 [教授開場]: {greeting}")
        
        self.conversation_history.append({"role": "professor", "content": greeting})

        # ★ 發送教授文字到 Flutter
        if self.on_transcript:
            self.on_transcript("professor", greeting)
        
        # 播放開場白 (阻塞，直到播完) → 同時收集音訊傳到 Flutter
        self._sync_play_tts(greeting)
        
        # 播放完畢，自動開啟麥克風
        print("🟢 [自動開麥] 請學生開始回答或思考...")
        self.stt.start_recording()

    def _sync_play_tts(self, text):
        """同步阻塞播放 TTS，同時收集音訊傳給 Flutter"""
        print(f"🔊 [TTS 開始播放] 文字長度: {len(text)}")
        
        # ★★★ 收集所有 PCM 音訊片段 ★★★
        collected_pcm = bytearray()

        def on_chunk(chunk_bytes):
            if chunk_bytes is not None:
                collected_pcm.extend(chunk_bytes)

        async def _play():
            await self.tts.stream_text(
                text=text,
                voice_id=self.professor_persona.voice_id,
                speed=self.professor_persona.speed,  # ★ 傳入教授專屬語速
                on_chunk=on_chunk  # ★ 傳入回呼收集音訊
            )
        try:
            asyncio.run(_play())
            print("🔊 [TTS 播放結束]")
            
            # ★★★ 將收集到的 PCM 轉為 WAV 並發送到 Flutter ★★★
            if collected_pcm and self.on_audio_chunk:
                wav_data = self._pcm_to_wav(bytes(collected_pcm), sample_rate=32000)
                self.on_audio_chunk(wav_data)
                print(f"📤 已發送 WAV 音訊到 Flutter ({len(wav_data)} bytes)")
            
            # ★ 通知 Flutter TTS 播放結束
            if self.on_tts_done:
                self.on_tts_done()

        except Exception as e:
            print(f"❌ [TTS 播放錯誤]: {e}")

    def _on_student_text(self, text):
        """ASR 辨識結果回呼"""
        if not self.interview_running:
            return
        print(f"🎤 [學生]: {text}")
        self.pending_student_texts.append(text)
        # ★ 發送學生文字到 Flutter
        if self.on_transcript:
            self.on_transcript("student", text)

    def process_speech_end(self):
        """
        當用戶按下「關閉麥克風」按鈕時觸發：
        1. 停止錄音
        2. 處理累積的 ASR 文本
        3. LLM 生成回答 -> TTS 播放
        4. 播放完畢後自動重新開麥
        """
        if not self.interview_running:
            print("⚠️ 面試尚未啟動，無法處理結束語音。")
            return

        print("⏹ [手動關麥] 正在處理學生回答並產出教授回應...")
        self.stt.stop_recording()
        
        # 稍微緩衝等待殘餘的 ASR 文本送達
        print("⏳ 等待 ASR 殘餘文本...")
        time.sleep(1.0)
        print(f"📊 目前收集到的文本段數: {len(self.pending_student_texts)}")

        if self.pending_student_texts:
            self._process_and_reply()
            self.pending_student_texts = []
        else:
            print("⚠️ 未偵測到有效的學生發言。")
            # 如果沒說話，可能還是要提示一下或維持錄音？
            # 這裡依據邏輯，沒說話關麥後我們還是自動重開錄音
            print("🟢 [自動重開錄音] 等待學生準備好...")
            self.stt.start_recording()

    def _process_and_reply(self):
        """核心邏輯：LLM 生成並播放，播放完自動開麥"""
        student_text = " ".join(self.pending_student_texts)
        self.conversation_history.append({"role": "student", "content": student_text})

        # LLM 生成回答
        print("🤔 教授正在思考中...")
        prompt = self._build_llm_prompt()
        reply = ask_gpt4_1_nano(prompt, professor_type=self.professor_persona.name)
        
        print(f"👨‍🏫 [教授]: {reply}")
        self.conversation_history.append({"role": "professor", "content": reply})

        # ★ 發送教授文字到 Flutter
        if self.on_transcript:
            self.on_transcript("professor", reply)

        # TTS 播放 (阻塞，播完才往下走) → 同時傳送音訊到 Flutter
        print("🎵 播放教授回答中...")
        self._sync_play_tts(reply)
        print("✅ 播放完畢。")

        # 重點：播放完畢自動開麥
        print("🟢 [自動重開錄音] 請學生繼續...")
        self.stt.start_recording()

    def _build_llm_prompt(self):
        """建立對話 Prompt"""
        prompt_text = self.system_prompt + "\n\n"
        for turn in self.conversation_history[-10:]:
            role = turn["role"]
            content = turn["content"]
            label = "學生" if role == "student" else "教授"
            prompt_text += f"{label}說: {content}\n"
        prompt_text += "請以教授身份回答下一句。\n"
        return prompt_text

    def stop_interview(self):
        self.interview_running = False
        self.stt.stop_recording()
        # 關閉線程池
        if self.executor:
            self.executor.shutdown(wait=False)
        print("⏹ 面試完全結束，線程池已關閉")

    def create_did_stream(self):
        """向 D-ID 申請開啟 WebRTC 視訊會議室"""
        print("正在向 D-ID 申請開啟視訊會議室...")
        username, password = self.did_api_key.split(':')
        
        # 讀取 .env 中的 D_ID_URL，如果沒有就用預設的
        url = os.getenv("D_ID_URL", "https://api.d-id.com/talks/streams")
        
        payload = {
            # 改用你們的教授照片
            "source_url": "https://raw.githubusercontent.com/1yidayo/Luminew/refs/heads/main/Luminew/backend/assets/images/Paul.jpg" 
        }
        
        headers = {
            "accept": "application/json",
            "content-type": "application/json"
        }

        try:
            response = requests.post(
                url, 
                json=payload, 
                headers=headers, 
                auth=(username, password)
            )
            
            if response.status_code == 201:
                data = response.json()
                # 把拿到的房間號碼記在經理的腦袋裡，以後要講話才知道去哪間房
                self.did_stream_id = data.get("id")
                self.did_session_id = data.get("session_id")
                
                print(f"🎉 D-ID 會議室建立成功！房間代碼: {self.did_stream_id}")
                return data # 將整包包含 offer SDP 的資料回傳，準備交給 Flutter
            else:
                print(f"❌ D-ID 建立失敗：{response.text}")
                return {"error": "Failed to create stream"}
                
        except Exception as e:
            print(f"程式發生錯誤：{e}")
            return {"error": str(e)}
