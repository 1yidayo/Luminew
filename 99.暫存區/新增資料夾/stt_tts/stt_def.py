import whisper #stt
from printcolor import color
import subprocess, os

def convert_to_wav():
    input_file = input(color("plz input stt file path, press 'd' if u want to use the default path:")).strip().strip('"').strip("'")
    if input_file.lower() == "d":
          input_file = r"D:\Desktop\\-\\testtttt\\stt_tts\\0815.mp3"
    output_file = os.path.splitext(input_file)[0] + "_conv.wav"
    cmd = ["ffmpeg", "-y", "-i", input_file, "-ar", "16000", "-ac", "1", output_file]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return output_file

def load_whisper_model(model_size="medium"):
    model = whisper.load_model(model_size)
    return model
def transcribe_audio(model):
    file_path = input(color("plz input stt file path, press 'd' if u want to use the default path:")).strip().strip('"').strip("'")
    if file_path.lower() == "d":
          file_path = r"D:\Desktop\\-\\testtttt\\stt_tts\\0815.mp3"
    result = model.transcribe(file_path)
    print(color("> stt辨識結果：" + result["text"]))
    return result["text"]

from opencc import OpenCC #簡轉繁
def opencc_model(text):
    cc = OpenCC('s2twp') 
    cc_output = cc.convert(text)
    print(color("> 簡轉繁結果：" + cc_output))
    return cc_output

import jieba #jieba斷句
def jieba_model(text):
    jieba.set_dictionary("D:\Desktop\-\\testtttt\stt_tts\dict.txt.big") #繁體詞庫
    jieba_output = '，'.join(jieba.cut(text, cut_all=False, HMM=True))
    print(color("> jieba中文斷句結果：" + jieba_output))
    return jieba_output

"""
可指定自己的词典 用法： jieba.load_userdict(file_name) # file_name 为文件类对象或自定义词典的路径
词典格式和 dict.txt 一样，一个词占一行；每一行分三部分：词语、词频（可省略）、词性（可省略），用空格隔开，顺序不可颠倒。
file_name 若为路径或二进制方式打开的文件，则文件必须为 UTF-8 编码。
"""
# text = '我來到北京清華大學'
# print('預設:', '，'.join(jieba.cut(text, cut_all=False, HMM=True))) #用著個
# print('預設:', '，'.join(jieba.cut(text, cut_all=True, HMM=True)))
# print('全關閉:', '，'.join(jieba.cut(text, cut_all=False, HMM=False)))
# print('全關閉:', '，'.join(jieba.cut(text, cut_all=True, HMM=True)))

# “今天天气 不错”应该被切成“今天 天气 不错”？（以及类似情况）
# 解决方法：强制调低词频 jieba.suggest_freq(('今天', '天气'), True)
# 或者直接删除该词 jieba.del_word('今天天气')
# 使用 add_word(word, freq=None, tag=None) 和 del_word(word) 可在程序中动态修改词典。
# 使用 suggest_freq(segment, tune=True) 可调节单个词语的词频，使其能（或不能）被分出来。

