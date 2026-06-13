import os
import json
from PIL import Image

# 基本路徑設定
PROJECT_ROOT = r"C:\xampp\htdocs\Luminew\Luminew"
FRONTEND_ROOT = os.path.join(PROJECT_ROOT, "frontend")
SOURCE_IMAGE = os.path.join(PROJECT_ROOT, "backend", "brain", "luminew_source.png")

ANDROID_RES_DIR = os.path.join(FRONTEND_ROOT, "android", "app", "src", "main", "res")
IOS_ICONSET_DIR = os.path.join(FRONTEND_ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

# Android 尺寸定義 (px)
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

def generate_android_icons(source_path):
    print("--- 正在生成 Android 圖示 ---")
    with Image.open(source_path) as img:
        for folder, size in ANDROID_SIZES.items():
            target_dir = os.path.join(ANDROID_RES_DIR, folder)
            os.makedirs(target_dir, exist_ok=True)
            target_path = os.path.join(target_dir, "ic_launcher.png")
            
            # 轉換並縮放
            resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
            resized_img.save(target_path, "PNG")
            print(f"[OK] {folder}/ic_launcher.png (尺寸: {size}x{size})")

def generate_ios_icons(source_path):
    print("\n--- 正在生成 iOS 圖示 ---")
    contents_json_path = os.path.join(IOS_ICONSET_DIR, "Contents.json")
    if not os.path.exists(contents_json_path):
        print("[ERROR] 找不到 iOS Contents.json 檔案")
        return

    with open(contents_json_path, "r") as f:
        contents = json.load(f)

    with Image.open(source_path) as img:
        for image_info in contents.get("images", []):
            if "filename" not in image_info:
                continue
                
            filename = image_info["filename"]
            # 解析尺寸。格式通常是 "20x20", "29x29"
            size_str = image_info["size"]
            scale_str = image_info["scale"] # "1x", "2x", "3x"
            
            w, h = map(float, size_str.split('x'))
            scale = int(scale_str.replace('x', ''))
            
            target_w = int(w * scale)
            target_h = int(h * scale)
            
            target_path = os.path.join(IOS_ICONSET_DIR, filename)
            
            # 轉換並縮放
            resized_img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
            resized_img.save(target_path, "PNG")
            print(f"[OK] {filename} (實際尺寸: {target_w}x{target_h})")

if __name__ == "__main__":
    if not os.path.exists(SOURCE_IMAGE):
        print(f"[ERROR] 找不到原始圖檔: {SOURCE_IMAGE}")
    else:
        generate_android_icons(SOURCE_IMAGE)
        generate_ios_icons(SOURCE_IMAGE)
        print("\n🎉 所有圖示已成功生成並替換！")
