import torch
import torch.nn as nn
from torchvision import transforms, models
import cv2
from PIL import Image
import os
import sys
from collections import deque

# -----------------------------
# 設定專案路徑
# -----------------------------
PROJECT_DIR = r"C:\MicroExpressionProject"
MODEL_PATH = os.path.join(PROJECT_DIR, "models", "image_test_model.pth")
HAAR_CASCADE_PATH = os.path.join(PROJECT_DIR, "data", "haarcascade_frontalface_default.xml")

# -----------------------------
# 檢查檔案
# -----------------------------
if not os.path.exists(MODEL_PATH):
    print(f"❌ 找不到模型檔：{MODEL_PATH}")
    sys.exit(1)
if not os.path.exists(HAAR_CASCADE_PATH):
    print(f"❌ 找不到 Haar Cascade XML：{HAAR_CASCADE_PATH}")
    sys.exit(1)

# -----------------------------
# 載入 checkpoint（到合適 device）
# -----------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
checkpoint = torch.load(MODEL_PATH, map_location=device)

# 檢查 checkpoint 內容
if "state_dict" in checkpoint:
    state_dict = checkpoint["state_dict"]
else:
    state_dict = checkpoint

# classes 檢查
if "classes" in checkpoint:
    classes = checkpoint["classes"]
else:
    print("⚠️ checkpoint 中沒有 'classes'，請在程式中手動指定 classes。")
    # 假設這是您的表情類別，如果不是請替換
    classes = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']

print(f"✅ Model loaded. Expressions to recognize: {classes}")

# -----------------------------
# 建立模型骨架（resnet18）
# -----------------------------
model = models.resnet18(pretrained=False)

# 判斷 checkpoint 裡 fc 層結構
fc_keys = [k for k in state_dict.keys() if k.startswith("fc.")]
use_sequential_fc = any(k.startswith("fc.1.") for k in fc_keys)

if use_sequential_fc:
    model.fc = nn.Sequential(
        nn.Dropout(0.3),
        nn.Linear(model.fc.in_features, len(classes))
    )
    print("ℹ️ 建立 model.fc = Sequential(Dropout(0.3), Linear(...))")
else:
    model.fc = nn.Linear(model.fc.in_features, len(classes))
    print("ℹ️ 建立 model.fc = Linear(...)")

model = model.to(device)

try:
    model.load_state_dict(state_dict)
except RuntimeError:
    print("⚠️ load_state_dict 嚴格匹配失敗，嘗試 lenient 載入 (strict=False)。")
    model.load_state_dict(state_dict, strict=False)

model.eval()

# -----------------------------
# 圖片預處理（需與訓練一致）
# -----------------------------
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

# -----------------------------
# 臉部偵測
# -----------------------------
face_cascade = cv2.CascadeClassifier(HAAR_CASCADE_PATH)
if face_cascade.empty():
    print("⚠️ 無法載入 Haar Cascade XML")
    sys.exit(1)

# -----------------------------
# 攝影機啟動
# -----------------------------
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("⚠️ 無法開啟攝影機")
    sys.exit(1)

print("▶ 按 ESC 結束，攝影機啟動中...")

# -----------------------------
# 平滑參數設定
# -----------------------------
SMOOTH_WINDOW = 5  # 您可以調整這個值來改變平滑程度，例如 5 或 10
smooth_queue = deque(maxlen=SMOOTH_WINDOW)

# -----------------------------
# 即時辨識主迴圈
# -----------------------------
with torch.no_grad():
    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 8)

        for (x, y, w, h) in faces:
            # 臉部裁切與轉換
            face_crop = frame[y:y+h, x:x+w]
            img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(img)
            img_tensor = transform(img).unsqueeze(0).to(device)

            # 模型推論
            outputs = model(img_tensor)
            probs = torch.softmax(outputs, dim=1)[0]

            # ✅ 平滑處理 (滑動平均)
            smooth_queue.append(probs.cpu())
            avg_probs = torch.stack(list(smooth_queue), dim=0).mean(dim=0)
            probs = avg_probs.to(device)

            # 取前三大表情 (torch.topk 會自動排序，最高的在最前面)
            k = min(3, len(classes))
            top_prob, top_idx = torch.topk(probs, k)
            results = [f"{classes[top_idx[i]]}: {top_prob[i]*100:.1f}%" for i in range(k)]

            # 顯示人臉框
            cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 0, 0), 2)
            
            # ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
            # 唯一的修改點：將顯示文字的座標固定在左上角
            # ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
            for i, text in enumerate(results):
                # 原始座標是 (x, y - 10 - i*25)，跟著人臉框(x,y)移動
                # 修改後座標是 (10, 30 + i*25)，固定在視窗左上角
                cv2.putText(frame, text, (10, 30 + i*25),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        cv2.imshow("MicroExpression Recognition", frame)
        if cv2.waitKey(1) & 0xFF == 27:  # ESC 離開
            break

cap.release()
cv2.destroyAllWindows()