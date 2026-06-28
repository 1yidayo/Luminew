# emotion_service.py
# 情緒分析核心服務 - 非同步 + 多線程版本

import os
import cv2
import numpy as np
import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
import httpx
from dotenv import load_dotenv
import traceback
from collections import deque
import uuid
import json
import asyncio
from concurrent.futures import ThreadPoolExecutor
import subprocess

# 載入環境變數
load_dotenv()

# ---------------------------
# 全域設定
# ---------------------------
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_PATH = os.path.join(PROJECT_DIR, "models", "test_best_.pth")
VIDEO_STORAGE_DIR = os.path.join(PROJECT_DIR, "static", "videos")
os.makedirs(VIDEO_STORAGE_DIR, exist_ok=True)

# [FIX] 背景處理執行緒池
video_executor = ThreadPoolExecutor(max_workers=2)

def flip_video_horizontally(video_path: str):
    """
    使用 ffmpeg 將影片水平翻轉 (hflip)
    這會直接覆蓋原檔案，確保後台儲存的影片也是鏡像的
    """
    if not os.path.exists(video_path):
        print(f"[WARN] [Flip] 檔案不存在: {video_path}")
        return
        
    temp_path = video_path + ".temp.mp4"
    try:
        print(f"[FIX] [Flip] 開始背景翻轉影片: {video_path}")
        # -vf hflip: 水平翻轉
        cmd = [
            'ffmpeg', '-y', '-i', video_path,
            '-vf', 'hflip',
            '-c:a', 'copy',
            temp_path
        ]
        # 使用 subprocess 執行
        subprocess.run(cmd, check=True, capture_output=True)
        # 覆蓋原檔
        os.replace(temp_path, video_path)
        print(f"[OK] [Flip] 影片鏡像完成: {video_path}")
    except Exception as e:
        print(f"[ERROR] [Flip] 影片翻轉失敗: {e}")
        if os.path.exists(temp_path):
            os.remove(temp_path)

def flip_video_async(video_path: str):
    """
    在背景非同步執行翻轉任務
    """
    video_executor.submit(flip_video_horizontally, video_path)

# OpenAI API Key
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if OPENAI_API_KEY:
    print(f"[AUTH] OpenAI API Key: {OPENAI_API_KEY[:10]}...")
    print("✅ OpenAI API 設定成功")
# 載入人臉辨識器 (使用 OpenCV DNN，比 Haar 準確且避開 mediapipe 路徑 bug)
PROTOTXT_PATH = os.path.join(PROJECT_DIR, "deploy.prototxt")
MODEL_WEIGHTS_PATH = os.path.join(PROJECT_DIR, "res10_300x300_ssd_iter_140000_fp16.caffemodel")

if os.path.exists(PROTOTXT_PATH) and os.path.exists(MODEL_WEIGHTS_PATH):
    print("📂 成功載入 OpenCV DNN 人臉辨識模組")
    face_net = cv2.dnn.readNetFromCaffe(PROTOTXT_PATH, MODEL_WEIGHTS_PATH)
    # [GPU 加速] 讓 OpenCV DNN 也跑在顯卡上
    if torch.cuda.is_available():
        face_net.setPreferableBackend(cv2.dnn.DNN_BACKEND_CUDA)
        face_net.setPreferableTarget(cv2.dnn.DNN_TARGET_CUDA)
        print("⚡ OpenCV DNN 已切換至 CUDA GPU 模式")
else:
    print("❌ 找不到 OpenCV DNN 模型黨，請確認下載成功")
    face_net = None

# 載入情緒模型 (ResNet18)
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
CLASSES = ['confidence', 'nervous', 'passion', 'relaxed']

model = models.resnet18(pretrained=False)
try:
    checkpoint = torch.load(MODEL_PATH, map_location=device)
    state_dict = checkpoint["state_dict"] if "state_dict" in checkpoint else checkpoint
    
    fc_keys = [k for k in state_dict.keys() if k.startswith("fc.")]
    use_sequential = any(k.startswith("fc.1.") for k in fc_keys)
    
    if use_sequential:
        model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(model.fc.in_features, len(CLASSES)))
    else:
        model.fc = nn.Linear(model.fc.in_features, len(CLASSES))
        
    model.load_state_dict(state_dict, strict=False)
    print("✅ 情緒辨識模型載入成功")
