# read_history.py
import json

log_path = r"C:\Users\Luminew\.gemini\antigravity-ide\brain\a6266cdd-cbbd-44bd-bb23-3eb18b37194f\.system_generated\logs\transcript.jsonl"
out_path = r"C:\Users\Luminew\Desktop\Luminew\Luminew\Luminew\history.txt"

history = []
with open(log_path, "r", encoding="utf-8") as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get("type") == "USER_INPUT":
                created_at = data.get("created_at", "")
                content = data.get("content", "")
                history.append(f"[{created_at}] USER:\n{content}\n" + "="*50 + "\n")
        except Exception as e:
            pass

with open(out_path, "w", encoding="utf-8") as f:
    f.writelines(history)

print("Done writing history to history.txt")
