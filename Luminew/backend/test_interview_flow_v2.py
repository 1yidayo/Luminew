# test_interview_flow_v2.py
import time
import asyncio
from app.services.InterviewManager import InterviewManager

async def run_interview_v2_async():
    """非同步面試流程"""
    # 1. 初始化面試官
    manager = InterviewManager(professor_type="warm_industry_professor")
    
    print("\n" + "="*60)
    print("🎓 AI 面試流程 V2 測試 (非同步版本)")
    print("="*60)
    print("教授角色:", manager.professor_persona.name)
    print("\n[流程說明]:")
    print("1. 程式啟動後，教授會先說開場白。")
    print("2. 開場白結束後，麥克風會【自動開啟】（綠色提示）。")
    print("3. 當您講完後，請按一次 [Enter] 鍵進行【手動關麥】。")
    print("4. 教授會思考並回答，回答完後麥克風會【再次自動開啟】。")
    print("5. 持續循環，直到按下 Ctrl+C 結束。")
    print("="*60 + "\n")

    # ★★★ 啟動面試（非同步，不阻塞）★★★
    await manager.start_interview()

    try:
        round_count = 1
        loop = asyncio.get_event_loop()
        
        while True:
            print(f"\n" + "="*20)
            print(f"   [對話第 {round_count} 輪]   ")
            print("="*20)
            print("💡 提示：現在麥克風是開啟的，您可以開始說話。")
            
            # ★★★ 在獨立線程等待 input（不阻塞事件循環）★★★
            await loop.run_in_executor(None, input, "🎤 如果您講完了，請按 [Enter] 鍵結束錄音並送出...")
            
            print("\n🚀 [動作] 偵測到 Enter，正在請求教授回應...")
            # ★★★ 非同步執行 process_speech_end ★★★
            await manager.process_speech_end_async()
            
            # 程式碼走到這裡時，教授的回應已經播完了，且內部已經自動 call 了 start_recording
            # 我們只需要稍等一下日誌顯示，然後繼續循環
            await asyncio.sleep(0.5)
            round_count += 1

    except KeyboardInterrupt:
        print("\n⏹ 外力介入，面試終止。")
    finally:
        manager.stop_interview()

# ★ 同步包裝（用於同步環境呼叫）
def run_interview_v2():
    """同步包裝"""
    asyncio.run(run_interview_v2_async())

if __name__ == "__main__":
    run_interview_v2()
