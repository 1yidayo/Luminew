# emotion_service.py
# 情緒分析核心服務 - 非同步 + 多線程版本

import os
import cv2
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

# 載入環境變數
load_dotenv()

# ---------------------------
# 全域設定
# ---------------------------
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_PATH = os.path.join(PROJECT_DIR, "models", "test_best_.pth")
VIDEO_STORAGE_DIR = os.path.join(PROJECT_DIR, "static", "videos")
os.makedirs(VIDEO_STORAGE_DIR, exist_ok=True)

# OpenAI API Key
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if OPENAI_API_KEY:
    print(f"🔑 OpenAI API Key 前十碼: {OPENAI_API_KEY[:10]}...")
    print("✅ OpenAI API 設定成功")
else:
    print("⚠️ 警告：找不到 OPENAI_API_KEY，AI 評語功能將使用本地評語")

# 載入人臉辨識器
HAAR_PATH = os.path.join(PROJECT_DIR, "haarcascade_frontalface_default.xml")
if not os.path.exists(HAAR_PATH):
    print(f"⚠️ 本地找不到 {HAAR_PATH}，嘗試使用 OpenCV 內建路徑...")
    HAAR_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'

print(f"📂 正在載入人臉辨識檔：{HAAR_PATH}")
face_cascade = cv2.CascadeClassifier(HAAR_PATH)

if face_cascade.empty():
    print("❌ 嚴重錯誤：無法載入人臉辨識器 (xml 檔案損毀或路徑錯誤)")

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

# 影像預處理
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

# ★★★ 建立共用的 ThreadPoolExecutor ★★★
# 最多同時處理 4 個影片任務
executor = ThreadPoolExecutor(max_workers=4)


def get_video_storage_dir():
    """取得影片儲存目錄"""
    return VIDEO_STORAGE_DIR


def _analyze_video_sync(video_path: str, save_video: bool) -> dict:
    """同步處理影片的核心邏輯 (在獨立線程中執行)"""
    try:
        print(f"🎬 [Worker] 開始處理影片: {video_path}")
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            return {"error": "Could not open video"}

        timeline_data = []
        fps = cap.get(cv2.CAP_PROP_FPS)
        if fps == 0 or fps is None:
            fps = 30
        frame_interval = max(1, int(fps / 3))

        session_history = []
        frame_count = 0
        detected_count = 0
        
        orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        print(f"🎥 原始影片尺寸: {orig_w} x {orig_h}, FPS: {fps}")

        smooth_queue = deque(maxlen=5)

        with torch.no_grad():
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                
                frame_count += 1
                if frame_count % 3 != 0:
                    continue

                # 縮小圖片以加快偵測速度
                h_orig, w_orig = frame.shape[:2]
                if w_orig > 640:
                    scale = 640 / w_orig
                    frame_small = cv2.resize(frame, (640, int(h_orig * scale)))
                else:
                    frame_small = frame
                    
                gray = cv2.cvtColor(frame_small, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray, 1.1, 8)
                
                found_face_info = None
                if len(faces) > 0:
                     if w_orig > 640:
                        scale_inv = w_orig / 640
                        faces = [(int(x*scale_inv), int(y*scale_inv), int(w*scale_inv), int(h*scale_inv)) for (x,y,w,h) in faces]
                        found_face_info = (frame, faces)
                     else:
                        found_face_info = (frame, faces)

                if found_face_info is None:
                    continue

                detected_count += 1
                correct_frame, faces = found_face_info
                (x, y, w, h) = max(faces, key=lambda f: f[2] * f[3])

                face_crop = correct_frame[y:y+h, x:x+w]

                try:
                    img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
                    img = Image.fromarray(img)
                    img_tensor = transform(img).unsqueeze(0).to(device)

                    outputs = model(img_tensor)
                    probs = torch.softmax(outputs, dim=1)[0]
                    
                    smooth_queue.append(probs.cpu())
                    avg_probs = torch.stack(list(smooth_queue), dim=0).mean(dim=0)

                    current_emotions = {}
                    for i, cls in enumerate(CLASSES):
                        current_emotions[cls] = avg_probs[i].item()
                    
                    session_history.append(current_emotions)

                    if frame_count % frame_interval == 0:
                        timeline_entry = {
                            "t": round(frame_count / fps, 1),
                            "c": int(current_emotions['confidence'] * 100),
                            "n": int(current_emotions['nervous'] * 100),
                            "p": int(current_emotions['passion'] * 100),
                            "r": int(current_emotions['relaxed'] * 100)
                        }
                        timeline_data.append(timeline_entry)

                except Exception:
                    pass

        cap.release()
        print(f"📊 [Worker] 分析完成：共 {frame_count} 幀，辨識 {detected_count} 幀")
        
        if not session_history:
            return {"error": "No face detected. Please fetch camera directly to your face."}

        # 計算平均分數
        avg_scores = {cls: 0.0 for cls in CLASSES}
        for entry in session_history:
            for cls in CLASSES:
                avg_scores[cls] += entry[cls]
                
        final_scores_float = {}
        for cls in CLASSES:
            final_scores_float[cls] = (avg_scores[cls] / len(session_history)) * 100
        
        final_scores_int = {k: int(v) for k, v in final_scores_float.items()}
        print(f"📈 結果: {final_scores_int}")

        # 處理影片 URL (先回傳，AI 評語稍後處理)
        video_url = None
        if save_video:
            filename = os.path.basename(video_path)
            video_url = f"http://10.0.2.2:8000/static/videos/{filename}"
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


