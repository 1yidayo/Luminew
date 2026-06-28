import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import transforms, models
import os
import sys
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import cv2

# -----------------------------
# 設定
# -----------------------------
PROJECT_DIR = r"C:\MicroExpressionProject"
DATA_DIR = os.path.join(PROJECT_DIR, "data")
MODEL_DIR = os.path.join(PROJECT_DIR, "models")
CALIBRATION_DIR = os.path.join(DATA_DIR, "calibration_videos")
HAAR_CASCADE_PATH = os.path.join(DATA_DIR, "haarcascade_frontalface_default.xml")

# --- VideoFrameDataset 類別定義 ---
class VideoFrameDataset(Dataset):
    def __init__(self, video_dir, transform=None):
        self.video_files = [os.path.join(video_dir, f) for f in os.listdir(video_dir) if f.endswith((".mp4", ".avi"))]
        self.transform = transform
        self.data = []
        self.labels = []

        face_cascade = cv2.CascadeClassifier(HAAR_CASCADE_PATH)
        print(f"正在從 {video_dir} 載入個人校準影片...")
        for vid_path in self.video_files:
            # 我們明確知道這段校準影片的標籤是 "relaxed"。
            label_name = "relaxed" 
            
            cap = cv2.VideoCapture(vid_path)
            while True:
                ret, frame = cap.read()
                if not ret: break
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
                if len(faces) == 0: continue
                x, y, w, h = faces[0]
                face_crop = frame[y:y+h, x:x+w]
                self.data.append(face_crop)
                self.labels.append(label_name)
            cap.release()
        print("個人校準影片載入完成！")
        
        self.classes = sorted(list(set(self.labels)))
        self.class_to_idx = {cls_name:i for i, cls_name in enumerate(self.classes)}
        self.idx_labels = [self.class_to_idx[l] for l in self.labels]

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        img = self.data[idx]
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(img)
        if self.transform:
            img = self.transform(img)
        label = self.idx_labels[idx]
        return img, label

# --- 微調超參數 ---
FINE_TUNE_EPOCHS = 12
FINE_TUNE_LR = 1e-5

# ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
# <<< 修改：從命令列接收參數，改成互動式輸入 >>>
# --- 主程式 ---
# 1. 自動掃描並列出所有可用的使用者
try:
    available_users = [name for name in os.listdir(CALIBRATION_DIR) if os.path.isdir(os.path.join(CALIBRATION_DIR, name))]
except FileNotFoundError:
    print(f"錯誤：找不到校準資料夾 {CALIBRATION_DIR}")
    input("按 Enter 鍵退出...")
    exit()

if not available_users:
    print(f"錯誤：在 '{CALIBRATION_DIR}' 中找不到任何使用者的校準資料夾！")
    print("請先執行 '2_個人化校準.py' 來建立資料。")
    input("按 Enter 鍵退出...")
    exit()

print("✅ 找到以下可用的個人化校準資料：")
for user in available_users:
    print(f"  - {user}")

# 2. 讓使用者輸入要處理的名稱，並驗證
username = ""
while True:
    username = input("\n> 請輸入您要進行微調的使用者名稱: ").strip()
    if username in available_users:
        break
    else:
        print(f"❌ 錯誤：找不到使用者 '{username}'。請從以上列表中選擇一個正確的名稱。")

# (原本接收 sys.argv 的部分已被上面取代)
# ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

user_video_dir = os.path.join(CALIBRATION_DIR, username)

# --- 載入通用基礎模型 ---
BASE_MODEL_PATH = os.path.join(MODEL_DIR, "test.pth")
if not os.path.exists(BASE_MODEL_PATH):
    print(f"錯誤：找不到通用基礎模型！請先執行 `3_訓練通用基礎模型.py`。")
    input("按 Enter 鍵退出...")
    exit()
    
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"正在從 {BASE_MODEL_PATH} 載入通用基礎模型...")
checkpoint = torch.load(BASE_MODEL_PATH, map_location=device)
classes = checkpoint['classes']
class_to_idx_base = {cls_name: i for i, cls_name in enumerate(classes)}

model = models.resnet18(pretrained=False)
model.fc = nn.Sequential(
    nn.Dropout(0.3),
    nn.Linear(model.fc.in_features, len(classes))
)
model.load_state_dict(checkpoint['state_dict'])
model = model.to(device)
print("✅ 通用基礎模型載入成功！")

# --- 準備個人化資料 ---
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

dataset = VideoFrameDataset(user_video_dir, transform=transform)
if len(dataset) == 0:
    print("錯誤：個人校準資料夾中沒有可用的臉部資料！")
    input("按 Enter 鍵退出...")
    exit()

try:
    relaxed_label_idx_in_base = class_to_idx_base["relaxed"]
    dataset.idx_labels = [relaxed_label_idx_in_base] * len(dataset)
except KeyError:
    print("錯誤：您的通用基礎模型中不包含 'relaxed' 這個類別！請確認標籤名稱。")
    input("按 Enter 鍵退出...")
    exit()

dataloader = DataLoader(dataset, batch_size=16, shuffle=True)

# --- 開始微調 ---
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=FINE_TUNE_LR)

print(f"\n🚀 開始為使用者 '{username}' 進行 {FINE_TUNE_EPOCHS} 輪的快速微調...")
model.train()
for epoch in range(FINE_TUNE_EPOCHS):
    total_loss = 0
    for imgs, labels in dataloader:
        imgs, labels = imgs.to(device), labels.to(device)
        
        optimizer.zero_grad()
        outputs = model(imgs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    
    avg_loss = total_loss / len(dataloader)
    print(f"微調 Epoch {epoch+1}/{FINE_TUNE_EPOCHS}, Loss: {avg_loss:.6f}")

# --- 儲存個人化模型 ---
PERSONAL_MODEL_PATH = os.path.join(MODEL_DIR, f"{username}_model.pth")
torch.save({
    "state_dict": model.state_dict(),
    "classes": classes
}, PERSONAL_MODEL_PATH)

print(f"\n🎉 微調完成！已為 '{username}' 產生專屬模型於: {PERSONAL_MODEL_PATH}")
input("按 Enter 鍵退出...") # 保持視窗開啟，直到使用者確認