except Exception as e:
    print(f"❌ 模型載入失敗: {e}")
    model.fc = nn.Linear(model.fc.in_features, len(CLASSES))

model = model.to(device)
model.eval()

# 影像預處理 (還原為模型訓練時的數值)
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5])
])

# ★★★ 建立共用的 ThreadPoolExecutor ★★★
# 最多同時處理 4 個影片任務
executor = ThreadPoolExecutor(max_workers=4)


def get_video_storage_dir():
    """取得影片儲存目錄"""
    return VIDEO_STORAGE_DIR


def flip_video_horizontally(video_path: str):
    """
    使用 ffmpeg 將影片水平翻轉 (hflip)
    這會直接覆蓋原檔案，確保後台儲存的影片也是鏡像的
    """
    try:
        base, ext = os.path.splitext(video_path)
        temp_path = f"{base}_temp{ext}"
        # -vf hflip: 水平翻轉; -c:a copy: 音訊不重新編碼以加快速度
        cmd = [
            'ffmpeg', '-y', '-i', video_path, 
            '-vf', 'hflip', 
            '-c:a', 'copy', 
            temp_path
        ]
        print(f"🎬 [FFmpeg] 正在執行翻轉: {' '.join(cmd)}")
        # Windows 下有時需要 shell=True 才能抓到 PATH 中的 ffmpeg
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        
        if result.returncode == 0 and os.path.exists(temp_path):
            os.replace(temp_path, video_path)
            print("✅ 影片翻轉成功")
        else:
            print(f"⚠️ [FFmpeg] 翻轉不支援或找不到: {result.stderr}")
            if os.path.exists(temp_path): os.remove(temp_path)
    except Exception as e:
        print(f"⚠️ [FFmpeg] 執行拋出異常: {e}")


