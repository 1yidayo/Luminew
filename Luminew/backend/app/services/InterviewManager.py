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
from app.services.question_loader import get_random_questions, get_questions

class InterviewManager:
    """
    管理整場模擬面試流程（純 asyncio 非同步 WebSocket 解耦版）：
    1. 教授開場白 (TTS)
    2. 自動開啟麥克風 (等待前端 websocket 音訊)
    3. 學生發言完畢觸發 `process_speech_end`
    4. 教授回答 (TTS) -> 播放完後再次觸發前端開啟麥克風
    不再使用本地 Threading 或 sounddevice。
    """

    # ── 自我介紹說法隨機清單（通用型第一題，不帶時間限制）──
    _SELF_INTRO_PROMPTS = [
        "同學請坐，可以先跟我們簡單介紹一下你自己嗎？",
        "同學請坐，那我們直接開始吧，請你先自我介紹一下。",
        "同學請坐，請先介紹你自己。",
        "同學請坐，請你先做個簡單的自我介紹。",
        "同學請坐，我們從自我介紹開始吧。",
    ]

    # ── 結語隨機清單 ──
    _CLOSING_REMARKS = [
        "好的，謝謝你今天的分享，我們這次面試就先到這裡。",
        "了解，今天的面試結束了，辛苦了。",
        "好，我們今天的面試到此結束，謝謝你的參與。",
        "謝謝你今天的回答，面試到這裡告一段落。",
    ]

    def __init__(self, professor_type="warm_industry_professor", department="im", use_did=False, custom_questions=None):
        self.professor_persona = get_professor_persona(professor_type)
        self.department = department
        self.use_did = use_did
        self.mode = "did" if use_did else "minimax"

        import random

        # ─────────────────────────────────────────────────────────
        # 題目分配邏輯（2 題制）
        # ─────────────────────────────────────────────────────────
        if self.department == "通用型":
            # 第一題：固定自介，隨機說法，不帶時間限制
            first_q = random.choice(self._SELF_INTRO_PROMPTS)

            # 第二題：PDF 優先，否則從 general.json（排除自介類問題）
            if custom_questions and len(custom_questions) > 0:
                second_q = random.choice(custom_questions)
            else:
                pool = get_questions("通用型", count=1, exclude_self_intro=True)
                second_q = pool[0] if pool else "在你的求學過程中，有沒有遇過什麼重大的挫折？你是如何解決的？"

        elif self.department == "資管專業":
            # 兩題都從資管題庫或 PDF，不固定自介
            if custom_questions and len(custom_questions) > 0:
                pool = custom_questions
                if len(pool) >= 2:
                    selected = random.sample(pool, 2)
                else:
                    # PDF 不足 2 題，補充題庫
                    extra = get_questions("資管專業", count=2 - len(pool))
                    selected = pool + extra
                first_q, second_q = selected[0], selected[1]
            else:
                selected = get_questions("資管專業", count=2)
                if len(selected) >= 2:
                    first_q, second_q = selected[0], selected[1]
                else:
                    first_q = selected[0] if selected else "你覺得「資訊管理」跟「資訊工程」最大的差別在哪裡？"
                    second_q = "請談談你對 AI 人工智慧改變未來職場的看法。"

        else:  # 學習歷程
            # 全部從 PDF，PDF 失敗則使用備用題庫
            if custom_questions and len(custom_questions) > 0:
                pool = custom_questions
                if len(pool) >= 2:
                    selected = random.sample(pool, 2)
                else:
                    from app.services.question_generator import DEFAULT_BANKS
                    fallback = DEFAULT_BANKS.get("學習歷程", [])
                    selected = pool + fallback[:max(0, 2 - len(pool))]
                first_q, second_q = selected[0], selected[1]
            else:
                # PDF 必填但解析失敗時的最後備用
                from app.services.question_generator import DEFAULT_BANKS
                fallback = DEFAULT_BANKS.get("學習歷程", [])
                first_q = fallback[0] if len(fallback) > 0 else "這份學習歷程中，哪一個部分是你投入心力最多、感到最自豪的？"
                second_q = fallback[1] if len(fallback) > 1 else "在準備學習歷程檔案的過程中，你對自己的專業興趣有新的發現嗎？"

        self.questions = [first_q, second_q]
        self.current_question_index = 0  # 追蹤目前是第幾題
        self.total_questions = 2

        print(f"[INIT] 面試類型: {self.department} | 題目: {self.questions}")

        # D-ID 設定 (從 .env 讀取，並處理 auth)
        self.did_api_key = os.getenv("D_ID_API_KEY")
        self.session = requests.Session()
        if self.did_api_key and ':' in self.did_api_key:
            u, p = self.did_api_key.split(':')
            self.session.auth = (u, p)
        elif self.did_api_key:
            self.session.headers.update({"Authorization": f"Basic {self.did_api_key}"})

        questions_text = "\n".join([f"{i+1}. {q}" for i, q in enumerate(self.questions)])

        # 把題庫偷偷塞進系統提示詞
        self.system_prompt = self.professor_persona.prompt + f"\n\n【本次面試核心任務】\n請擔任主考官，自然地將以下題目融入對話中（總共 2 題，請嚴格按照題號順序進行）：\n{questions_text}\n目前進行到第 {self.current_question_index + 1} 題。"

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
        self.on_send_audio = None
        self.on_did_ice = None
        
        # ★ 用於追蹤 D-ID 說話狀態
        self._did_talk_event = asyncio.Event()
        self._is_professor_speaking = False

        # WebSocket 事件回呼 (都是 async function)
        self.on_transcript = None      # async (role, text) → void
        self.on_audio_chunk = None     # async (bytes) → void
        self.on_tts_done = None        # async () → void
        self.on_tts_start = None       # async () → void
        self.on_interview_end = None   # async () → void (面試完全結束，通知前端分析)

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
        print(f"[ACAD] 面試啟動（教授: {self.professor_persona.name}）")

        self.stt.start_asr_background(self._on_student_text_sync)
        await self._play_opening_greeting()

    def _on_student_text_sync(self, text):
        """ASR 的文字回呼，因為跑在其它線程，我們需要用 asyncio 去呼叫 WS 回呼"""
        if not getattr(self, "interview_running", False):
            return
        print(f"[MIC] [學生]: {text}")
        if not hasattr(self, "pending_student_texts"): return
        self.pending_student_texts.append(text)
        if hasattr(self, "on_transcript") and self.on_transcript and getattr(self, "main_loop", None):
            try:
                asyncio.run_coroutine_threadsafe(self.on_transcript("student", text), self.main_loop)
            except Exception as e:
                print(f"[ERROR] _on_student_text_sync 錯誤: {e}")

    async def _play_opening_greeting(self):
        """教授開場並提出第一題"""
        first_q = self.questions[0]

        if self.department == "通用型":
            # 通用型第一題是自介，引導自然開場，不提時間
            opening_instruct = (
                f"\n\n現在面試剛開始，請你作為面試官（{self.professor_persona.name}），主動向學生打招呼。\n"
                "【開場強制任務】\n"
                "1. 請務必先請學生「坐下」（例如：同學請坐、請坐下吧）。\n"
                f"2. 開場後，自然邀請學生自我介紹（核心問題：「{first_q}」），不要提時間限制。\n"
                "3. 語氣要完全符合你的教授人格，保持簡短直接。\n"
                "4. 注意：本次面試只有 2 題，請保持簡潔有力。"
            )
        else:
            # 資管專業 / 學習歷程：開場後自然拋出第一題
            opening_instruct = (
                f"\n\n現在面試剛開始，請你作為面試官（{self.professor_persona.name}），主動向學生打招呼。\n"
                "【開場強制任務】\n"
                "1. 請務必先請學生「坐下」（例如：同學請坐、請坐下吧）。\n"
                f"2. 開場後，自然地提出第一個問題：「{first_q}」\n"
                "3. 語氣要完全符合你的教授人格，保持簡短直接。\n"
                "4. 注意：本次面試只有 2 題，請保持簡潔有力。"
            )
        
        opening_prompt = self.system_prompt + opening_instruct

        print(f"[THINK] 教授 ({self.professor_persona.name}) 正在準備開場白...")
        greeting = await asyncio.to_thread(ask_gpt4_1_nano, opening_prompt, self.professor_persona.name)
        
        print(f"[PROF] [教授開場]: {greeting}")

        self.conversation_history.append({"role": "professor", "content": greeting})

        if self.on_transcript:
            await self.on_transcript("professor", greeting)

        # 正常播放 TTS (透過 D-ID 串流)
        await self._async_play_tts(greeting)
        
        self.current_question_index = 0 # 標記目前是第一題

    async def handle_did_talk_completed(self):
        """由 Webhook 觸發：通知 D-ID 說話已完成"""
        self._did_talk_event.set()
        self._is_professor_speaking = False

    async def _async_play_tts(self, tts_text, tts_audio=None):
        # ★ 新增：如果是第一次播放，稍微多等一下
        if not getattr(self, "_first_tts_done", False):
            print("[WAIT] [D-ID] 第一次播放，額外等待 2 秒確保連線穩定...")
            await asyncio.sleep(2.0)
            self._first_tts_done = True

        tts_text = tts_text.replace("調整", "條整").replace("挑戰", "窕戰").replace("專長", "專常").replace("挫折", "錯折")
        print(f"[AUDIO] [TTS 準備播放] 文字長度: {len(tts_text)}")

        if getattr(self, "use_did", False) and self.did_stream_id:
            # 1. 將 Minimax 生成的音訊存成檔案
            print(f"[AUDIO] [D-ID] 正在生成高品質 Minimax 音訊檔案...")
            pcm_bytes = await self.tts.generate_audio_bytes(tts_text, voice_id=self.professor_persona.voice_id)
            if pcm_bytes:
                wav_data = self._pcm_to_wav(pcm_bytes, sample_rate=32000)
                
                # ★★★ 終極修復：不論是否為 D-ID 模式，都向前端推送一份原始音訊 ★★★
                if self.on_audio_chunk:
                    try:
                        await self.on_audio_chunk(wav_data)
                    except Exception as e:
                        print(f"[WARN] WebSocket send error: {e}")

                filename = f"speak_{int(time.time()*1000)}.wav"
                filepath = os.path.join("app", "public", "audio", filename)
                os.makedirs(os.path.dirname(filepath), exist_ok=True)
                with open(filepath, "wb") as f:
                    f.write(wav_data)
                
                # 2. 將音訊上傳至免費雲端 (Catbox 或 pomf.lain.la)
                audio_url = None
                try:
                    # 優先嘗試 Catbox
                    upload_res = await asyncio.to_thread(
                        requests.post, 
                        'https://catbox.moe/user/api.php', 
                        data={'reqtype': 'fileupload'}, 
                        files={'fileToUpload': ('speak.wav', wav_data, 'audio/wav')},
                        timeout=10
                    )
                    temp_url = upload_res.text.strip()
                    if temp_url.startswith('http'):
                        audio_url = temp_url
                    else:
                        raise ValueError(f"Catbox 回傳無效: {temp_url}")
                except Exception as e:
                    print(f"[WARN] Catbox 失敗 ({e})，嘗試使用備用雲端 pomf.lain.la...")
                    try:
                        upload_res = await asyncio.to_thread(
                            requests.post, 
                            'https://pomf.lain.la/user/api.php', 
                            data={'reqtype': 'fileupload'}, 
                            files={'files[]': ('speak.wav', wav_data, 'audio/wav')},
                            timeout=10
                        )
                        res_json = upload_res.json()
                        audio_url = res_json['files'][0]['url']
                    except Exception as e2:
                        print(f"[WARN] 所有音訊上傳空間皆失敗: {e2}")
                        
                try:
                    if not audio_url or not audio_url.startswith('http'):
                        raise ValueError("無法取得有效的音檔網址")
                        
                    print(f"[LINK] [D-ID] 上傳成功，安全音訊 URL: {audio_url}")
                    if self.on_tts_start:
                        await self.on_tts_start()
                    # 指揮 D-ID 播放高品質音訊
                    await asyncio.to_thread(self.send_did_talk_audio, audio_url)
                except Exception as e:
                    print(f"[ERROR] [D-ID] 高高品質音訊播報失敗 ({e})，啟動終極防禦：降級為純文字發音")
                    await asyncio.to_thread(self.send_did_talk, tts_text)
            
                # [D-ID 串流模式] 狀態管理
                self._did_talk_event.clear()
                self._is_professor_speaking = True
                pass
                
                self._is_professor_speaking = False
                
                # --- [測試] 拔除所有預熱延遲，直接啟動並亮燈 ---
                self.stt.start_recording()

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
            print("[AUDIO] [TTS 播放結束]")
            
            # --- [測試] 拔除所有預熱延遲 ---
            self.stt.start_recording()

            if self.on_tts_done:
                await self.on_tts_done()
        except Exception as e:
            print(f"[ERROR] [TTS 播放錯誤]: {e}")

    async def process_speech_end(self):
        if not self.interview_running:
            return

        print("[STOP] [學生演講結束] 正在處理學生回答並產出教授回應...")
        self.stt.stop_recording()

        await asyncio.sleep(1.0)

        student_text = " ".join(self.pending_student_texts).strip()

        # [加固檢查] 如果辨識內容太短或為空，視為沒聽清楚，觸發 fallback
        if len(student_text) < 2:
            print("[WARN] 偵測到無效或過短的回答，觸發重啟錄音流程...")
            fallback_msg = "不好意思，我剛剛沒聽清楚，能請你再說一次嗎？"
            
            if self.on_transcript:
                await self.on_transcript("professor", fallback_msg)
            
            await self._async_play_tts(fallback_msg)
            self.pending_student_texts = []
        else:
            await self._process_and_reply()
            self.pending_student_texts = []

    async def _process_and_reply(self):
        student_text = " ".join(self.pending_student_texts)
        self.conversation_history.append({"role": "student", "content": student_text})

        # --- [更新] 題號進度管理 ---
        self.current_question_index += 1
        
        if self.current_question_index >= self.total_questions:
            # 面試結束（2題完畢，隨機結語）
            import random
            reply = random.choice(self._CLOSING_REMARKS)
            print(f"[PROF] [面試結束]: {reply}")
            self.conversation_history.append({"role": "professor", "content": reply})
            if self.on_transcript:
                await self.on_transcript("professor", reply)
            await self._async_play_tts(reply)
            
            # --- 通知前端面試結束 ---
            if self.on_interview_end:
                await self.on_interview_end()
                
            self.stop_interview()
            return

        print(f"[THINK] 教授正在思考第 {self.current_question_index + 1} 題...")
        prompt = self._build_llm_prompt()
        reply = await asyncio.to_thread(ask_gpt4_1_nano, prompt, self.professor_persona.name)

        print(f"[PROF] [教授]: {reply}")
        self.conversation_history.append({"role": "professor", "content": reply})

        if self.on_transcript:
            await self.on_transcript("professor", reply)

        await self._async_play_tts(reply)

        print("[READY] [等待語音] 請前端串流繼續...")
        self.stt.start_recording()

    def _build_llm_prompt(self):
        # 更新系統提示詞中的進度（2題流程）
        questions_text = "\n".join([f"{i+1}. {q}" for i, q in enumerate(self.questions)])
        current_system_prompt = self.professor_persona.prompt + f"\n\n【本次面試核心任務】\n請擔任主考官，自然地將以下題目融入對話中（總共 2 題，請嚴格按照題號順序進行）：\n{questions_text}\n目前進行到第 {self.current_question_index + 1} 題。"

        prompt_text = current_system_prompt + "\n\n"
        for turn in self.conversation_history[-10:]:
            label = "學生" if turn["role"] == "student" else "教授"
            prompt_text += f"{label}說: {turn['content']}\n"

        target_q = self.questions[self.current_question_index]

        if self.current_question_index == 1:
            # 第二題（最後一題）：允許根據第一答的完整性進行追問或提出預設問題
            prompt_text += (
                f"\n【重要指示】這是第 2 題（最後一個問題）。請你評估學生對第一題的回答：\n"
                f"1. 如果學生的回答不夠完整、有邏輯破綻，或是有值得進一步深挖的話題，請你【針對第一題進行引導式追問】。\n"
                f"2. 如果學生的回答已經很完整，或者你認為沒有特別需要追問的地方，請直接問出以下預設的第二個問題：『{target_q}』。\n"
                f"請注意：無論選擇追問或提出預設問題，你都只能問「一個」問題，不要追問多個。請給予極簡的承接（如：了解、好的、謝謝）後自然且簡短地問出。字數請嚴格控制在你的限制以內。\n"
            )
        else:
            prompt_text += f"\n【重要指示】這是第 {self.current_question_index + 1} 題，請直接提出以下問題：『{target_q}』。\n"
            prompt_text += "請給予極簡的承接（如：了解、謝謝、好的）後，自然地帶出這個問題。\n"
            prompt_text += "不要追問、不要延伸，直接以教授身份問出這題即可。\n"

        return prompt_text

    def stop_interview(self):
        self.interview_running = False
        self.stt.stop_recording()
        print("[STOP] 面試完全結束")

    # ─────────────────────────────
    # D-ID 相關方法
    # ─────────────────────────────
    def _is_url_reachable(self, url):
        """檢查外部 URL 是否可被下載 (增加超時容忍度至 10.0s)"""
        try:
            res = requests.head(url, timeout=10.0)
            if res.status_code == 200:
                return True
            else:
                print(f"[SIGNAL] [偵測] 網址連通但狀態碼非 200: {res.status_code}")
                return False
        except Exception as e:
            print(f"[SIGNAL] [偵測] 網址檢測失敗: {e}")
            return False

    def _update_did_cookies(self, sid):
        """同步 D-ID 的 AWSALB Cookie，維持 Session 持續性 (改由 requests.Session 自動管理)"""
        if not sid: return
        print(f" [SYMBOL]  [DEBUG] 目前 D-ID 紀錄的 Session ID: {sid}, Cookies: {self.session.cookies.get_dict()}")

    def create_did_stream(self):
        print("正在向 D-ID 申請開啟視訊會議室...")
        if not self.did_api_key or ':' not in self.did_api_key:
            return {"error": "Invalid D_ID_API_KEY"}
        username, password = self.did_api_key.split(':')

        url = os.getenv("D_ID_URL", "https://api.d-id.com/talks/streams")

        if not getattr(self, "public_url", None):
            env_url = os.getenv("PUBLIC_URL")
            if env_url:
                self.public_url = env_url.rstrip("/")
                print(f"[SIGNAL] [DEBUG] 使用環境變數 PUBLIC_URL: {self.public_url}")
            # --- 註解 Ngrok 備用邏輯 ---
            # else:
            #     try:
            #         import requests
            #         ngrok_res = requests.get("http://127.0.0.1:4040/api/tunnels", timeout=1)
            #         if ngrok_res.ok:
            #             tunnels = ngrok_res.json().get("tunnels", [])
            #             for t in tunnels:
            #                 if t.get("proto") == "https":
            #                     self.public_url = t.get("public_url")
            #                     print(f"[SIGNAL] [DEBUG] 自動偵測到 ngrok 網址: {self.public_url}")
            #                     break
            #     except Exception:
            #         pass

        img_url = self.professor_persona.image_url
        if img_url.startswith("http"):
            source_url = img_url
        else:
            public_url = getattr(self, "public_url", None)
            if public_url:
                source_url = f"{public_url.rstrip('/')}/assets/images/{img_url}"
            else:
                source_url = f"http://140.136.155.145:8000/assets/images/{img_url}"

        payload = {
            "source_url": source_url,
            "config": {
                "stitch": True
            }
        }

        public_url = getattr(self, "public_url", None)
        if public_url:
            payload["webhook"] = f"{public_url}/api/interview/did-webhook"
            print(f"[LINK] [D-ID] 已設定 Webhook 回傳地址 (請確認 ngrok 正常): {payload['webhook']}")
        else:
            print("[WARN] [D-ID] 警告：找不到 public_url，D-ID 將無法回傳路徑 (ICE)，連線可能卡住")

        headers = {
            "accept": "application/json",
            "content-type": "application/json"
        }
        try:
            response = self.session.post(url, json=payload, headers=headers)

            if response.status_code == 201:
                data = response.json()
                self.did_stream_id = data.get("id")
                self.did_session_id = data.get("session_id", "")
                self._update_did_cookies(self.did_session_id)
                print(f"[OK] [D-ID] 串流已建立: {self.did_stream_id}")
                return data
            else:
                print(f"[ERROR] D-ID 建立失敗 ({response.status_code}): {response.text}")
                return {"error": response.text}

        except Exception as e:
            return {"error": str(e)}

    async def submit_did_sdp_answer(self, answer, session_id=None):
        """將前端產生的 WebRTC Answer 交回給 D-ID"""
        target_sid = session_id or self.did_session_id
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}/sdp"
        payload = {"answer": answer}
        if target_sid:
            payload["session_id"] = target_sid

        headers = {"accept": "application/json", "content-type": "application/json"}
        response = await asyncio.to_thread(self.session.post, url, json=payload, headers=headers)

        if not response.ok:
            print(f"[ERROR] [D-ID] SDP Answer 提交失敗 ({response.status_code}): {response.text}")
        else:
            print(f"[OK] [D-ID] SDP Answer 提交成功! 回應: {response.text}")
            res_data = response.json()
            if res_data.get("session_id"):
                self.did_session_id = res_data["session_id"]
                self._update_did_cookies(res_data["session_id"])
        return response.json() if response.ok else {"error": response.text}

    async def submit_did_ice(self, candidate_data):
        """Websocket 專用的 ICE 轉發介面"""
        return await self.submit_did_ice_candidate(
            candidate=candidate_data.get("candidate"),
            sdpMid=candidate_data.get("sdpMid"),
            sdpMLineIndex=candidate_data.get("sdpMLineIndex"),
            session_id=candidate_data.get("session_id")
        )

    async def submit_did_ice_candidate(self, candidate, sdpMid, sdpMLineIndex, session_id=None):
        """將前端產生的 ICE Candidate 交回給 D-ID"""
        target_sid = session_id or self.did_session_id
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}/ice"
        payload = {
            "candidate": candidate,
            "sdpMid": sdpMid,
            "sdpMLineIndex": sdpMLineIndex
        }
        if target_sid:
            payload["session_id"] = target_sid

        headers = {"accept": "application/json", "content-type": "application/json"}
        response = await asyncio.to_thread(self.session.post, url, json=payload, headers=headers)
        if not response.ok:
            print(f"[ERROR] [D-ID] ICE 提交失敗 ({response.status_code}): {response.text}")
        else:
            print(f"[OK] [D-ID] ICE 提交成功! 回應: {response.text}")
            res_data = response.json()
            if res_data.get("session_id"):
                self.did_session_id = res_data["session_id"]
                self._update_did_cookies(res_data["session_id"])
        return response.json() if response.ok else {"error": response.text}

    def send_did_talk(self, text):
        print(f" [SYMBOL]  正在指揮 D-ID 教授說話...")
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}"
        payload = {
            "script": {
                "type": "text",
                "input": text,
                "provider": {
                    "type": "microsoft",
                    "voice_id": "zh-TW-YunJheNeural"
                }
            }
        }
        if self.did_session_id:
            payload["session_id"] = self.did_session_id
        headers = {"accept": "application/json", "content-type": "application/json"}
        response = self.session.post(url, json=payload, headers=headers)
        if not response.ok:
            print(f"[ERROR] [D-ID 說話失敗]: {response.status_code} - {response.text}")
        else:
            print(f"[OK] [D-ID 說話成功]")
        return response.json() if response.ok else {"error": response.text}

    def send_did_talk_audio(self, audio_url):
        """讓 D-ID 裡的虛擬教授開口說話 (使用自訂音檔 URL)"""
        print(f" [SYMBOL]  正在指揮 D-ID 教授播報 Minimax 聲音...")
        url = f"https://api.d-id.com/talks/streams/{self.did_stream_id}"
        payload = {
            "script": {
                "type": "audio",
                "audio_url": audio_url,
            }
        }
        if self.did_session_id:
            payload["session_id"] = self.did_session_id
        headers = {"accept": "application/json", "content-type": "application/json"}
        response = self.session.post(url, json=payload, headers=headers)
        if response.ok:
            print(f"[OK] [D-ID 音訊說話成功] 狀態碼: {response.status_code}")
        else:
            print(f"[ERROR] [D-ID 音訊說話失敗] 狀態碼: {response.status_code}, 回應: {response.text}")
        return response.json() if response.ok else {"error": response.text}

    async def handle_did_talk_completed(self):
        """當 D-ID Webhook 通知說話完畢時觸發"""
        print(f"[VIDEO] [D-ID] 收到 talk/completed，解鎖等待事件")
        self._did_talk_event.set()
