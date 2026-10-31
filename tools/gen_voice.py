#!/usr/bin/env python3
"""Placeholder voices via Piper (local). Run with /workspace/_gd/venv/bin/python. Writes audio/voice/<id>.ogg.
Swap for recorded actors by overwriting the same file name. Voice models: john/joe/ljspeech (public domain / CC0), alba (CC BY 4.0, credited)."""
import json, os, subprocess, tempfile, wave
from piper import PiperVoice, SynthesisConfig
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V = "/workspace/_gd/voices"
# speaker: (model, length_scale, pitch ratio, extra ffmpeg filter)
CFG = {"jesus": ("en_US-john-medium", 1.12, 0.93, ""), "narrator": ("en_GB-alba-medium", 1.06, 1.0, ""),
 "mary": ("en_US-ljspeech-medium", 1.08, 0.97, ""), "naomi": ("en_US-ljspeech-medium", 1.0, 1.08, ""),
 "steward": ("en_US-joe-medium", 1.0, 0.97, ""), "servant": ("en_US-joe-medium", 0.95, 1.12, ""),
 "guest": ("en_US-joe-medium", 0.95, 1.05, ""), "guestf": ("en_US-ljspeech-medium", 0.95, 1.15, "")}
lines = json.load(open(ROOT + "/data/lines.json")); cache = {}
os.makedirs(ROOT + "/audio/voice", exist_ok=True)
for lid, d in lines.items():
    m, ls, pitch, _ = CFG[d["speaker"]]
    v = cache.get(m) or cache.setdefault(m, PiperVoice.load(f"{V}/{m}.onnx"))
    sr = v.config.sample_rate
    with tempfile.TemporaryDirectory() as t:
        w = t + "/a.wav"
        with wave.open(w, "wb") as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr)
            for c in v.synthesize(d["text"], syn_config=SynthesisConfig(length_scale=ls)): f.writeframes(c.audio_int16_bytes)
        af = f"asetrate={int(sr*pitch)},aresample=22050,atempo={1/pitch:.4f},loudnorm=I=-18:TP=-2:LRA=11"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-af", af, "-ar", "22050", "-c:a", "libvorbis", "-q:a", "3", f"{ROOT}/audio/voice/{lid}.ogg"], check=True)
        dur = float(subprocess.check_output(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",f"{ROOT}/audio/voice/{lid}.ogg"]))
        d["dur"] = round(dur, 2)
json.dump(lines, open(ROOT + "/data/lines.json", "w"), indent=1, ensure_ascii=False)
print("voices done", len(lines))