def _analyze_video_sync(video_path: str, save_video: bool, baseline: dict = None) -> dict:
    """同步處理影片的核心邏輯 (在獨立線程中執行)"""
    try:
        print(f"🎬 [Worker] 開始處理影片: {video_path}")
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            return {"error": "Could not open video"}

        timeline_data = []
        fps = cap.get(cv2.CAP_PROP_FPS)
        if fps == 0 or fps is None or fps > 100:
            fps = 30
            
        # ★ [效能優化] 提速關鍵：面試影片動輒 1~3 分鐘。
        # 為了大幅提升分析速度並避免 Nginx 60 秒 Timeout，將取樣率降為「每 2 秒 1 幀」。
        process_interval = max(1, int(fps) * 2)
        # 時間軸紀錄頻率：配合處理頻率
        record_interval = process_interval

        session_history = []
        frame_count = 0
        detected_count = 0
        
        # ★ [效能優化] 人臉框快取：不用每幀都跑 DNN 偵測，沿用舊框
        cached_face_box = None
        cached_face_ttl = 0
        
        orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        print(f"🎥 原始影片尺寸: {orig_w} x {orig_h}, FPS: {fps}, 處理間隔: {process_interval}")

        # 因為處理頻率降低，平滑佇列長度也跟著縮小，避免時間延遲太嚴重 (5 幀約等於 2.5 秒)
        smooth_queue = deque(maxlen=5)

        with torch.no_grad():
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                
                frame_count += 1
                if frame_count % process_interval != 0:
                    continue

                # ★ [效能優化] 人臉追蹤快取
                # 如果快取還有效，直接沿用上一次的臉部位置
                if cached_face_box is not None and cached_face_ttl > 0:
                    (x, y, w, h) = cached_face_box
                    # 確保沒有超出邊界
                    h_orig, w_orig = frame.shape[:2]
                    if x + w <= w_orig and y + h <= h_orig:
                        face_crop = frame[y:y+h, x:x+w]
                        cached_face_ttl -= 1
                        detected_count += 1
                        found_face_info = True # 標記成功
                    else:
                        cached_face_box = None
                        cached_face_ttl = 0
                        found_face_info = None
                else:
                    found_face_info = None

                # 如果沒有快取或快取失效，重新跑 DNN 偵測
                if found_face_info is None:
                    # 縮小圖片以加快偵測速度
                    h_orig, w_orig = frame.shape[:2]
                    if w_orig > 640:
                        scale = 640.0 / w_orig
                        frame_small = cv2.resize(frame, (640, int(h_orig * scale)))
                    else:
                        frame_small = frame
                        
                    # ★ 使用 OpenCV DNN 抓臉
                    if face_net is not None:
                        blob = cv2.dnn.blobFromImage(cv2.resize(frame_small, (300, 300)), 1.0, (300, 300), (104.0, 177.0, 123.0))
                        face_net.setInput(blob)
                        detections = face_net.forward()

                        faces = []
                        ih, iw = frame_small.shape[:2]
                        for i in range(0, detections.shape[2]):
                            confidence = detections[0, 0, i, 2]
                            if confidence > 0.5:  # 門檻值 0.5
                                box = detections[0, 0, i, 3:7] * np.array([iw, ih, iw, ih])
                                (startX, startY, endX, endY) = box.astype("int")
                                
                                # 確保在邊界內
                                startX, startY = max(0, startX), max(0, startY)
                                endX, endY = min(iw, endX), min(ih, endY)
                                
                                w, h = endX - startX, endY - startY
                                if w > 0 and h > 0:
                                    faces.append((startX, startY, w, h))
                        
                        if len(faces) > 0:
                             if w_orig > 640:
                                scale_inv = w_orig / 640.0
                                faces = [(int(fx*scale_inv), int(fy*scale_inv), int(fw*scale_inv), int(fh*scale_inv)) for (fx, fy, fw, fh) in faces]
                                found_face_info = faces
                             else:
                                found_face_info = faces

                    if found_face_info is None:
                        continue

                    detected_count += 1
                    faces = found_face_info
                    (x, y, w, h) = max(faces, key=lambda f: f[2] * f[3])
                    
                    # 更新快取 (讓接下來的 3 秒都直接沿用這個框)
                    cached_face_box = (x, y, w, h)
                    cached_face_ttl = 3 
                    
                    # 裁切臉部
                    face_crop = frame[y:y+h, x:x+w]

                try:
                    img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
                    img = Image.fromarray(img)
                    img_tensor = transform(img).unsqueeze(0).to(device)

                    outputs = model(img_tensor)
                    probs = torch.softmax(outputs, dim=1)[0]
                    
                    smooth_queue.append(probs.cpu())
                    # ★ 加權移動平均（越近的幀影響越大）
                    n = len(smooth_queue)
                    weights = torch.linspace(0.5, 1.0, n)
                    weights = weights / weights.sum()
                    avg_probs = (torch.stack(list(smooth_queue)) * weights.unsqueeze(1)).sum(dim=0)

                    current_emotions = {}
                    for i, cls in enumerate(CLASSES):
                        current_emotions[cls] = avg_probs[i].item()
                    
                    session_history.append(current_emotions)

                    # ★ 改用 record_interval，因為我們每秒只提取 2 幀，這裡如果整除就可以記錄
                    # 或是直接把它當作每次處理 (process_interval) 都要記錄也行，因為 2 幀/秒 數據量不大
                    if frame_count % record_interval == 0 or frame_count % record_interval < process_interval:
                        t_emotions = {
                            "c": current_emotions['confidence'] * 100,
                            "n": current_emotions['nervous'] * 100,
                            "p": current_emotions['passion'] * 100,
                            "r": current_emotions['relaxed'] * 100
                        }
                        
                        # ★ 若有 baseline，在時間軸也要套用校準
                        if baseline:
                            for k, cls in zip(['c', 'n', 'p', 'r'], CLASSES):
                                base_val = baseline.get(cls, 0)
                                # 使用比例調整，避免歸零
                                if base_val > 0.1:
                                    t_emotions[k] = t_emotions[k] * (50.0 / max(0.1, base_val))
                            
                            # 重新歸一化時間軸
                            t_total = sum(t_emotions.values())
                            if t_total > 0:
                                for k in ['c', 'n', 'p', 'r']:
                                    t_emotions[k] = (t_emotions[k] / t_total) * 100

                        timeline_entry = {
                            "t": round(frame_count / fps, 1),
                            "c": int(t_emotions['c']),
                            "n": int(t_emotions['n']),
                            "p": int(t_emotions['p']),
                            "r": int(t_emotions['r'])
                        }
                        timeline_data.append(timeline_entry)

                except Exception:
                    pass

        cap.release()
        print(f"📊 [Worker] 分析完成：共 {frame_count} 幀，辨識 {detected_count} 幀")
        
        if not session_history:
            video_url = None
            if save_video:
                filename = os.path.basename(video_path)
                video_url = f"/static/videos/{filename}"
            else:
                try:
                    os.remove(video_path)
                    print(f"🗑️ 已刪除暫存影片")
                except:
                    pass
            return {
                "emotions": {"confidence": 0, "nervous": 0, "passion": 0, "relaxed": 0},
                "timeline": [],
                "final_scores_float": {"confidence": 0.0, "nervous": 0.0, "passion": 0.0, "relaxed": 0.0},
                "video_url": video_url,
                "face_detected": False
            }

        # 計算平均分數
        avg_scores = {cls: 0.0 for cls in CLASSES}
        for entry in session_history:
            for cls in CLASSES:
                avg_scores[cls] += entry[cls]
                
        final_scores_float = {}
        for cls in CLASSES:
            final_scores_float[cls] = (avg_scores[cls] / len(session_history)) * 100
        
        # ★ 基線校準：使用比例調整而非絕對扣除，防止歸零
        if baseline:
            print(f"🎯 套用個人基線校準 (比例法): {baseline}")
            for cls in CLASSES:
                baseline_val = baseline.get(cls, 0)
                # 假設基線狀態代表該情緒的「中性強度」(例如 50%)
                # 如果目前分數高於基線，就會被放大；低於則縮小
                if baseline_val > 0.1:
                    final_scores_float[cls] = final_scores_float[cls] * (50.0 / max(0.1, baseline_val))
            
            # 重新歸一化到加總 = 100
            total = sum(final_scores_float.values())
            if total > 0:
                for cls in CLASSES:
                    final_scores_float[cls] = (final_scores_float[cls] / total) * 100
            print(f"🎯 校準後分數: {final_scores_float}")
        
        final_scores_int = {k: int(v) for k, v in final_scores_float.items()}
        print(f"📈 結果: {final_scores_int}")

        # 處理影片 URL (使用公開網址而非 10.0.2.2)
        video_url = None
        if save_video:
            filename = os.path.basename(video_path)
            video_url = f"/static/videos/{filename}"
        else:
            try:
                os.remove(video_path)
                print(f"🗑️ 已刪除暫存影片")
            except:
                pass

        return {
            "emotions": final_scores_int,
            "timeline": timeline_data,
            "final_scores_float": final_scores_float,
            "video_url": video_url
        }

    except Exception as e:
        print(f"❌ [Worker] 分析錯誤: {e}")
        traceback.print_exc()
        return {"error": f"Error: {str(e)}"}


