import cv2
import os
import time

PROJECT_DIR = r"C:\MicroExpressionProject"
DATA_DIR = os.path.join(PROJECT_DIR, "data")
CALIBRATION_DIR = os.path.join(DATA_DIR, "calibration_videos")
os.makedirs(CALIBRATION_DIR, exist_ok=True)

# --- 設定 ---
RECORD_DURATION = 5  # 固定錄製5秒

# --- 主程式 ---
username = input("請輸入您的使用者名稱 (英文, e.g., justin_luo): ").strip()
if not username:
    print("使用者名稱不可為空！")
    exit()

user_video_dir = os.path.join(CALIBRATION_DIR, username)
os.makedirs(user_video_dir, exist_ok=True)

print(f"你好, {username}! 我們將開始個人化校準。")
# <<< 修改：更新提示訊息 >>>
print(f"請將您的臉部置於畫面中，準備好後按下 'q' 鍵，將會自動錄製 {RECORD_DURATION} 秒。")

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("無法開啟攝影機")
    exit()

frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
fps = cap.get(cv2.CAP_PROP_FPS)
if fps == 0:
    fps = 30
fourcc = cv2.VideoWriter_fourcc(*'mp4v')

# 檔名固定，代表這是中性基準影片
video_filename = "relaxed_baseline.mp4" 
video_path = os.path.join(user_video_dir, video_filename)
out = cv2.VideoWriter(video_path, fourcc, fps, (frame_width, frame_height))

# ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
# <<< 修改：採用 Q 鍵觸發、5秒自動結束的邏輯 >>>
recording = False
start_time = None

while True:
    ret, frame = cap.read()
    if not ret:
        print("無法讀取攝影機畫面！")
        break

    key = cv2.waitKey(1) & 0xFF

    # --- 狀態處理 ---
    # 1. 如果還沒開始錄製，等待 Q 鍵觸發
    if not recording:
        instruction_text = f"Press Q to start recording ({RECORD_DURATION} seconds)"
        cv2.putText(frame, instruction_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        if key == ord('q'):
            recording = True
            start_time = time.time() # 按下Q的瞬間，啟動計時器
            print(f"▶️ 開始錄製，{RECORD_DURATION} 秒後自動結束...")

    # 2. 如果正在錄製，更新畫面並檢查時間
    if recording:
        # 檢查是否已達到錄製時間
        elapsed_time = time.time() - start_time
        if elapsed_time >= RECORD_DURATION:
            break # 時間到，跳出主迴圈

        # 如果時間未到，繼續寫入影格並顯示倒數
        out.write(frame)
        remaining_time = int(RECORD_DURATION - elapsed_time) + 1
        record_text = f"RECORDING... {remaining_time}s left"
        cv2.putText(frame, record_text, (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    # 3. 按下 ESC 隨時可以提前結束
    if key == 27:
        if recording:
            print("⏹️ 錄製被手動中斷。")
        break
        
    cv2.imshow("個人化校準", frame)

# ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

print(f"\n✅ 自然表情錄製完成!")
print(f"🎉 {username} 的個人化校準已全部完成！影片儲存於 {video_path}")

# --- 釋放資源 ---
cap.release()
out.release()
cv2.destroyAllWindows()