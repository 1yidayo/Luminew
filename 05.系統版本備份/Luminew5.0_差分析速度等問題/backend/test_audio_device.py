import sounddevice as sd
import numpy as np

def test_audio():
    print("Available devices:")
    print(sd.query_devices())
    
    fs = 32000
    duration = 2  # seconds
    t = np.linspace(0, duration, int(fs * duration))
    # Generate a simple beep
    data = 0.5 * np.sin(2 * np.pi * 440 * t)
    
    print(f"Playing a 2-second beep at {fs}Hz...")
    try:
        sd.play(data, fs)
        sd.wait()
        print("Test complete. Did you hear anything?")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_audio()
