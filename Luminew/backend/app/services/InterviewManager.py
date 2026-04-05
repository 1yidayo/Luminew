# app/services/InterviewManager.py
import asyncio
import io
import json
import struct
import time
import requests
import os
from app.services.yating_stt import YatingSTT
from app.services.openai_llm import ask_gpt4_1_nano
from app.services.minimax_tts import MinimaxTTSWS
from app.services.professor_persona import get_professor_persona
from app.services.question_loader import get_random_questions

class InterviewManager:
    """
    管理整場模擬面試流程（純 asyncio 非同步 WebSocket 解耦版）：
    1. 教授開場白 (TTS)
    2. 自動開啟麥克風 (等待前端 websocket 音訊)
    3. 學生發言完畢觸發 `process_speech_end`
    4. 教授回答 (TTS) -> 播放完後再次觸發前端開啟麥克風
    不再使用本地 Threading 或 sounddevice。
    """

    def __init__(self, professor_type="warm_industry_professor", department="im", use_did=False):
        self.professor_persona = get_professor_persona(professor_type)
        self.department = department
        self.use_did = use_did

        # 取得隨機題庫
        selected_questions = get_random_questions(department=self.department)
        self.questions = selected_questions
        self.current_question_index = 0

        # D-ID 設定 (從 .env 讀取，並處理 auth)
        self.did_api_key = os.getenv("D_ID_API_KEY")
        self.session = requests.Session()
        if self.did_api_key and ':' in self.did_api_key:
            u, p = self.did_api_key.split(':')
            self.session.auth = (u, p)
        elif self.did_api_key:
            self.session.headers.update({"Authorization": f"Basic {self.did_api_key}"})

        questions_text = "\n".join([f"{i+1}. {q}" for i, q in enumerate(selected_questions)])

        # 把題庫偷偷塞進系統提示詞
        self.system_prompt = self.professor_persona.prompt + f"\n\n【本次面試核心任務】\n請擔任主考官，自然地將以下題目融入對話中（不需要一次問完，也不要照稿念，可根據學生回答動態調整、追問）：\n{questions_text}"

        # 初始化服務
        self.stt = YatingSTT()
        self.tts = MinimaxTTSWS(default_voice_id=self.professor_persona.voice_id)

        # 對話歷史
        self.conversation_history = []
        self.pending_student_texts = []
        self.interview_running = False

        # D-ID 專用的狀態變數
        self.did_stream_id = None    # 用來記住 D-ID 的會議室代碼
        self.did_session_id = None   # 用來記住通話的 Session

        # WebSocket 事件回呼 (都是 async function)
        self.on_transcript = None      # async (role, text) → void
        self.on_audio_chunk = None     # async (bytes) → void
        self.on_tts_done = None        # async () → void

        try:
            self.main_loop = asyncio.get_running_loop()
        except RuntimeError:
            self.main_loop = None

    @staticmethod
    def _pcm_to_wav(pcm_data: bytes, sample_rate: int = 32000, channels: int = 1, sample_width: int = 2) -> bytes:
        data_size = len(pcm_data)
        wav_buf = io.BytesIO()
        wav_buf.write(b'RIFF')
        wav_buf.write(struct.pack('<I', 36 + data_size))
        wav_buf.write(b'WAVE')
        wav_buf.write(b'fmt ')
        wav_buf.write(struct.pack('<I', 16))
        wav_buf.write(struct.pack('<H', 1))
        wav_buf.write(struct.pack('<H', channels))
        wav_buf.write(struct.pack('<I', sample_rate))
        wav_buf.write(struct.pack('<I', sample_rate * channels * sample_width))
        wav_buf.write(struct.pack('<H', channels * sample_width))
        wav_buf.write(struct.pack('<H', sample_width * 8))
        wav_buf.write(b'data')
        wav_buf.write(struct.pack('<I', data_size))
        wav_buf.write(pcm_data)
        return wav_buf.getvalue()

    async def start_interview(self):
        """啟動面試（非同步版）"""
        self.interview_running = True
        print(f"🎓 面試啟動（教授: {self.professor_persona.name}）")

        self.stt.start_asr_background(self._on_student_text_sync)
        await self._play_opening_greeting()

    def _on_student_text_sync(self, text):
        """ASR 的文字回呼，因為跑在其它線程，我們需要用 asyncio 去呼叫 WS 回呼"""
        if not getattr(self, "interview_running", False):
            return
        print(f"🎤 [學生]: {text}")
        if not hasattr(self, "pending_student_texts"): return
        self.pending_student_texts.append(text)
        if hasattr(self, "on_transcript") and self.on_transcript and getattr(self, "main_loop", None):
            try:
                asyncio.run_coroutine_threadsafe(self.on_transcript("student", text), self.main_loop)
            except Exception as e:
                print(f"❌ _on_student_text_sync 錯誤: {e}")

    async def _play_opening_greeting(self):
        opening_instruct = (
            "\n\n現在面試剛開始，請你作為面試官，主動向學生打招呼並拋出第一題。\n"
            "【開場強制規定】\n"
            "1. 第一句話請固定說「同學好，歡迎來參加這次的二階面試」，絕對不要說「聊天」或「您好」。\n"
            "2. 拋出第一題時必須「非常簡短直接」，不要做過多的描述與解釋。\n"
            "3. 如果要加上結尾，最多只能說「方便我們更了解你」，不需要其他贅字。"
        )
        opening_prompt = self.system_prompt + opening_instruct

        print("🤔 教授正在準備開場白...")
        greeting = await asyncio.to_thread(ask_gpt4_1_nano, opening_prompt, self.professor_persona.name)
        print(f"👨‍🏫 [教授開場]: {greeting}")

        self.conversation_history.append({"role": "professor", "content": greeting})

        if self.on_transcript:
            await self.on_transcript("professor", greeting)

        await self._async_play_tts(greeting)

        print("🟢 [等待語音] 請前端發送學生音訊...")
        self.stt.start_recording()

    async def _async_play_tts(self, text):
        tts_text = text.replace("調整", "條整").replace("挑戰", "窕戰")
        print(f"🔊 [TTS 準備播放] 文字長度: {len(tts_text)}")

        if getattr(self, "use_did", False) and self.did_stream_id:
            await asyncio.to_thread(self.send_did_talk, text)
            await asyncio.sleep(max(3, len(text) * 0.3))
            if self.on_tts_done:
                await self.on_tts_done()
            return

        def on_chunk_sync(chunk_bytes):
            if chunk_bytes is not None and self.on_audio_chunk:
                wav_data = self._pcm_to_wav(bytes(chunk_bytes), sample_rate=32000)
                try:
                    loop = asyncio.get_running_loop()
                    loop.create_task(self.on_audio_chunk(wav_data))
                except RuntimeError:
                    pass

        try:
            await self.tts.stream_text(
                text=tts_text,
                voice_id=self.professor_persona.voice_id,
                speed=self.professor_persona.speed,
                on_chunk=on_chunk_sync,
            )
            print("🔊 [TTS 播放結束]")
            if self.on_tts_done:
                await self.on_tts_done()
        except Exception as e:
            print(f"❌ [TTS 播放錯誤]: {e}")

    async def process_speech_end(self):
        if not self.interview_running:
            return

        print("⏹ [學生演講結束] 正在處理學生回答並產出教授回應...")
        self.stt.stop_recording()

        await asyncio.sleep(1.0)

        if self.pending_student_texts:
            await self._process_and_reply()
            self.pending_student_texts = []
        else:
            print("⚠️ 未偵測到有效的學生發言。繼續收音")
            self.stt.start_recording()

    async def _process_and_reply(self):
        student_text = " ".join(self.pending_student_texts)
        self.conversation_history.append({"role": "student", "content": student_text})

        print("🤔 教授正在思考中...")
        prompt = self._build_llm_prompt()
        reply = await asyncio.to_thread(ask_gpt4_1_nano, prompt, self.professor_persona.name)

        print(f"👨‍🏫 [教授]: {reply}")
        self.conversation_history.append({"role": "professor", "content": reply})

        if self.on_transcript:
            await self.on_transcript("professor", reply)

        await self._async_play_tts(reply)

        print("🟢 [等待語音] 請前端串流繼續...")
        self.stt.start_recording()

    def _build_llm_prompt(self):
        prompt_text = self.system_prompt + "\n\n"
        for turn in self.conversation_history[-10:]:
            label = "學生" if turn["role"] == "student" else "教授"
            prompt_text += f"{label}說: {turn['content']}\n"
        prompt_text += "請以教授身份回答下一句。\n"
        return prompt_text

    def stop_interview(self):
        self.interview_running = False
        self.stt.stop_recording()
        print("⏹ 面試完全結束")

    # ─────────────────────────────
    # D-ID 相關方法
    # ─────────────────────────────

    def create_did_stream(self):
        print("正在向 D-ID 申請開啟視訊會議室...")
        if not self.did_api_key or ':' not in self.did_api_key:
            return {"error": "Invalid D_ID_API_KEY"}
        username, password = self.did_api_key.split(':')

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
            response = self.session.post(url, json=payload, headers=headers)

            if response.status_code == 201:
                data = response.json()
                print(f"📡 [DEBUG] D-ID Stream Creation Response: {json.dumps(data)}")
                print(f"📄 [DEBUG] D-ID Response Headers: {dict(response.headers)}")

                self.did_stream_id = data.get("id")
                self.did_session_id = data.get("session_id", "")

                # ★ 最終修復：使用 Cookie Jar 處理 AWSALB，避免手動更新 Header 造成衝突
                if "AWSALB" in self.did_session_id:
                    print("🍪 偵測到 Cookie 型 SessionID，正在同步到 Cookie Jar...")
                    for part in self.did_session_id.split(';'):
                        part = part.strip()
                        if '=' in part:
                            k, v = part.split('=', 1)
                            # 只存關鍵 Token
                            if k.upper() in ["AWSALB", "AWSALBCORS"]:
                                self.session.cookies.set(k, v, domain="api.d-id.com")

                print(f"✅ D-ID 會議室建立成功！StreamID: {self.did_stream_id}, SessionID: {self.did_session_id}")
                return data
            else:
                print(f"❌ D-ID 建立失敗 ({response.status_code}): {response.text}")
                return {"error": response.text}

        except Exception as e:
            return {"error": str(e)}

    def submit_did_sdp_answer(self, answer, session_id=None):
        """將前端產生的 WebRTC Answer 交回給 D-ID"""
        target_sid = session_id or self.did_session_id

        # ★ 嘗試：先稍微等待 D-ID 後台準備好，避免 500 Stream Error
        print("⏳ 等待 D-ID 後台準備 (3秒)...")
        time.sleep(3)

        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}/sdp"

        # 嚴格遵循 D-ID WebRTC 最新規範
        payload = {
            "answer": answer,
            "session_id": target_sid
        }

        headers = {"accept": "application/json", "content-type": "application/json"}
        response = self.session.post(url, json=payload, headers=headers)

        if not response.ok:
            print(f"❌ [D-ID] SDP Answer 提交失敗 ({response.status_code}): {response.text}")
            print(f"📡 [DEBUG] 提交的 Payload: {json.dumps(payload)[:200]}...")
        else:
            print(f"✅ [D-ID] SDP Answer 提交成功: {response.text}")
        return response.json() if response.ok else {"error": response.text}

    def submit_did_ice_candidate(self, candidate, sdpMid, sdpMLineIndex, session_id=None):
        """將前端產生的 ICE Candidate 交回給 D-ID"""
        target_sid = session_id or self.did_session_id
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}/ice"
        payload = {
            "candidate": candidate,
            "sdpMid": sdpMid,
            "sdpMLineIndex": sdpMLineIndex,
            "session_id": target_sid
        }

        headers = {"accept": "application/json", "content-type": "application/json"}
        # ★ 送出請求，self.session 會自動帶上我們剛剛設定的 AWSALB Cookies
        response = self.session.post(url, json=payload, headers=headers)
        if not response.ok:
            print(f"❌ [D-ID] ICE 提交失敗 ({response.status_code}): {response.text}")
        else:
            print(f"✅ [D-ID] ICE 提交成功")
        return response.json() if response.ok else {"error": response.text}

    def send_did_talk(self, text):
        print(f"😎 正在指揮 D-ID 教授說話...")
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}"
        payload = {
            "script": {
                "type": "text",
                "input": text,
                "provider": {
                    "type": "microsoft",
                    "voice_id": "zh-TW-YunJheNeural"  # 使用微軟中文男聲
                }
            },
            "session_id": self.did_session_id
        }
        headers = {"accept": "application/json", "content-type": "application/json"}
        response = self.session.post(url, json=payload, headers=headers)
        if not response.ok:
            print(f"❌ [D-ID 說話失敗]: {response.status_code} - {response.text}")
        else:
            print(f"✅ [D-ID 說話成功]")
        return response.json() if response.ok else {"error": response.text}

    def send_did_talk_audio(self, audio_url):
        """讓 D-ID 裡的虛擬教授開口說話 (使用自訂音檔 URL)"""
        print(f"😎 正在指揮 D-ID 教授播報 Minimax 聲音...")
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}"
        payload = {
            "script": {
                "type": "audio",
                "audio_url": audio_url,
            },
            "session_id": self.did_session_id
        }
        headers = {"accept": "application/json", "content-type": "application/json"}
        response = self.session.post(url, json=payload, headers=headers)
        return response.json() if response.ok else {"error": response.text}
