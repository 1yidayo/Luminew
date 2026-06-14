import os
import shutil
import subprocess
import sys

# 避免 Windows 終端機 Unicode 輸出報錯
if sys.platform.startswith("win"):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

def run_cmd(args, cwd=None):
    print(f"▶ 執行命令: {' '.join(args)} (工作路徑: {cwd or '.'})")
    res = subprocess.run(args, cwd=cwd, shell=True)
    if res.returncode != 0:
        print(f"❌ 命令執行失敗，回傳碼: {res.returncode}")
        sys.exit(res.returncode)
    print("✅ 執行成功")

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    frontend_dir = os.path.join(root_dir, "frontend")
    backend_dir = os.path.join(root_dir, "backend")
    web_build_src = os.path.join(frontend_dir, "build", "web")
    web_build_dest = os.path.join(backend_dir, "web_build")

    print("=== Step 1: 開始編譯 Flutter Web ===")
    run_cmd(["flutter", "build", "web", "--release"], cwd=frontend_dir)

    print("\n=== Step 2: 清理舊的部署目錄 ===")
    if os.path.exists(web_build_dest):
        print(f"正在移除 {web_build_dest}...")
        shutil.rmtree(web_build_dest)
    os.makedirs(web_build_dest, exist_ok=True)
    print("✅ 清理完成")

    print("\n=== Step 3: 複製編譯產物到後端目錄 ===")
    if not os.path.exists(web_build_src):
        print(f"❌ 找不到編譯來源目錄: {web_build_src}")
        sys.exit(1)

    # 複製檔案
    for item in os.listdir(web_build_src):
        s = os.path.join(web_build_src, item)
        d = os.path.join(web_build_dest, item)
        if os.path.isdir(s):
            shutil.copytree(s, d)
        else:
            shutil.copy2(s, d)
    print("✅ 複製完成！")

    print("\n=== Step 4: 重啟 PM2 後端服務 ===")
    try:
        # 嘗試使用 pm2 restart，如果系統有安裝 pm2
        run_cmd(["pm2", "restart", "luminew-backend"], cwd=backend_dir)
        print("✅ PM2 服務已成功重啟！")
    except Exception as e:
        print("⚠️ 未檢測到 pm2 或重啟失敗，請手動重啟後端 Python 服務。")

    print("\n🎉 部署編譯完成！最新程式碼已生效。")

if __name__ == "__main__":
    main()
