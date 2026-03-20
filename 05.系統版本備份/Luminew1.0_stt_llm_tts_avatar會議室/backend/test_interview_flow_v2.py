# test_interview_flow_v2.py
import time
from app.services.InterviewManager import InterviewManager

def run_interview_v2():
    # 1. 初始化面試官
    manager = InterviewManager(professor_type="warm_industry_professor")
    
    print("\n" + "="*60)
    print("🎓 AI 面試流程 V2 測試 (開場白 -> 手動關麥 -> 自動開麥)")
    print("="*60)
    print("教授角色:", manager.professor_persona.name)
    print("\n[流程說明]:")
    print("1. 程式啟動後，教授會先說開場白。")
    print("2. 開場白結束後，麥克風會【自動開啟】（綠色提示）。")
    print("3. 當您講完後，請按一次 [Enter] 鍵進行【手動關麥】。")
    print("4. 教授會思考並回答，回答完後麥克風會【再次自動開啟】。")
    print("5. 持續循環，直到按下 Ctrl+C 結束。")
    print("="*60 + "\n")

    # 啟動面試 (會包含：ASR準備 -> 開場白TTS -> 自動開麥)
    manager.start_interview()

    try:
        round_count = 1
        while True:
            print(f"\n" + "="*20)
            print(f"   [對話第 {round_count} 輪]   ")
            print("="*20)
            print("💡 提示：現在麥克風是開啟的，您可以開始說話。")
            input(f"🎤 如果您講完了，請按 [Enter] 鍵結束錄音並送出...")
            
            print("\n🚀 [動作] 偵測到 Enter，正在請求教授回應...")
            # 手動觸發關麥與生成回應
            manager.process_speech_end()
            
            # 程式碼走到這裡時，教授的回應已經播完了，且內部已經自動 call 了 start_recording
            # 我們只需要稍等一下日誌顯示，然後繼續循環
            time.sleep(0.5)
            round_count += 1

    except KeyboardInterrupt:
        print("\n⏹ 外力介入，面試終止。")
    finally:
        manager.stop_interview()

if __name__ == "__main__":
    run_interview_v2()
