import torch
import collections
from TTS.utils import radam
from TTS.utils.manage import ModelManager
from TTS.api import TTS

def tts_model():
     model_name = "tts_models/zh-CN/baker/tacotron2-DDC-GST"
     
     # 下載模型或找到本地路徑
     manager = ModelManager()
     checkpoint_file = manager.download_model(model_name)[0]  # 直接就是 model_file.pth
     # print("checkpoint 路徑:", checkpoint_file)

     # 列出 checkpoint 中的不安全 globals
     unsafe_globals = torch.serialization.get_unsafe_globals_in_checkpoint(checkpoint_file)
     # print("Unsafe globals in checkpoint:", unsafe_globals)

     # 加入 safe globals
     torch.serialization.add_safe_globals([dict, collections.defaultdict, radam.RAdam])

     # 載入 checkpoint
     checkpoint = torch.load(checkpoint_file, map_location="cpu", weights_only=True)
     # print("Checkpoint 成功載入！")

     text = input("plz input text:")
     output_path = input("plz input the output path, press 'd' if u want to use the default path:").strip('"')
     if output_path.lower() == "d":
          output_path = r"D:\Desktop\\-\\testtttt\stt_tts\\output.wav"
     
     # 初始化 TTS 並生成語音
     tts = TTS(model_name)  # TTS 內部會自動使用 safe globals
     tts.tts_to_file(text=text, file_path=output_path)
     return print(f"> 語音已儲存到：{output_path}")

     



#還沒看API 有stt也有tts
# https://developer.yating.tw/zh-TW/doc/introduction-%E7%94%A2%E5%93%81%E8%88%87%E4%BD%BF%E7%94%A8%E4%BB%8B%E7%B4%B9
# https://studio.yating.tw/intro/zh-TW

#想試試的模組
# https://www.youtube.com/watch?v=0PuslZHJQes
# https://pyttsx3.readthedocs.io/en/latest/engine.html

#想試試的模組
# https://medium.com/@zzxiang/text-to-speech-in-6-lines-of-python-code-free-no-online-api-a428a163decd
# from espnet2.bin.tts_inference import Text2Speech
# import soundfile
# text2speech = Text2Speech.from_pretrained("kan-bayashi/ljspeech_vits")
# text = "Hello, this is a text-to-speech test. Does my speech sound good?"
# speech = text2speech(text)["wav"]
# soundfile.write("output.wav", speech.numpy(), text2speech.fs, "PCM_16")