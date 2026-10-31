#!/usr/bin/env python3
"""Self-generated CC0 SFX and music for Walk With Him (numpy synthesis, fixed seed). Writes audio/sfx/*.ogg and audio/music/*.ogg.
Reuses the synthesis helpers from the Nehemiah prototype."""
import os, subprocess, wave, numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
rng = np.random.default_rng(7)
def t_(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] = np.minimum(e[-nr:], np.linspace(1, 0, nr)); return e
def lp(x, k):  # one-pole lowpass, k in 0..1 (bigger = brighter)
    y = np.zeros_like(x); s = 0.0
    for i in range(len(x)): s += k * (x[i] - s); y[i] = s
    return y
def lpf(x, fc):
    k = 1 - np.exp(-2 * np.pi * fc / SR); 
    from numpy import zeros
    # fast vectorised-ish: use cumulative filter via lfilter-like loop in chunks
    return lp(x, k)
def hp(x, fc): return x - lpf(x, fc)
def norm(x, peak=0.8): m = np.max(np.abs(x)) + 1e-9; return x / m * peak
def save(path, x, stereo=False):
    x = np.clip(x, -1, 1); pcm = (x * 32767).astype("<i2")
    tmp = path + ".wav"
    with wave.open(tmp, "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg","-y","-loglevel","error","-i",tmp,"-c:a","libvorbis","-q:a","3",path],check=True); os.remove(tmp)
def pluck(freq, dur, decay=0.996, bright=0.5):
    n = int(SR * dur); N = max(2, int(SR / freq)); y = np.zeros(n)
    y[:N] = rng.uniform(-1, 1, N) * np.hanning(N) ** 0.3
    y[:N] = lp(y[:N], bright) if bright < 1 else y[:N]
    for i in range(N, n):  # simple KS
        y[i] = decay * 0.5 * (y[i - N] + y[i - N + 1 if i - N + 1 < i else i - N])
    return y
def thud(f0=95, f1=42, d=0.4):
    t = t_(d); ph = 2 * np.pi * np.cumsum(f1 + (f0 - f1) * np.exp(-t * 18)) / SR
    return np.sin(ph) * np.exp(-t * 9)
def noise_burst(d, fc, decay):
    n = int(SR * d); return lpf(rng.uniform(-1, 1, n), fc) * np.exp(-t_(d) * decay)

