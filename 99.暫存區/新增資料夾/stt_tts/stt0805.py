import whisper #conda tts_env

model = whisper.load_model("medium")
result = model.transcribe(r"D:\Desktop\\-\\testtttt\\tts_stt\\test_stt.m4a")
print("辨識結果：", result["text"])
