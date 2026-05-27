"""使用 faster-whisper 将音频文件转录为 SRT 字幕"""
import sys
from faster_whisper import WhisperModel


def format_timestamp(ms: float) -> str:
    h = int(ms // 3600000)
    m = int((ms % 3600000) // 60000)
    s = int((ms % 60000) // 1000)
    millis = int(ms % 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{millis:03d}"


def transcribe_to_srt(audio_path: str, model_size: str = "large-v3", language: str = "en"):
    print(f"Loading model {model_size} ...")
    model = WhisperModel(model_size, device="cpu", compute_type="int8")

    print(f"Transcribing {audio_path} (language={language}) ...")
    segments, info = model.transcribe(audio_path, language=language, vad_filter=True)

    srt_lines = []
    for i, segment in enumerate(segments, 1):
        start = format_timestamp(segment.start * 1000)
        end = format_timestamp(segment.end * 1000)
        text = segment.text.strip()
        srt_lines.append(f"{i}\n{start} --> {end}\n{text}\n")
        print(f"  [{i}] {start} --> {end}  {text}")

    return "\n".join(srt_lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python whisper_to_srt.py <audio_path> [language] [model_size]")
        sys.exit(1)

    audio_path = sys.argv[1]
    language = sys.argv[2] if len(sys.argv) > 2 else "en"
    model_size = sys.argv[3] if len(sys.argv) > 3 else "large-v3"

    srt_content = transcribe_to_srt(audio_path, model_size=model_size, language=language)

    output_path = audio_path.rsplit(".", 1)[0] + ".srt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(srt_content)
    print(f"\nSRT saved to: {output_path}")
