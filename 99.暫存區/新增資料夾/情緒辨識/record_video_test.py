import cv2
import os
from datetime import datetime
import re

PROJECT_DIR = r"C:\MicroExpressionProject"
DATA_DIR = os.path.join(PROJECT_DIR, "data")
RAW_VIDEO_DIR = os.path.join(DATA_DIR, "raw_videos")
os.makedirs(RAW_VIDEO_DIR, exist_ok=True)

while True:
    expression = input("Enter expression name (English, e.g., nervous): ").strip()
    if not expression:
        expression = "unknown"
        break
    if re.fullmatch(r"[A-Za-z0-9_]+", expression):
        break
    print("Error: Please enter only English letters or numbers (no spaces or symbols).")

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
video_filename = f"{expression}_{timestamp}.mp4"
video_path = os.path.join(RAW_VIDEO_DIR, video_filename)

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Cannot open camera")
    exit()

frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
fps = 30
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter(video_path, fourcc, fps, (frame_width, frame_height))

print("Press 'q' to start/pause recording, Press 'ESC' to exit")
recording = False
while True:
    ret, frame = cap.read()
    if not ret:
        continue

    

    if recording:
        out.write(frame)
        # Show recording status
        cv2.putText(frame, f"Recording... ({expression})", (10,90),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,0,255), 2)

    cv2.imshow("Record Video", frame)
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'):
        recording = not recording
    elif key == 27:
        break

cap.release()
out.release()
cv2.destroyAllWindows()
print(f"Recording finished! Video saved at: {video_path}")

