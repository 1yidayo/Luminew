import cv2
import os
from tkinter import Tk, filedialog

# -----------------------------
# 專案設定
# -----------------------------
PROJECT_DIR = r"C:\MicroExpressionProject"
VIDEO_DIR = os.path.join(PROJECT_DIR, "data", "raw_videos")
OUTPUT_DIR = os.path.join(PROJECT_DIR, "data", "processed_videos")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# -----------------------------
# 輔助函式：調整亮度
# -----------------------------
def adjust_brightness(frame, factor=1.0):
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hsv = hsv.astype("float32")
    hsv[..., 2] = hsv[..., 2] * factor
    hsv[..., 2] = hsv[..., 2].clip(0, 255)
    hsv = hsv.astype("uint8")
    return cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)

# -----------------------------
# 選擇影片檔案
# -----------------------------
Tk().withdraw()  # 不顯示主視窗
video_path = filedialog.askopenfilename(
    initialdir=VIDEO_DIR,
    title="選擇要處理的影片",
    filetypes=[("Video files", "*.mp4 *.avi *.mov *.mkv")]
)

if not video_path:
    print("⚠️ 沒有選取任何影片，程式結束")
    exit()

video_name = os.path.basename(video_path)
print("🎬 已選擇影片:", video_name)

# -----------------------------
# 開啟影片
# -----------------------------
cap = cv2.VideoCapture(video_path)
if not cap.isOpened():
    print(f"⚠️ 無法開啟影片: {video_path}")
    exit()

# 影片參數（保留原始大小與幀率）
fps = cap.get(cv2.CAP_PROP_FPS)
frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
fourcc = int(cap.get(cv2.CAP_PROP_FOURCC))

# 輸出影片路徑
bright_path = os.path.join(OUTPUT_DIR, f"{os.path.splitext(video_name)[0]}_bright.mp4")
dark_path = os.path.join(OUTPUT_DIR, f"{os.path.splitext(video_name)[0]}_dark.mp4")

out_bright = cv2.VideoWriter(bright_path, fourcc, fps, (frame_width, frame_height))
out_dark = cv2.VideoWriter(dark_path, fourcc, fps, (frame_width, frame_height))

# -----------------------------
# 處理影片
# -----------------------------
print("🚀 開始處理影片...")
while True:
    ret, frame = cap.read()
    if not ret:
        break

    # 調亮與調暗
    bright_frame = adjust_brightness(frame, 1.5)
    dark_frame = adjust_brightness(frame, 0.5)

    out_bright.write(bright_frame)
    out_dark.write(dark_frame)

# 釋放資源
cap.release()
out_bright.release()
out_dark.release()

print("✅ 處理完成！")
print("輸出檔案：")
print(" -", bright_path)
print(" -", dark_path)




