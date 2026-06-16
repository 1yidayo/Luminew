import os
import json
import random

# 含有「自我介紹」性質的關鍵詞，用來過濾通用型第二題不要重複問自介
_SELF_INTRO_KEYWORDS = ["自我介紹", "介紹你自己", "介紹一下你自己"]


def _load_json(filepath: str) -> list:
    """安全讀取 JSON 題庫，失敗回傳空陣列"""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[ERROR] 讀取題庫失敗 ({filepath}): {e}")
        return []


def _get_data_dir() -> str:
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_dir, "data", "questions")


def get_questions(department: str, count: int = 2, exclude_self_intro: bool = False) -> list:
    """
    回傳指定數量的題目。
    - department: "通用型" | "資管專業"
    - count: 要抽取的題目數量
    - exclude_self_intro: 若為 True，過濾掉含自介性質的題目（通用型第二題使用）
    """
    data_dir = _get_data_dir()

    if department == "通用型" or department == "general":
        pool = _load_json(os.path.join(data_dir, "general.json"))
    elif department == "資管專業" or department == "im":
        pool = _load_json(os.path.join(data_dir, "im.json"))
    else:
        pool = _load_json(os.path.join(data_dir, "general.json"))

    if exclude_self_intro:
        pool = [q for q in pool if not any(kw in q for kw in _SELF_INTRO_KEYWORDS)]

    if not pool:
        return []

    return random.sample(pool, min(count, len(pool)))


def get_random_questions(department="im", general_count=1, dept_count=2):
    """
    舊有介面，維持相容性。
    從 JSON 中隨機抽取指定數量的通用題與專業題。
    """
    data_dir = _get_data_dir()
    general_file = os.path.join(data_dir, "general.json")
    questions = []

    # 映射前端面試類型
    if department == "通用型" or department == "general":
        pool = _load_json(general_file)
        return random.sample(pool, min(3, len(pool))) if pool else []

    elif department == "資管專業":
        department = "im"

    dept_file = os.path.join(data_dir, f"{department}.json")

    # 讀取通用題並隨機抽取
    general_q = _load_json(general_file)
    if general_q:
        questions.extend(random.sample(general_q, min(general_count, len(general_q))))

    # 讀取科系專業題並隨機抽取
    dept_q = _load_json(dept_file)
    if dept_q:
        questions.extend(random.sample(dept_q, min(dept_count, len(dept_q))))

    return questions