def _generate_ai_feedback_sync(final_scores_float: dict, transcript: list = None, interviewer: str = "warm_industry_professor", face_detected: bool = True) -> dict:
    """同步生成 AI 評語 (在獨立線程中執行)"""
    try:
        if not OPENAI_API_KEY:
            raise Exception("無 API Key")
        
        confidence = final_scores_float.get('confidence', 0)
        passion = final_scores_float.get('passion', 0)
        relaxed = final_scores_float.get('relaxed', 0)
        nervous = final_scores_float.get('nervous', 0)
        
        # 取得面試官 Persona
        from app.services.professor_persona import get_professor_persona
        persona = get_professor_persona(interviewer)
        persona_desc = persona.prompt
        persona_name = persona.name
        
        # 整理對話紀錄
        chat_text = "無對話紀錄"
        if transcript and len(transcript) > 0:
            chat_lines = []
            for msg in transcript:
                role_name = "面試官" if msg.get("role") == "professor" else "學生"
                text = msg.get("text", "")
                chat_lines.append(f"【{role_name}】{text}")
            chat_text = "\n".join(chat_lines)

        # 未偵測到臉部的提示注入與三層防護鎖
        if not face_detected:
            face_status_prompt = """【⚠️ 重要評分調整：未偵測到臉部表情】
- 由於此影片未偵測到清晰的人臉表情，微表情與情緒分數 (20%) 直接以 0 分計。
- 請僅針對「口語回答內容」進行評估與打分（口語回答滿分為 100 分），並將該口語分數乘以 0.8 後作為最終的 `overall_score`（例如口語得 80 分，最終 overall_score 為 64 分）。"""
            
            guidelines_prompt = """- 請使用「你」直接對學生說話，不可使用「他」或「學生」等第三人稱來稱呼。
- 你的評分依據為：口語回答內容 (佔 100%)。由於此面試未偵測到人臉表情，請完全忽略表情指標，僅根據回答內容評估。"""
            
            emotion_data_prompt = "⚠️ 注意：此影片完全未偵測到人臉，因此沒有任何表情與情緒數據。請忽略任何情緒分析，不可憑空捏造或猜測表情數據。"
            
            comment_desc = "150-250字的綜合評語。由於本次面試未偵測到學生的臉部表情，你必須『只針對學生的口語回答內容與邏輯』進行評分與評語，嚴禁在評語中提及任何微表情數據或情緒狀態（如緊張度、自信度等百分比）。"
            
            suggestion_desc = "2-3 條具體可執行的改進建議，用分號分隔。你必須針對學生的回答內容、專業度與故事案例提出內容上的改善建議，嚴禁提及任何與情緒或表情調整有關的建議。"
        else:
            face_status_prompt = ""
            
            guidelines_prompt = """- 請使用「你」直接對學生說話，不可使用「他」或「學生」等第三人稱來稱呼。
- 你的兩大評分依據為：
  1. 口語回答內容 (佔 80%)：學生是否有針對問題給出具體、有邏輯、符合該職位/科系期待的答案？內容是否貧乏或不知所云？
  2. 微表情與情緒 (佔 20%)：考量到壓力測試或溫和引導，學生表現出的情緒是否合宜？"""
            
            emotion_data_prompt = f"""- 自信程度: {confidence:.0f}%
- 表達熱忱: {passion:.0f}%
- 放鬆程度: {relaxed:.0f}%
- 緊張程度: {nervous:.0f}%"""
            
            comment_desc = "150-250字的綜合評語。你必須「結合對話內容與表情數據」：具體引述學生在逐字稿中說的某句話，並指出在講那句話（或整體面試）時，他的微表情數據（例如緊張度高達X%或自信僅有Y%）透露了什麼訊號。告訴他哪裡暴露了不自信、或是哪段內容太過空洞。"
            
            suggestion_desc = "2-3 條具體可執行的改進建議，用分號分隔。你必須明確指出他在逐字稿中『回答哪一題或哪句話』時情緒表現不佳（如太緊張或沒熱忱），並給出針對該句話的具體改善解法（例如教他下次講到這題時怎麼放鬆，或是內容該怎麼補強）。"

        # ★★★ 改進版提示詞 ★★★
        prompt = f"""你是專業的面試培訓教練，正在直接對學生說話。
你這次安排讓學生與扮演「{persona_name}」的 AI 面試官進行面試。
面試官的性格設定為：{persona_desc}

請嚴格根據以下的「面試問答逐字稿」以及「微表情數據分析」，提供非常具有區別性、直接且客觀的建設性評估。
{face_status_prompt}

【重要指南：提升分數區別度】
{guidelines_prompt}

目前學生分數普遍偏高。為了鼓勵學生並保持鑑別度，請精準給分，避免大家的分數都差不多。分數範圍應真實分布在 45~95 分之間（不給滿分，留有進步空間）：
85-95分：表現優異。回答具體有邏輯、內容豐富，且情緒表現佳（展現自信或熱忱）。
75-84分：表現良好。內容順暢適切，能回答到核心，情緒數據合理正常。
65-74分：表現尚可。回答略顯簡短、缺乏具體例子、背稿感較重，或情緒數據顯示較為緊張。
55-64分：需要加強。答非所問、內容空洞、明顯支吾其詞，且情緒面臨較大壓力。
45-54分：表現極需改善。幾乎沒有回答實質內容、放棄作答、或只有極少數草率回應。

【面試問答逐字稿】
{chat_text}

【情緒微表情數據分析】
{emotion_data_prompt}

【評分標準】（請依此計算 overall_score 與 relevance）
1. overall_score: 請根據上述級距，針對學生的實際表現給出「精準」的整數分數，不要習慣性給中間分數。請避免只給以 0 或 5 結尾的整數。
2. relevance: 請嚴格審視學生的回答內容是否切題：
   - 85-95分：完全針對問題回答，緊扣核心且內容充實。
   - 75-84分：有回答到問題，但可能稍微發散或稍嫌簡短。
   - 65-74分：只回答到邊緣，或內容偏題、沒有針對具體情境。
   - 55-64分：幾乎答非所問、文不對題、或不知所云。
   - 45-54分：沒有實質回答、回答「不知道」、或放棄作答。
   若回答內容空洞或放棄作答，overall_score 與 relevance 皆必須落在 45-54 分之間。
3. 最終分數必須為一個介於 45-95 的整數。

【回覆格式】
請用繁體中文回覆，符合台灣人的說話習慣。
請只回傳純 JSON（不要 Markdown 區塊），格式如下：
{{
  "overall_score": 綜合上述標準給出嚴格的整數分數 (45~95),
  "relevance": 針對學生回答內容的切題率給予的整數分數 (45~95，代表回答與問題的契合度、聚焦度，要有區分度，不要與 overall_score 完全一樣),
  "comment": "{comment_desc}",
  "suggestion": "{suggestion_desc}"
}}"""
            
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "gpt-4o-mini",  # ★ 升級為 4o-mini，品質更好
            "messages": [
                {"role": "system", "content": "你是 Luminew 專業面試專家。請直接回傳 JSON。"},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 800  # ★ 增加 token 上限以應付更長的逐字稿與評語
        }
        
        print("🤖 呼叫 OpenAI 生成評語 (同步，在獨立線程中)...")
        
        # ★★★ 使用同步 httpx ★★★
        with httpx.Client(timeout=30.0) as client:
            resp = client.post(url, headers=headers, json=payload)
        
        if resp.status_code == 200:
            content = resp.json()["choices"][0]["message"]["content"]
            clean = content.replace("```json", "").replace("```", "").strip()
            return json.loads(clean)
        else:
            raise Exception(f"API Error {resp.status_code}")

    except Exception as e:
        print(f"⚠️ 啟用救援評語: {e}")
        # ★★★ 改進版救援邏輯：使用評分標準計算 ★★★
        c = int(confidence) if 'confidence' in dir() else int(final_scores_float.get('confidence', 0))
        p = int(final_scores_float.get('passion', 0))
        r = int(final_scores_float.get('relaxed', 0))
        n = int(final_scores_float.get('nervous', 0))
        
        if not face_detected:
            calc_score = 52 # 65 * 0.8
            comment_text = "由於未偵測到臉部表情，系統已略過微表情分析，僅根據口語回答內容提供基本評析。請多練習模擬面試並確保光源充足。"
        else:
            calc_score = 65
            if c >= 30: calc_score += 10
            if c >= 50: calc_score += 10
            if p >= 30: calc_score += 5
            if r >= 30: calc_score += 5
            if n >= 20: calc_score -= 5
            if n >= 35: calc_score -= 10
            calc_score = int(min(max(calc_score, 45), 95))
            comment_text = f"你的自信程度為 {c}%，整體表現{'良好' if c >= 50 else '尚可'}。{'熱忱度足夠，能感受到你對這次面試的重視。' if p >= 40 else '建議展現更多熱忱。'}{'但緊張程度較高，可能影響發揮。' if n >= 50 else '情緒控制穩定。'}建議多練習模擬面試以提升表現。"
        
        # 救援模式下，切題率給予一個與整體分數有細微區隔的合理預設值
        fallback_relevance = int(min(max(calc_score + 3, 45), 95))
        
        return {
            "overall_score": calc_score,
            "relevance": fallback_relevance,
            "comment": comment_text,
            "suggestion": "面試前做 3 次深呼吸放鬆；練習對鏡子回答問題；準備 2-3 個自己的故事案例"
        }


