"""効果音を合成して assets/sfx に WAV で出す。python3 tools/gen_sfx.py"""

import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100
random.seed(3)


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.85 / peak
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def env(i, n, attack=0.01, release=0.5):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = max(0.0, 1.0 - i / n) ** (1.0 / max(release, 1e-3))
    return a * r


def lowpass(xs, alpha):
    y = 0.0
    out = []
    for x in xs:
        y += alpha * (x - y)
        out.append(y)
    return out


def splash():
    n = int(SR * 0.6)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    f = lowpass(noise, 0.25)
    out = [f[i] * env(i, n, 0.003, 0.25) for i in range(n)]
    # 小さな水滴
    for k in range(6):
        start = int(SR * random.uniform(0.08, 0.45))
        freq = random.uniform(900, 1600)
        for j in range(int(SR * 0.06)):
            if start + j < n:
                out[start + j] += 0.35 * math.sin(2 * math.pi * (freq + j * 8) * j / SR) * math.exp(-j / (SR * 0.015))
    return out


def lift():
    n = int(SR * 0.5)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    out = []
    y = 0.0
    for i, x in enumerate(noise):
        a = 0.02 + 0.3 * (i / n)
        y += a * (x - y)
        out.append(y * math.sin(math.pi * i / n))
    return out


def chime():
    n = int(SR * 1.6)
    notes = [(0.0, 1046.5), (0.09, 1318.5), (0.18, 1568.0), (0.27, 2093.0)]
    out = [0.0] * n
    for t0, f in notes:
        s = int(SR * t0)
        for j in range(n - s):
            e = math.exp(-j / (SR * 0.45))
            out[s + j] += e * (math.sin(2 * math.pi * f * j / SR) + 0.3 * math.sin(2 * math.pi * f * 2.01 * j / SR))
    return out


def tear():
    n = int(SR * 0.45)
    out = []
    for i in range(n):
        crackle = random.uniform(-1, 1) if random.random() < 0.25 else 0.0
        out.append(crackle * env(i, n, 0.001, 0.6))
    return lowpass(out, 0.6)


def hatch():
    n = int(SR * 1.2)
    out = [0.0] * n
    # 殻が割れる音 + きらめき
    for i in range(int(SR * 0.08)):
        out[i] += random.uniform(-1, 1) * math.exp(-i / (SR * 0.02))
    for k, f in enumerate([784, 988, 1175, 1568, 1976]):
        s = int(SR * (0.1 + k * 0.06))
        for j in range(n - s):
            out[s + j] += 0.5 * math.exp(-j / (SR * 0.35)) * math.sin(2 * math.pi * f * j / SR)
    return out


def sparkle():
    n = int(SR * 1.0)
    out = [0.0] * n
    for k in range(14):
        s = int(SR * random.uniform(0, 0.7))
        f = random.uniform(2400, 4200)
        for j in range(int(SR * 0.25)):
            if s + j < n:
                out[s + j] += 0.4 * math.exp(-j / (SR * 0.06)) * math.sin(2 * math.pi * f * j / SR)
    return out


def river_loop():
    n = int(SR * 6.0)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    f = lowpass(noise, 0.04)
    out = [x * 0.6 for x in f]
    # 虫の声とたまの水音
    for k in range(10):
        s = int(SR * random.uniform(0, 5.5))
        freq = random.uniform(3800, 4600)
        for j in range(int(SR * 0.3)):
            if s + j < n:
                am = 0.5 + 0.5 * math.sin(2 * math.pi * 30 * j / SR)
                out[s + j] += 0.05 * am * math.sin(2 * math.pi * freq * j / SR) * math.sin(math.pi * j / (SR * 0.3))
    # つなぎ目をなめらかに
    fade = int(SR * 0.3)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


def tone(f, dur, decay, harm=(1.0, 0.3), amp=1.0):
    n = int(SR * dur)
    return [amp * math.exp(-i / (SR * decay)) * sum(h * math.sin(2 * math.pi * f * (k + 1) * 1.0005 ** k * i / SR) for k, h in enumerate(harm)) for i in range(n)]


def mix(dst, src, at):
    s = int(SR * at)
    for i, x in enumerate(src):
        if s + i < len(dst):
            dst[s + i] += x


def tap():
    out = tone(1400, 0.08, 0.012, (1.0, 0.2))
    return out


def pop():
    n = int(SR * 0.18)
    return [math.sin(2 * math.pi * (500 + 900 * (i / n)) * i / SR) * math.exp(-i / (SR * 0.04)) for i in range(n)]


def grow():
    out = [0.0] * int(SR * 1.4)
    for k, f in enumerate([523.3, 659.3, 784.0, 1046.5, 1318.5]):
        mix(out, tone(f, 1.0, 0.35, (1.0, 0.25, 0.1)), k * 0.08)
    return out


def bell():
    out = [0.0] * int(SR * 1.8)
    mix(out, tone(880, 1.8, 0.6, (1.0, 0.0, 0.4, 0.0, 0.15)), 0)
    mix(out, tone(1320, 1.2, 0.4, (0.4,)), 0.0)
    return out


def night():
    out = [0.0] * int(SR * 2.4)
    for k, f in enumerate([392.0, 329.6, 261.6]):
        mix(out, tone(f, 1.8, 0.7, (1.0, 0.15)), k * 0.35)
    return out


def dream():
    out = [0.0] * int(SR * 3.0)
    for k, f in enumerate([523.3, 659.3, 784.0, 987.8, 784.0, 659.3]):
        mix(out, tone(f, 1.6, 0.5, (1.0, 0.1, 0.25)), k * 0.22)
    return out


def lullaby():
    """オルゴールの子守歌（ループ用、8小節）"""
    bpm = 84
    beat = 60 / bpm
    melody = [(67, 1), (64, 0.5), (65, 0.5), (67, 1), (72, 1), (69, 1), (67, 1), (64, 2),
              (65, 1), (62, 0.5), (64, 0.5), (65, 1), (69, 1), (67, 1.5), (65, 0.5), (64, 2),
              (67, 1), (64, 0.5), (65, 0.5), (67, 1), (72, 1), (74, 1), (72, 1), (69, 2),
              (67, 1), (65, 1), (64, 1), (62, 1), (60, 4)]
    total = sum(d for _, d in melody) * beat
    out = [0.0] * int(SR * total)
    t = 0.0
    for m, d in melody:
        f = 440 * 2 ** ((m - 69) / 12)
        mix(out, tone(f, min(2.5, d * beat + 1.2), 0.45, (1.0, 0.0, 0.3, 0.0, 0.08), 0.6), t)
        t += d * beat
    bass = [48, 53, 55, 48, 53, 55, 53, 48]
    for i, m in enumerate(bass):
        f = 440 * 2 ** ((m - 69) / 12)
        for b in range(4):
            mix(out, tone(f * (1.5 if b % 2 else 1.0), 1.0, 0.3, (1.0, 0.2), 0.25), (i * 4 + b) * beat)
    return out


write("splash", splash())
write("lift", lift())
write("chime", chime())
write("tear", tear())
write("hatch", hatch())
write("sparkle", sparkle())
write("river_loop", river_loop())
for name, fn in [("tap", tap), ("pop", pop), ("grow", grow), ("bell", bell), ("night", night), ("dream", dream), ("lullaby", lullaby)]:
    write(name, fn())
print("wrote sfx to", OUT)
