from sttdef0815_gpt import load_whisper_model, transcribe_audio

model = load_whisper_model("medium") #有比base準確

# 轉錄音檔
file_path = r"D:\Desktop\\-\\testtttt\\tts_stt\\test_stt.m4a"
text = transcribe_audio(model, file_path)

print("辨識結果：", text)

"""(繁體)
test_stt.m4a
測試測試，測試測試，這是一段音檔。

辨識結果： 測試測試測試測試就是一段音檔
"""

"""(簡體)
0815.mp3
大家好，我是 AI 語音測試系統。今天我們來測試語音辨識和語音合成的效果。
Hello everyone, this is an AI voice testing system. Today we are testing speech recognition and text-to-speech performance.
請注意發音清晰度和語速，看看系統是否能正確辨識中文和英文。
Please pay attention to pronunciation clarity and speaking speed, and see if the system can correctly recognize both Chinese and English.

warnings.warn("FP16 is not supported on CPU; using FP32 instead")
辨識結果： 大家好,我是AI语音测试系统今天我们来测试语音辨识和语音合成的效果Hello everyone, this is an AI voice testing systemToday we are testing speak ignition and text to speech performance请注意发音清晰度和语速看下系统是否能确辨识中文和英文Please pay attention to pronunciation clarity and speaking speedand see if the system can correctly recognize both Chinese and English
"""