import whisper

def load_whisper_model(model_size="medium"):
    model = whisper.load_model(model_size)
    return model

def transcribe_audio(model, file_path):
    result = model.transcribe(file_path)
    return result["text"]
