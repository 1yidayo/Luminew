# test_interviews.py
import threading
import asyncio
import time
from app.services.InterviewManager import InterviewManager

def run_interview():
    manager = InterviewManager(professor_type="warm_industry_professor")
    manager.start_interview()

    print("🎓 面試系統已連線，按 Enter 開始講話，講完再按 Enter 停止錄音並生成回應")
    print("🔹 Ctrl+C 隨時結束面試\n")

    try:
        while True:
            input("🎤 按 Enter 開麥，開始講話...")
            # 開始錄音（保險起見先清空 pending）
            manager.pending_student_texts = []
            manager.stt.start_recording()
            print("🟢 麥克風已開啟，開始說話...（Enter 關麥）")
            input()  # 等待學生按 Enter 關麥

            # 關麥，送給 LLM 生成回答，TTS 播放
            print("⏹ 已停止錄音，等待辨識結果...")
            manager.process_speech_end()

            # 暫停 0.5 秒再提示開麥，避免 TTS 與錄音衝突
            time.sleep(0.5)
            print("🔹 下一輪可以按 Enter 開麥...\n")

    except KeyboardInterrupt:
        print("\n⏹ 面試中斷")
        manager.stop_interview()


if __name__ == "__main__":
    run_interview()