async def analyze_video(video_path: str, save_video: bool = True, baseline: dict = None, transcript: list = None, interviewer: str = "warm_industry_professor") -> dict:
    """
    非同步分析影片
    - 影片處理：在 ThreadPoolExecutor 中執行（不阻塞主線程）
    - AI 評語：也在 ThreadPoolExecutor 中執行
    - baseline：個人校準基線（可選）
    - public_url: Ngrok 公開網址
    """
    loop = asyncio.get_event_loop()
    
    # ★★★ 使用 ThreadPoolExecutor 執行影片分析 ★★★
    video_result = await loop.run_in_executor(
        executor, _analyze_video_sync, video_path, save_video, baseline
    )
    
    if "error" in video_result:
        return video_result
    
    # 提取分析結果
    final_scores_float = video_result.pop("final_scores_float", {})
    face_detected = video_result.get("face_detected", True)
    
    # ★★★ 在獨立線程中呼叫 OpenAI ★★★
    ai_feedback = await loop.run_in_executor(executor, _generate_ai_feedback_sync, final_scores_float, transcript, interviewer, face_detected)
    
    video_result["ai_analysis"] = ai_feedback
    return video_result


def _calibrate_sync(video_path: str) -> dict:
    """
    同步校準：分析短影片，回傳個人情緒基線 (在獨立線程中執行)
    """
    try:
        print(f"🎯 [校準] 開始處理: {video_path}")
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            return {"error": "無法開啟校準影片"}
        
        session_history = []
        frame_count = 0
        
        with torch.no_grad():
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                
                frame_count += 1
                if frame_count % 3 != 0:
                    continue
                
                # 縮小圖片
                h_orig, w_orig = frame.shape[:2]
                if w_orig > 640:
                    scale = 640.0 / w_orig
                    frame_small = cv2.resize(frame, (640, int(h_orig * scale)))
                else:
                    frame_small = frame
                
                # 人臉偵測
                if face_net is None:
                    continue
                
                blob = cv2.dnn.blobFromImage(
                    cv2.resize(frame_small, (300, 300)), 1.0, (300, 300), (104.0, 177.0, 123.0)
                )
                face_net.setInput(blob)
                detections = face_net.forward()
                
                ih, iw = frame_small.shape[:2]
                best_face = None
                best_area = 0
                
                for i in range(detections.shape[2]):
                    conf = detections[0, 0, i, 2]
                    if conf > 0.5:
                        box = detections[0, 0, i, 3:7] * np.array([iw, ih, iw, ih])
                        (sx, sy, ex, ey) = box.astype("int")
                        sx, sy = max(0, sx), max(0, sy)
                        ex, ey = min(iw, ex), min(ih, ey)
                        w, h = ex - sx, ey - sy
                        if w * h > best_area:
                            best_area = w * h
                            # 還原到原始座標
                            if w_orig > 640:
                                inv = w_orig / 640.0
                                best_face = (int(sx*inv), int(sy*inv), int(w*inv), int(h*inv))
                            else:
                                best_face = (sx, sy, w, h)
                
                if best_face is None:
                    continue
                
                x, y, w, h = best_face
                face_crop = frame[y:y+h, x:x+w]
                
                try:
                    img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
                    img = Image.fromarray(img)
                    img_tensor = transform(img).unsqueeze(0).to(device)
                    
                    outputs = model(img_tensor)
                    probs = torch.softmax(outputs, dim=1)[0]
                    
                    emotions = {}
                    for i, cls in enumerate(CLASSES):
                        emotions[cls] = probs[i].item()
                    session_history.append(emotions)
                except Exception:
                    pass
        
        cap.release()
        
        # 刪除暫存影片
        try:
            os.remove(video_path)
        except:
            pass
        
        if not session_history:
            return {"error": "校準失敗：未偵測到人臉，請確認臉部正對鏡頭"}
        
        # 計算基線（各情緒平均值 × 100）
        baseline = {cls: 0.0 for cls in CLASSES}
        for entry in session_history:
            for cls in CLASSES:
                baseline[cls] += entry[cls]
        for cls in CLASSES:
            baseline[cls] = (baseline[cls] / len(session_history)) * 100
        
        baseline_int = {k: round(v, 1) for k, v in baseline.items()}
        print(f"🎯 [校準] 基線結果 ({len(session_history)} 幀): {baseline_int}")
        
        return {"success": True, "baseline": baseline_int, "frames_analyzed": len(session_history)}
    
    except Exception as e:
        print(f"❌ [校準] 錯誤: {e}")
        traceback.print_exc()
        return {"error": f"校準失敗: {str(e)}"}


