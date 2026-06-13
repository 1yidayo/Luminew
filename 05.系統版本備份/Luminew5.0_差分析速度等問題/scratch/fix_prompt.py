import os
import re

file_path = 'backend/app/services/emotion_service.py'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 匹配目前的 JSON 區塊（包含之前的提醒字串）
pattern = r'\{\{\s+"summary": "【整體評語】.*?特別提醒：.*?JSON Array\."'

# 恢復原始穩定版本，並將新理念整合至提醒區塊
new_prompt_content = """{{
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
        5. 務必分項回傳 JSON Array，請勿將多個觀點擠在同一個字串中。" """

if re.search(pattern, content, re.DOTALL):
    new_content = re.sub(pattern, new_prompt_content, content, flags=re.DOTALL)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Successfully restored original prompt structure with integrated core philosophy.")
else:
    # 備用匹配方案（如果 pattern 稍有不同）
    pattern_alt = r'\{\{\s+"summary": "【整體評語】.*?\}\}'
    if re.search(pattern_alt, content, re.DOTALL):
        new_content = re.sub(pattern_alt, new_prompt_content, content, flags=re.DOTALL)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Restored using alternative pattern.")
    else:
        print("Pattern not found for restoration.")
