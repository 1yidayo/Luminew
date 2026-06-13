import os
import subprocess

unmerged_paths = [
    "backend/app/api/emotion.py",
    "backend/app/api/interview.py",
    "backend/app/services/InterviewManager.py",
    "backend/app/services/emotion_service.py",
    "backend/app/services/yating_stt.py",
    "frontend/lib/interview_ws_service.dart",
    "frontend/lib/screens/interview_screens.dart"
]

os.makedirs("conflicts", exist_ok=True)

for path in unmerged_paths:
    # Get filename
    filename = os.path.basename(path)
    
    # In git index, the path is relative to repo root. Repo root is C:/xampp/htdocs/Luminew
    # Since we are in Luminew/Luminew, the index path is likely Luminew/<path>
    index_path = f"Luminew/{path}"
    
    # Save Ours (Stage 2)
    try:
        ours = subprocess.check_output(["git", "show", f":2:{index_path}"])
        with open(f"conflicts/{filename}.ours", "wb") as f:
            f.write(ours)
    except Exception as e:
        print(f"Error getting ours for {path}: {e}")

    # Save Theirs (Stage 3)
    try:
        theirs = subprocess.check_output(["git", "show", f":3:{index_path}"])
        with open(f"conflicts/{filename}.theirs", "wb") as f:
            f.write(theirs)
    except Exception as e:
        print(f"Error getting theirs for {path}: {e}")

    # Save Working Tree version
    try:
        with open(path, "rb") as f:
            with open(f"conflicts/{filename}.working", "wb") as w:
                w.write(f.read())
    except Exception as e:
        print(f"Error reading {path}: {e}")

print("Done extracting conflicts.")
