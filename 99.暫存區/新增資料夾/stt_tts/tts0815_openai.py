import requests

url = "https://api.ttsopenai.com/uapi/v1/document-to-speech"
headers = {
    "x-api-key": "tts-0bec4ec20f8d86262281dd07de6d4c36"
}

# 文字參數
data = {
    "model": "tts-1",
    "voice_id": "PE0182",
    "speed": "1"
}

# 檔案參數
files = {
    "file": open(r"D:\Desktop\\-\\testtttt\\tts_stt\\0815.txt", "rb")
}

response = requests.post(url, headers=headers, data=data, files=files)
print(response.json())
