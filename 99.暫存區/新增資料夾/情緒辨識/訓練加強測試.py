import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import transforms, models
import cv2
import os
from torch.utils.data import Dataset, DataLoader, random_split
from PIL import Image

# -----------------------------
# 設定資料夾
# -----------------------------
PROJECT_DIR = r"C:\MicroExpressionProject"
VIDEO_DIR = os.path.join(PROJECT_DIR, "data", "test_videos")
MODEL_DIR = os.path.join(PROJECT_DIR, "models")
MODEL_PATH = os.path.join(MODEL_DIR, "test.pth") # 檔名加上 best
HAAR_CASCADE_PATH = os.path.join(PROJECT_DIR, "data", "haarcascade_frontalface_default.xml")
os.makedirs(VIDEO_DIR, exist_ok=True)
os.makedirs(MODEL_DIR, exist_ok=True)

# -----------------------------
# 影片資料集 Dataset
# -----------------------------
class VideoFrameDataset(Dataset):
    def __init__(self, video_dir, transform=None):
        self.video_files = [os.path.join(video_dir, f) for f in os.listdir(video_dir) if f.endswith((".mp4", ".avi"))]
        self.transform = transform
        self.data = []
        self.labels = []

        face_cascade = cv2.CascadeClassifier(HAAR_CASCADE_PATH)
        for vid_path in self.video_files:
            label_name = os.path.basename(vid_path).split("_")[0]
            cap = cv2.VideoCapture(vid_path)
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
                if len(faces) == 0:
                    continue
                x, y, w, h = faces[0]
                face_crop = frame[y:y+h, x:x+w]
                self.data.append(face_crop)
                self.labels.append(label_name)
            cap.release()

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

# -----------------------------
# Transform & Dataset
# -----------------------------
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

dataset = VideoFrameDataset(VIDEO_DIR, transform=transform)

if len(dataset) == 0:
    print("⚠️ 沒有任何可用的臉部資料，請確認 test_videos 裡是否有影片")
    exit()

# 80% 作為訓練集，20% 作為驗證集
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = random_split(dataset, [train_size, val_size])

# 建立各自的 DataLoader
train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False)

print("✅ 這次將訓練的表情類別:", dataset.classes)
print(f"✅ 資料集切分完成 -> 訓練集: {len(train_dataset)} 筆, 驗證集: {len(val_dataset)} 筆")

# -----------------------------
# 模型
# -----------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = models.resnet18(pretrained=True)
model.fc = nn.Sequential(
    nn.Dropout(0.3),
    nn.Linear(model.fc.in_features, len(dataset.classes))
)
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=1e-4, weight_decay=1e-5)

# ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
# <<< 修改點：移除 verbose=True 參數以相容舊版 PyTorch >>>
# ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, 'min', factor=0.1, patience=1)

# -----------------------------
# 載入舊模型繼續訓練（支援類別變動）
# -----------------------------
if os.path.exists(MODEL_PATH):
    checkpoint = torch.load(MODEL_PATH, map_location=device)
    state_dict = checkpoint["state_dict"]

    filtered_dict = {k:v for k,v in state_dict.items() if not k.startswith("fc.1.")}
    model.load_state_dict(filtered_dict, strict=False)
    print("✅ 已載入先前訓練過的模型權重（最後一層隨新類別數初始化），繼續訓練！")
else:
    print("🚀 沒有舊模型，將從頭開始訓練。")

# -----------------------------
# 訓練（含 Early Stopping + Ctrl+C 捕捉）
# -----------------------------
best_val_loss = float("inf")
patience = 2
counter = 0
delta = 1e-5
max_epochs = 20

print(f"\n🚀 開始訓練，共 {len(dataset.classes)} 種表情: {dataset.classes}\n")

try:
    for epoch in range(max_epochs):
        # --- 訓練階段 ---
        model.train()
        total_train_loss = 0
        for imgs, labels in train_loader:
            imgs, labels = imgs.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(imgs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            total_train_loss += loss.item()
        avg_train_loss = total_train_loss / len(train_loader)

        # --- 驗證階段 ---
        model.eval()
        total_val_loss = 0
        with torch.no_grad():
            for imgs, labels in val_loader:
                imgs, labels = imgs.to(device), labels.to(device)
                outputs = model(imgs)
                loss = criterion(outputs, labels)
                total_val_loss += loss.item()
        avg_val_loss = total_val_loss / len(val_loader)

        print(f"Epoch {epoch+1}/{max_epochs}: Train Loss={avg_train_loss:.6f}, Val Loss={avg_val_loss:.6f}")

        # Early Stopping 檢查基於 avg_val_loss
        if avg_val_loss < best_val_loss - delta:
            best_val_loss = avg_val_loss
            counter = 0
            torch.save({
                "state_dict": model.state_dict(),
                "classes": dataset.classes
            }, MODEL_PATH)
            print("✅ 驗證集 Loss 降低，已保存最佳模型！")
        else:
            counter += 1
            print(f"⚠️ 驗證集 Loss 未改善（第 {counter} 次）")
            if counter >= patience:
                print(f"⏹️ 連續 {patience} 次未改善，提前停止訓練。")
                break
        
        # 更新學習率
        scheduler.step(avg_val_loss)

except KeyboardInterrupt:
    print(f"\n⏹️ 訓練被手動中斷。")

print("\n🎉 訓練完成，最佳模型已儲存！")
print("已保存表情類別:", dataset.classes)