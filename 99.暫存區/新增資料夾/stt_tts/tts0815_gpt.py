import torch
from TTS.utils import radam

# 將 RAdam 加入 safe globals
torch.serialization.add_safe_globals([radam.RAdam])

from TTS.api import TTS #conda tts_env_310

# 選一個支援多語系與多說話者的模型
model_name = "tts_models/zh-CN/baker/tacotron2-DDC-GST"

# 載入模型
tts = TTS(model_name)

print("支援的語言：", tts.languages)
print("支援的說話人：", tts.speakers)

language = "en"         # 報錯無中文

# text = "你好，我是AI語音合成系統。"
text = "Hello, i' m AI voice robot. Nice to meet you."

output_path = r"D:\Desktop\\-\\testtttt\\tts_stt\\output.wav"

# 執行 TTS 並輸出檔案
tts.tts_to_file(text=text, speaker=tts.speakers[0], language=language, file_path=output_path)

print("語音已儲存到", output_path)