def sfx():
    o = ROOT + "/audio/sfx/"
    t = t_(0.1); save(o + "tap.ogg", norm(np.sin(2 * np.pi * 620 * t) * np.exp(-t * 55) + 0.4 * hp(rng.uniform(-1, 1, len(t)), 3000) * np.exp(-t * 80), 0.6))
    t = t_(0.2); x = np.sin(2 * np.pi * 523 * t) * np.exp(-t * 14) + 0.6 * np.sin(2 * np.pi * 784 * np.maximum(t - 0.07, 0)) * np.exp(-t * 14) * (t > 0.07); save(o + "select.ogg", norm(x, 0.6))
    # scroll pickup: bright sparkle arpeggio
    x = np.zeros(int(SR * 0.9))
    for i, fq in enumerate([659, 784, 988, 1319]):
        t = t_(0.7); s = (np.sin(2 * np.pi * fq * t) * np.exp(-t * 6) + 0.3 * np.sin(2 * np.pi * fq * 2 * t) * np.exp(-t * 10)); p = int(i * 0.07 * SR); x[p:p+len(s)] += s[:len(x)-p] * 0.5
    save(o + "pickup.ogg", norm(x, 0.65))
    # water pour / splash: filtered noise with bubbling modulation
    d = 0.5; t = t_(d); x = lpf(rng.uniform(-1, 1, len(t)), 3200) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t + 3 * np.sin(2 * np.pi * 7 * t))) * np.minimum(1, t / 0.03) * np.exp(-t * 4)
    x += 0.25 * lpf(rng.uniform(-1, 1, len(t)), 600) * np.exp(-t * 6); save(o + "pour.ogg", norm(x, 0.7))
    # waterpot full: low stone knock + soft chime
    x = thud(180, 90, 0.35) * 0.8; t = t_(0.8); c = np.sin(2 * np.pi * 784 * t) * np.exp(-t * 5) * 0.4 + np.sin(2 * np.pi * 1175 * t) * np.exp(-t * 7) * 0.25
    y = np.zeros(int(SR * 0.9)); y[:len(x)] += x; y[int(0.08 * SR):int(0.08 * SR) + len(c)] += c; save(o + "pot_full.ogg", norm(y, 0.7))
    # wine miracle: rising shimmer with warm pad and bell cluster
    d = 4.5; t = t_(d); x = np.zeros(len(t))
    for k, fq in enumerate([196, 294, 392, 494, 587, 784, 988]):
        a = np.clip((t - 0.25 * k) / 1.2, 0, 1) * np.exp(-np.maximum(t - 0.25 * k, 0) * 0.55)
        x += np.sin(2 * np.pi * fq * t + 0.4 * np.sin(2 * np.pi * 5 * t)) * a * (0.5 / (1 + k * 0.35))
    sw = hp(rng.uniform(-1, 1, len(t)), 3000) * np.sin(np.pi * t / d) ** 2 * 0.12
    save(o + "wine_miracle.ogg", norm(x + sw, 0.75))
    # cheer / gasp murmur: band-limited noise bursts
    d = 2.2; t = t_(d); x = hp(lpf(rng.uniform(-1, 1, len(t)), 2400), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 5.5 * t)) * np.sin(np.pi * t / d) ** 0.7
    save(o + "crowd_cheer.ogg", norm(x, 0.55))
    # murmur loop
    d = 8.0; t = t_(d); x = hp(lpf(rng.uniform(-1, 1, len(t)), 1500), 200) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.1 * t + np.sin(2 * np.pi * 0.37 * t) * 3)) * 0.8
    f = int(0.3 * SR); x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f); save(o + "crowd_murmur.ogg", norm(x, 0.4))
    # chapter-complete sting
    x = np.zeros(int(SR * 2.0))
    for i, fq in enumerate([294, 370, 440, 587]): s = pluck(fq, 1.2, 0.997, 0.6); p = int(i * 0.18 * SR); x[p:p+len(s)] += s[:len(x)-p]
    save(o + "complete.ogg", norm(x, 0.7))
# --- music: Phrygian-dominant on D, oud-like plucks + darbuka frame-drum pattern
D = 146.83
SCALE = [0, 1, 4, 5, 7, 8, 10]  # D Eb F# G A Bb C
def note(deg, octv=0): 
    o, d = divmod(deg, 7); return D * 2 ** ((SCALE[d] + 12 * (o + octv)) / 12)
def darbuka(kind):
    if kind == "D": x = thud(150, 70, 0.35) * 1.0 + noise_burst(0.35, 400, 20) * 0.1
    elif kind == "T": 
        t = t_(0.12); x = hp(rng.uniform(-1, 1, len(t)), 2500) * np.exp(-t * 45) * 0.6 + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 60) * 0.4
    else:
        t = t_(0.09); x = hp(rng.uniform(-1, 1, len(t)), 1800) * np.exp(-t * 60) * 0.35
    return x
