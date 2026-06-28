# main_controller.py
import time
import threading
import keyboard

from asr_ws import start_asr_background, start_recording, stop_recording
from call_openai import ask_gpt4_1_nano
from yating_tts import synthesize_and_play

# 狀態與 buffer
is_recording = False
asr_buffer = ""
last_final = ""
ignore_until = 0.0


# --- 工具函式 ---
def set_ignore(sec):
    """在開麥後短暫忽略 ASR 結果（避免回音）"""
    global ignore_until
    ignore_until = time.time() + sec


# --- 接收 ASR final（只累積，不送出） ---
def handle_asr_text(text):
    global asr_buffer, is_recording, last_final, ignore_until

    if not is_recording:
        return

    # 避免剛開麥時收到回聲
    now = time.time()
    if now < ignore_until:
        return

    text = (text or "").strip()
    if not text:
        return

    # 避免 yating ASR 重複同一句
    if text == last_final:
        return

    print(f"[ASR] {text}")
    asr_buffer += text + " "
    last_final = text
  

# --- 關麥後：送 GPT + TTS + 自動開麥 ---
def process_student_speech():
    global asr_buffer, last_final, is_recording

    if not asr_buffer.strip():
        print("[主控] 無有效內容，不送出")
        return

    print(f"[主控] 本段輸入：{asr_buffer.strip()}")

    reply = ask_gpt4_1_nano(
        asr_buffer,
        system_instructions="你是一位台灣大學教授，回答要簡短、清楚、口語。"
    )

    print(f"[主控] GPT 回覆：{reply}")

    # 教授說話
    synthesize_and_play(reply)

    # 清空 buffer
    asr_buffer = ""
    last_final = ""

    # ============================
    #   ✨ 教授講完 → 自動開麥流程
    # ============================
    print("🎤 教授講完 → 準備自動開麥…")

    # 讓 ASR 緩衝區重置：安全 0.8 秒
    time.sleep(0.8)

    # 避免 TTS 尾音被收進來
    set_ignore(0.5)

    # 開麥
    start_recording()
    is_recording = True

    # 再延遲 0.5 秒，避免剛開麥漏收前幾個字
    time.sleep(0.5)

    print("🎤 麥克風已開啟，你可以開始說話")
    # ============================


# --- 主程式 ---
if __name__ == "__main__":
    print("=== 即時教授練習系統啟動 ===")
    print("按空白鍵：在『開麥↔關麥並送出』之間切換")
    print("ASR 啟動中…")

    # 啟動 ASR
    start_asr_background(handle_asr_text)
    print("ASR 已啟動！準備開始使用\n")

    # --- 空白鍵事件 ---
    while True:
        keyboard.wait("space")

        if not is_recording:
            # 開麥
            print("🎤 按下空白 → 開麥")
            asr_buffer = ""
            last_final = ""
            set_ignore(0.5)
            start_recording()
            is_recording = True

        else:
            # 關麥 → 送出 → GPT/TTS → 自動開麥
            print("🔇 按下空白 → 關麥並送出給 GPT…")
            stop_recording()
            is_recording = False

            # 給 ASR 0.05 秒收最後一個 final
            time.sleep(0.05)

            process_student_speech()
   