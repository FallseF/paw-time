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


write("splash", splash())
write("lift", lift())
write("chime", chime())
write("tear", tear())
write("hatch", hatch())
write("sparkle", sparkle())
write("river_loop", river_loop())
print("wrote sfx to", OUT)


# ---- Variant A で足した音 ----

def bubble():
    n = int(SR * 1.2)
    out = [0.0] * n
    for k in range(9):
        s = int(SR * (k * 0.11 + random.uniform(0, 0.04)))
        f0 = random.uniform(500, 900)
        for j in range(int(SR * 0.09)):
            if s + j < n:
                f = f0 + j * 12
                out[s + j] += 0.5 * math.sin(2 * math.pi * f * j / SR) * math.exp(-j / (SR * 0.025))
    return out


def pop():
    n = int(SR * 0.12)
    return [math.sin(2 * math.pi * (600 + i * 18) * i / SR) * math.exp(-i / (SR * 0.02)) for i in range(n)]


def thunder():
    n = int(SR * 2.2)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    f = lowpass(noise, 0.02)
    out = []
    for i in range(n):
        crack = random.uniform(-1, 1) * math.exp(-i / (SR * 0.05)) * 0.8
        rumble = f[i] * 6 * math.exp(-i / (SR * 0.9)) * (0.6 + 0.4 * math.sin(i / SR * 13))
        out.append(crack + rumble)
    return out


def combo():
    n = int(SR * 0.35)
    out = [0.0] * n
    for k, fr in enumerate([1568.0, 2093.0]):
        s = int(SR * k * 0.06)
        for j in range(n - s):
            out[s + j] += math.sin(2 * math.pi * fr * j / SR) * math.exp(-j / (SR * 0.08))
    return out


def fanfare():
    n = int(SR * 1.8)
    out = [0.0] * n
    seq = [(0.0, 784), (0.12, 988), (0.24, 1175), (0.36, 1568), (0.36, 1175), (0.36, 988)]
    for t0, fr in seq:
        s = int(SR * t0)
        for j in range(n - s):
            e = math.exp(-j / (SR * (0.25 if t0 < 0.3 else 0.8)))
            out[s + j] += e * (math.sin(2 * math.pi * fr * j / SR) + 0.25 * math.sin(2 * math.pi * fr * 3 * j / SR))
    return out


def levelup():
    n = int(SR * 1.0)
    out = [0.0] * n
    for k, fr in enumerate([523, 659, 784, 1046, 1318]):
        s = int(SR * k * 0.07)
        for j in range(n - s):
            out[s + j] += 0.6 * math.exp(-j / (SR * 0.3)) * math.sin(2 * math.pi * fr * j / SR)
    return out


def craft():
    n = int(SR * 0.9)
    out = [0.0] * n
    for k in range(3):
        s = int(SR * k * 0.13)
        for j in range(int(SR * 0.1)):
            if s + j < n:
                out[s + j] += random.uniform(-1, 1) * math.exp(-j / (SR * 0.012)) * 0.7
    for j in range(n - int(SR * 0.4)):
        s = int(SR * 0.4)
        out[s + j] += 0.6 * math.exp(-j / (SR * 0.3)) * (math.sin(2 * math.pi * 1318 * j / SR) + 0.5 * math.sin(2 * math.pi * 1976 * j / SR))
    return out


def festival_loop():
    # 太鼓と笛（ペンタトニック）の、ゆるい祭りばやし 4 小節
    bpm = 104
    beat = 60.0 / bpm
    n = int(SR * beat * 16)
    out = [0.0] * n
    def drum(t, f0, amp, dec):
        s = int(SR * t)
        for j in range(int(SR * 0.5)):
            if s + j < n:
                f = f0 * (1 + 0.6 * math.exp(-j / (SR * 0.02)))
                out[s + j] += amp * math.sin(2 * math.pi * f * j / SR) * math.exp(-j / (SR * dec))
    for b in range(16):
        drum(b * beat, 70, 0.9 if b % 4 == 0 else 0.5, 0.18)
        if b % 2 == 1:
            drum(b * beat + beat * 0.5, 180, 0.25, 0.05)
    scale = [587, 659, 784, 880, 988, 1175]
    rnd = random.Random(8)
    melody = [rnd.choice(scale) for _ in range(16)]
    for b, fr in enumerate(melody):
        s = int(SR * b * beat)
        ln = int(SR * beat * 0.95)
        for j in range(ln):
            if s + j < n:
                vib = 1 + 0.006 * math.sin(2 * math.pi * 5.5 * j / SR)
                e = min(1.0, j / (SR * 0.03)) * math.exp(-j / (SR * 0.9))
                out[s + j] += 0.22 * e * (math.sin(2 * math.pi * fr * vib * j / SR) + 0.3 * math.sin(4 * math.pi * fr * vib * j / SR))
    return out


def room_loop():
    # 休憩室のオルゴール：ゆっくりしたペンタトニックの分散和音 8 小節
    bpm = 84
    beat = 60.0 / bpm
    n = int(SR * beat * 32)
    out = [0.0] * n
    chords = [[523, 659, 784], [440, 523, 659], [392, 494, 587], [440, 523, 659]]
    rnd = random.Random(21)
    for bar in range(8):
        ch = chords[bar % 4]
        for k in range(4):
            fr = ch[k % 3] * (2 if k == 3 else 1)
            s = int(SR * (bar * 4 + k) * beat)
            for j in range(int(SR * 1.6)):
                if s + j < n:
                    e = math.exp(-j / (SR * 0.5))
                    out[s + j] += 0.3 * e * (math.sin(2 * math.pi * fr * j / SR) + 0.2 * math.sin(2 * math.pi * fr * 2.76 * j / SR))
        # 低い音
        s = int(SR * bar * 4 * beat)
        for j in range(int(SR * beat * 4)):
            if s + j < n:
                out[s + j] += 0.18 * math.exp(-j / (SR * 1.2)) * math.sin(2 * math.pi * ch[0] / 2 * j / SR)
    return out


def swish_loop():
    # 水の中でポイを動かす音（ループ）：やわらかいノイズを帯域で絞る
    n = int(SR * 2.0)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    a = lowpass(noise, 0.08)
    b = lowpass(a, 0.3)
    out = [(a[i] - b[i] * 0.6) * (0.8 + 0.2 * math.sin(2 * math.pi * 3 * i / SR)) for i in range(n)]
    fade = int(SR * 0.2)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    return out[: n - fade]


write("swish_loop", swish_loop())
write("room_loop", room_loop())
write("bubble", bubble())
write("pop", pop())
write("thunder", thunder())
write("combo", combo())
write("fanfare", fanfare())
write("levelup", levelup())
write("craft", craft())
write("festival_loop", festival_loop())
print("wrote variant A sfx")
