import os
import json
import random

def get_random_questions(department="im", general_count=1, dept_count=2):
    """
    從 JSON 中隨機抽取指定數量的通用題與專業題
    """
    # 取得 app/data/questions 的絕對路徑
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_dir = os.path.join(base_dir, "data", "questions")
    
    general_file = os.path.join(data_dir, "general.json")
    dept_file = os.path.join(data_dir, f"{department}.json")
    
    questions = []
    
    # 讀取通用題並隨機抽取
    if os.path.exists(general_file):
        with open(general_file, "r", encoding="utf-8") as f:
            try:
                general_q = json.load(f)
                questions.extend(random.sample(general_q, min(general_count, len(general_q))))
            except Exception as e:
                print(f"[ERROR] 讀取通用題庫失敗: {e}")
                
    # 讀取科系專業題並隨機抽取
    if os.path.exists(dept_file):
        with open(dept_file, "r", encoding="utf-8") as f:
            try:
                dept_q = json.load(f)
                questions.extend(random.sample(dept_q, min(dept_count, len(dept_q))))
            except Exception as e:
                print(f"[ERROR] 讀取科系題庫失敗: {e}")
                
    return questions