def _generate_ai_feedback_sync(final_scores_float: dict) -> dict:
    """同步生成 AI 評語 (在獨立線程中執行)"""
    try:
        if not OPENAI_API_KEY:
            raise Exception("無 API Key")
        
        confidence = final_scores_float.get('confidence', 0)
        passion = final_scores_float.get('passion', 0)
        relaxed = final_scores_float.get('relaxed', 0)
        nervous = final_scores_float.get('nervous', 0)
        
        # ★★★ 改進版提示詞 ★★★
        prompt = f"""你是專業的面試培訓教練，正在直接對學生說話。請根據以下面試微表情分析結果，提供詳細且有建設性的評估。

【重要】請使用「你」直接對學生說話，不要用第三人稱。例如：「你的表現很好」而非「學生表現很好」。

【情緒數據分析】
- 自信程度: {confidence:.0f}%
- 表達熱忱: {passion:.0f}%
- 放鬆程度: {relaxed:.0f}%
- 緊張程度: {nervous:.0f}%

【評分標準】（請依此計算 overall_score）
1. 基礎分 60 分
2. 自信 ≥30% 加 15 分，≥50% 再加 10 分
3. 熱忱 ≥30% 加 10 分
4. 放鬆 ≥30% 加 5 分
5. 緊張 ≥20% 扣 10 分，≥35% 扣 15 分
6. 最終分數限制在 40-98 分之間

【回覆格式】
請只回傳純 JSON（不要 Markdown 區塊），格式如下：
{{
  "overall_score": 計算後的整數分數,
  "comment": "100-150字的綜合評語，用「你」直接對學生說話，需包含：(1) 你的表現優點 (2) 你需要改進之處 (3) 整體評價",
  "suggestion": "2-3 條具體可執行的改進建議，用「你」對學生說話，用分號分隔"
}}"""
            
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "gpt-3.5-turbo",
            "messages": [
                {"role": "system", "content": "你是專業面試教練，擅長分析微表情並給予具體建議。請只回傳 JSON，不要使用 Markdown。"},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 512  # ★ 增加 token 上限
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
        
        calc_score = 60
        if c >= 30: calc_score += 15
        if c >= 50: calc_score += 10
        if p >= 30: calc_score += 10
        if r >= 30: calc_score += 5
        if n >= 20: calc_score -= 10
        if n >= 35: calc_score -= 15
        calc_score = int(min(max(calc_score, 40), 98))
        
        return {
            "overall_score": calc_score,
            "comment": f"你的自信程度為 {c}%，整體表現{'良好' if c >= 50 else '尚可'}。{'熱忱度足夠，能感受到你對這次面試的重視。' if p >= 40 else '建議展現更多熱忱。'}{'但緊張程度較高，可能影響發揮。' if n >= 50 else '情緒控制穩定。'}建議多練習模擬面試以提升表現。",
            "suggestion": "面試前做 3 次深呼吸放鬆；練習對鏡子回答問題；準備 2-3 個自己的故事案例"
        }


async def analyze_video(video_path: str, save_video: bool = True) -> dict:
    """
    非同步分析影片
    - 影片處理：在 ThreadPoolExecutor 中執行（不阻塞主線程）
    - AI 評語：也在 ThreadPoolExecutor 中執行
    """
    loop = asyncio.get_event_loop()
    
    # ★★★ 使用 ThreadPoolExecutor 執行影片分析 ★★★
    # 這樣即使影片處理崩潰，也不會影響主程式
    video_result = await loop.run_in_executor(executor, _analyze_video_sync, video_path, save_video)
    
    if "error" in video_result:
        return video_result
    
    # 提取分析結果
    final_scores_float = video_result.pop("final_scores_float", {})
    
    # ★★★ 在獨立線程中呼叫 OpenAI ★★★
    ai_feedback = await loop.run_in_executor(executor, _generate_ai_feedback_sync, final_scores_float)
    
    video_result["ai_analysis"] = ai_feedback
    return video_result


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
        你是一位專業的高中升大學輔導專家，同時也是教育部「學習歷程檔案」的審閱委員。
        你正在審閱一位高中生的學習歷程檔案，請給予專業的評價和具體的改進建議。

        【學習歷程內容】
        {text_content}

        【請依照以下格式給予評價】
        請只回傳一個 JSON，不要有任何 Markdown 標記：
        {{
            "overall_score": (0-100 整數，根據內容完整性、個人特色、反思深度給分),
            "strengths": [
                "優點1",
                "優點2",
                "優點3"
            ],
            "weaknesses": [
                "需改進1",
                "需改進2"
            ],
            "comment": (100-150字的整體評語，指出這份學習歷程的亮點和可以加強的地方，要具體、有建設性),
            "suggestions": [
                "具體改進建議1",
                "具體改進建議2",
                "具體改進建議3"
            ]
        }}
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
            print(f"✅ 學習歷程分析完成！分數: {result_json.get('overall_score', 'N/A')}")
            
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