def track(name, bpm, bars, melody, drums, drone=True, vol=0.8):
    beat = 60 / bpm; step = beat / 2; n = int(SR * (bars * 8 * step + 1.0)); mix = np.zeros(n)
    # drums: pattern of 8 steps per bar
    for b in range(bars):
        for s, k in enumerate(drums):
            if k != "-":
                p = int(((b * 8 + s) * step) * SR); d = darbuka(k) * (0.9 if k == "D" else 0.7); mix[p:p + len(d)] += d[:n - p]
    # melody: list of (step, deg, octave, dur_steps)
    for st, deg, oc, ds in melody:
        p = int(st * step * SR); s = pluck(note(deg, oc), max(0.4, ds * step + 0.4), 0.9965, 0.55) * 0.55; mix[p:p + len(s)] += s[:n - p]
    if drone:
        t = np.arange(n) / SR; dr = np.sin(2 * np.pi * D / 2 * t) * 0.10 + np.sin(2 * np.pi * D * t) * 0.05
        mix += dr
    loop_len = int(SR * bars * 8 * step)
    out = mix[:loop_len].copy(); tail = mix[loop_len:]; out[:len(tail)] += tail  # wrap tail for seamless loop
    save(ROOT + f"/audio/music/{name}.ogg", norm(out, vol))
def pad(name, dur=16.0, vol=0.6):
    """Quiet warm pad for the miracle: slow drifting sines on D, loopable."""
    t = t_(dur); x = np.zeros(len(t))
    for k, (fq, a) in enumerate([(73.4, .5), (110, .35), (146.8, .3), (185, .2), (220, .22), (293.7, .12)]):
        ph = 2 * np.pi * fq * t + 0.5 * np.sin(2 * np.pi * (0.07 + 0.03 * k) * t); x += np.sin(ph) * a * (0.75 + 0.25 * np.sin(2 * np.pi * (1 / dur) * (k + 1) * t))
    save(ROOT + f"/audio/music/{name}.ogg", norm(x, vol))
def music():
    mel = []
    p1 = [(0,0,1,2),(2,1,1,1),(3,2,1,1),(4,3,1,2),(6,2,1,1),(7,1,1,1)]
    p2 = [(0,2,1,2),(2,3,1,1),(3,4,1,2),(5,3,1,1),(6,2,1,1),(7,1,1,1)]
    p3 = [(0,4,1,1),(1,5,1,1),(2,4,1,1),(3,3,1,1),(4,2,1,2),(6,1,1,1),(7,0,1,1)]
    p4 = [(0,0,1,4),(4,-1,1,2),(6,0,1,2)]
    for bar, ph in enumerate([p1, p2, p1, p2, p3, p2, p3, p4]):
        for s, dg, oc, ds in ph: mel.append((bar * 8 + s, dg, oc, ds))
    track("village", 84, 8, mel, "D-T-D-T-", vol=0.7)
    mel = []
    r1 = [(0,0,1,1),(1,2,1,1),(2,3,1,2),(4,4,1,1),(5,3,1,1),(6,2,1,2)]
    r2 = [(0,4,1,1),(1,5,1,1),(2,4,1,2),(4,3,1,1),(5,2,1,1),(6,1,1,1),(7,0,1,1)]
    for bar, ph in enumerate([r1, r1, r2, r2, r1, r2, r2, p4]):
        for s, dg, oc, ds in ph: mel.append((bar * 8 + s, dg, oc, ds))
    track("road", 100, 8, mel, "D-TkD-T-", vol=0.7)
    mel = []
    f1 = [(0,4,1,1),(1,5,1,1),(2,4,1,1),(3,3,1,1),(4,4,1,1),(5,3,1,1),(6,2,1,1),(7,3,1,1)]
    f2 = [(0,2,2,1),(1,3,2,1),(2,2,2,1),(3,1,2,1),(4,2,1,2),(6,1,1,1),(7,0,1,1)]
    for bar, ph in enumerate([f1, f1, f2, f2, f1, f2, f1, p4]):
        for s, dg, oc, ds in ph: mel.append((bar * 8 + s, dg, oc, ds))
    track("feast", 128, 8, mel, "DkTDkTDT", vol=0.75)
    pad("wonder")
if __name__ == "__main__":
    for d in ["sfx", "music"]: os.makedirs(ROOT + "/audio/" + d, exist_ok=True)
    sfx(); music(); print("audio done")
