from stt_def import load_whisper_model, transcribe_audio, opencc_model, jieba_model, convert_to_wav

# file_path = convert_to_wav()

# 可輸入mp3, m4a或wav轉文字，會忽略單引雙引和空格，注意路徑的斜線要兩個

text = transcribe_audio(load_whisper_model("medium"))

cc_output = opencc_model(text)

jieba_output = jieba_model(cc_output)



