import torch
import torch.nn as nn
from torchvision import transforms, models
import cv2
from PIL import Image
import os
import sys
from collections import deque

# --- 主程式 ---
PROJECT_DIR = r"C:\MicroExpressionProject"
MODEL_DIR = os.path.join(PROJECT_DIR, "models")
DATA_DIR = os.path.join(PROJECT_DIR, "data")
HAAR_CASCADE_PATH = os.path.join(DATA_DIR, "haarcascade_frontalface_default.xml")

# --- 動態載入模型 ---
# 提示：請確保這裡的基礎模型檔名與您在 `3_訓練通用基礎模型.py` 中產生的檔名一致！
BASE_MODEL_FILENAME = "test.pth" # 或者您之前使用的 "test.pth", "test2_best.pth" 等

username = input("請輸入您的使用者名稱 (若無個人模型則直接按Enter使用通用模型): ").strip()
PERSONAL_MODEL_PATH = os.path.join(MODEL_DIR, f"{username}_model.pth")
BASE_MODEL_PATH = os.path.join(MODEL_DIR, BASE_MODEL_FILENAME)

MODEL_TO_LOAD = ""
if username and os.path.exists(PERSONAL_MODEL_PATH):
    MODEL_TO_LOAD = PERSONAL_MODEL_PATH
    print(f"✅ 找到使用者 '{username}' 的個人化模型，正在載入...")
elif os.path.exists(BASE_MODEL_PATH):
    MODEL_TO_LOAD = BASE_MODEL_PATH
    print(f"⚠️ 找不到 '{username}' 的個人化模型，將使用通用基礎模型。")
    print(f"💡 建議執行 `2_個人化校準.py` 和 `4_執行即時微調.py` 以獲得更佳體驗。")
else:
    print(f"❌ 錯誤：找不到任何模型！({BASE_MODEL_PATH})")
    print("請先執行訓練腳本產生基礎模型。")
    input("按 Enter 鍵退出...")
    sys.exit(1)

# --- 載入 Checkpoint ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
checkpoint = torch.load(MODEL_TO_LOAD, map_location=device)

if "state_dict" in checkpoint: state_dict = checkpoint["state_dict"]
else: state_dict = checkpoint

if "classes" in checkpoint: classes = checkpoint["classes"]
else:
    print("⚠️ checkpoint 中沒有 'classes'，請在程式中手動指定 classes。")
    classes = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']

print(f"✅ 模型載入完成. 可辨識表情: {classes}")

# --- 建立模型骨架並載入權重 ---
model = models.resnet18(pretrained=False)
fc_keys = [k for k in state_dict.keys() if k.startswith("fc.")]
use_sequential_fc = any(k.startswith("fc.1.") for k in fc_keys)
if use_sequential_fc:
    model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(model.fc.in_features, len(classes)))
else:
    model.fc = nn.Linear(model.fc.in_features, len(classes))

model = model.to(device)
try:
    model.load_state_dict(state_dict)
except RuntimeError as e:
    print(f"⚠️ 載入模型權重時發生錯誤: {e}")
    print("嘗試以 non-strict 模式載入...")
    model.load_state_dict(state_dict, strict=False)

model.eval()

# --- 圖片預處理 ---
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

# --- 初始化臉部偵測器與攝影機 ---
face_cascade = cv2.CascadeClassifier(HAAR_CASCADE_PATH)
if face_cascade.empty():
    print("❌ 錯誤：無法載入 Haar Cascade XML 檔案！")
    input("按 Enter 鍵退出...")
    sys.exit(1)

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("❌ 錯誤：無法開啟攝影機！")
    input("按 Enter 鍵退出...")
    sys.exit(1)

print("▶ 按 ESC 結束，攝影機啟動中...")

SMOOTH_WINDOW = 5
smooth_queue = deque(maxlen=SMOOTH_WINDOW)

# --- 即時辨識主迴圈 ---
with torch.no_grad():
    while True:
        ret, frame = cap.read()
        if not ret: continue
        
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 8)

        # 在畫面上顯示當前使用的模型
        model_name = os.path.basename(MODEL_TO_LOAD)
        cv2.putText(frame, f"Model: {model_name}", (10, frame.shape[0] - 10), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

        for (x, y, w, h) in faces:
            face_crop = frame[y:y+h, x:x+w]
            img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(img)
            img_tensor = transform(img).unsqueeze(0).to(device)

            outputs = model(img_tensor)
            probs = torch.softmax(outputs, dim=1)[0]

            # 平滑處理
            smooth_queue.append(probs.cpu())
            avg_probs = torch.stack(list(smooth_queue), dim=0).mean(dim=0)
            probs = avg_probs.to(device)

            # 取得前三大表情
            k = min(3, len(classes))
            top_prob, top_idx = torch.topk(probs, k)
            results = [f"{classes[top_idx[i]]}: {top_prob[i]*100:.1f}%" for i in range(k)]

            # 繪製結果
            cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 0, 0), 2)
            
            for i, text in enumerate(results):
                cv2.putText(frame, text, (10, 30 + i*25),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        cv2.imshow("個人化表情辨識系統", frame)
        if cv2.waitKey(1) & 0xFF == 27: # ESC 鍵
            break

# --- 釋放資源 ---
cap.release()
cv2.destroyAllWindows()