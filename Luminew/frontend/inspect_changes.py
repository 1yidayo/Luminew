import subprocess
import os

try:
    # 1. Run git diff --name-status to see what's changed in tracked files
    res = subprocess.run(["git", "diff", "--name-status"], capture_output=True, text=True)
    tracked_changes = res.stdout
    
    # 2. Run git status --porcelain to see untracked files too
    res2 = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)
    all_status = res2.stdout
    
    # 3. Write all diffs to a file to analyze
    diffs = {}
    for line in all_status.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) < 2:
            continue
        status, filepath = parts
        # If it's a modified file, let's get its diff summary
        if status in ['M', 'MM']:
            res_diff = subprocess.run(["git", "diff", filepath], capture_output=True, text=True, errors="ignore")
            # Only store first 100 lines of diff for brevity
            diff_lines = res_diff.stdout.splitlines()
            diffs[filepath] = "\n".join(diff_lines[:100])
        elif status == '??':
            # Untracked file: read first 20 lines
            if os.path.isfile(filepath):
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read(2000)
                    diffs[filepath] = f"[NEW FILE]\n" + content[:1000]
                except:
                    diffs[filepath] = "[NEW FILE] (Unable to read content)"
            else:
                diffs[filepath] = "[NEW DIRECTORY / BINARY]"

    # Write output to a local txt file
    out_path = "frontend/git_changes_summary.txt"
    with open(out_path, 'w', encoding='utf-8') as out:
        out.write("=== GIT CHANGES SUMMARY ===\n\n")
        out.write("--- ALL STATUS ---\n")
        out.write(all_status + "\n\n")
        for filepath, diff_content in diffs.items():
            out.write(f"=========================================\n")
            out.write(f"FILE: {filepath}\n")
            out.write(f"=========================================\n")
            out.write(diff_content + "\n\n")
            
    print("Successfully wrote summary to frontend/git_changes_summary.txt")
except Exception as e:
    print("Error:", e)