async def calibrate_baseline(video_path: str) -> dict:
    """非同步入口 - 在獨立線程中執行校準"""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(executor, _calibrate_sync, video_path)


def _analyze_portfolio_sync(pdf_path: str) -> dict:
    """同步分析學習歷程 PDF (在獨立線程中執行)"""
    try:
        # 提取 PDF 文字內容
        try:
            from PyPDF2 import PdfReader
            text_content = ""
            
            reader = PdfReader(pdf_path)
            for page in reader.pages:
                t = page.extract_text()
                if t:
                    text_content += t + "\n"
            
            print(f"📖 提取到 {len(text_content)} 字")
            
            if len(text_content.strip()) < 50:
                try: os.remove(pdf_path)
                except: pass
                return {"error": "PDF 內容過少或為純圖片格式，無法分析。請上傳包含文字的 PDF。"}
            
        except Exception as pdf_err:
            try: os.remove(pdf_path)
            except: pass
            print(f"❌ PDF 解析失敗: {pdf_err}")
            return {"error": f"PDF 解析失敗: {str(pdf_err)}"}
        
        if not OPENAI_API_KEY:
            try: os.remove(pdf_path)
            except: pass
            return {"error": "OpenAI API 未設定"}
        
        # 限制文字長度
        max_chars = 10000
        if len(text_content) > max_chars:
            text_content = text_content[:max_chars] + "\n...(內容過長，已截斷)"
        
        prompt = f"""
        你是一位專業的高中升大學輔導專家，同時也是教育部「學習歷程檔案」的審閱委員。你將審閱一份學生的檔案內容，並提供精確、不帶分數、且具備實質建設性的反饋。

        【學習歷程內容】
        {text_content}

        【請依照以下格式給予評價】
        請只回傳一個 JSON，不要有任何 Markdown 標記：
        {{
            "summary": "【整體評語】內容：總結整份檔案的描述主題與事件。分析學生表達了什麼、呈現了多少寫作上的優點與缺點。語氣：採用綜合性敘述，請以『你』直接稱呼學生，語氣專業且溫暖。嚴禁提到分數、嚴禁在此列舉細項優缺點。導引：若檔案有精進空間，請提及『具體精進方式可參考改進建議區塊』。推薦活動：若檔案屬於自傳或經歷描述，請判斷學生可能的目標科系方向。若方向明確，請在段落結尾推薦 1-2 個台灣高中生實際可參加的活動、競賽或資源（例如：旺宏科學獎、全國小論文比賽、台大醫學營等），以豐富其經歷。若方向模糊則不需強行推薦。",
            "strengths": [
                "請具體分項列出寫作優勢 1",
                "請具體分項列出寫作優勢 2",
                "..."
            ],
            "weaknesses": [
                "請具體分項列出技術性缺點 1",
                "請具體分項列出技術性缺點 2",
                "..."
            ],
            "suggestions": [
                "請具體分項列出優化建議 1",
                "請具體分項列出優化建議 2",
                "..."
            ]
        }}
        特別提醒：
        1. 核心理念：我們不評判學生的經歷內容（例如：當社長很好、參加比賽很棒），而是分析他「如何呈現」這份檔案。
        2. 亮點優勢：請著重於寫作上「值得鼓勵」的地方（如：敘事節奏、情感真摯、架構清晰等）。
        3. 不足之處：僅指出「撰寫技術」上的缺失（如：結構不完整、缺乏例證、邏輯斷層等），嚴禁在此寫出建議。
        4. 改進建議：除了針對缺失提供改善方式（對症下藥），也應廣泛地提出其他精進建議（宏觀指引）。
        5. 務必分項回傳 JSON Array，請勿將多個觀點擠在同一個字串中。
        """
        
        print("🤖 正在呼叫 OpenAI 分析學習歷程 (同步，在獨立線程中)...")
        
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant that outputs JSON."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
        }
        
        # ★★★ 使用同步 httpx ★★★
        with httpx.Client(timeout=60.0) as client:
            resp = client.post(url, headers=headers, json=payload)
        
        if resp.status_code == 200:
            content = resp.json()["choices"][0]["message"]["content"]
            clean_text = content.replace('```json', '').replace('```', '').strip()
            result_json = json.loads(clean_text)
            
            try: os.remove(pdf_path)
            except: pass
            
            return {
                "success": True,
                "analysis": result_json
            }
        else:
             raise Exception(f"API Error: {resp.status_code}")
        
    except Exception as e:
        print(f"❌ 學習歷程分析失敗: {e}")
        traceback.print_exc()
        return {"error": f"分析失敗: {str(e)}"}


async def analyze_portfolio(pdf_path: str) -> dict:
    """非同步入口 - 在獨立線程中執行分析"""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(executor, _analyze_portfolio_sync, pdf_path)
