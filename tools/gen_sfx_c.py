"""大ピーク防衛（C案）の効果音と戦いの曲を合成して assets/sfx に WAV で出す。python3 tools/gen_sfx_c.py"""

import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100
random.seed(5)


def write(name, samples, peak_to=0.85):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = peak_to / peak
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


def square(f, t):
    return 1.0 if (f * t) % 1.0 < 0.5 else -1.0


def tri(f, t):
    p = (f * t) % 1.0
    return 4 * abs(p - 0.5) - 1


def lowpass(xs, alpha):
    y = 0.0
    out = []
    for x in xs:
        y += alpha * (x - y)
        out.append(y)
    return out


def pop():
    # 出撃：ぽこっ
    n = int(SR * 0.18)
    out = []
    for i in range(n):
        t = i / SR
        f = 380 + 900 * math.exp(-t * 30)
        out.append(sine(f, t) * math.exp(-t * 22))
    return out


def hit():
    # 軽い打撃：ぽす
    n = int(SR * 0.12)
    out = []
    for i in range(n):
        t = i / SR
        out.append((0.6 * random.uniform(-1, 1) + sine(160 - 400 * t, t)) * math.exp(-t * 40))
    return lowpass(out, 0.35)


def heavy():
    # 重い一撃：どすん
    n = int(SR * 0.35)
    out = []
    for i in range(n):
        t = i / SR
        out.append((0.5 * random.uniform(-1, 1) * math.exp(-t * 30) + sine(90 - 120 * t, t) * math.exp(-t * 9)))
    return lowpass(out, 0.25)


def zap():
    # 雷：ばりっ
    n = int(SR * 0.5)
    out = []
    for i in range(n):
        t = i / SR
        crack = random.uniform(-1, 1) * (1.0 if random.random() < 0.6 else 0.2)
        out.append((crack * 0.8 + 0.4 * square(60 + 30 * math.sin(t * 90), t)) * math.exp(-t * 7))
    return out


def bell():
    # 休憩のチャイム（キンコンカンコン）
    notes = [659.3, 523.3, 587.3, 392.0]
    n = int(SR * 2.2)
    out = [0.0] * n
    for k, f in enumerate(notes):
        s = int(SR * k * 0.36)
        for j in range(n - s):
            t = j / SR
            e = math.exp(-t * 2.2)
            out[s + j] += e * (sine(f, t) + 0.35 * sine(f * 2.76, t) * math.exp(-t * 6) + 0.2 * sine(f * 5.4, t) * math.exp(-t * 12))
    return out


def whoosh():
    n = int(SR * 0.4)
    out = []
    y = 0.0
    for i in range(n):
        a = 0.02 + 0.25 * math.sin(math.pi * i / n)
        y += a * (random.uniform(-1, 1) - y)
        out.append(y * math.sin(math.pi * i / n))
    return out


def coin():
    n = int(SR * 0.28)
    out = []
    for i in range(n):
        t = i / SR
        f = 1318.5 if t < 0.06 else 1760.0
        out.append(square(f, t) * 0.4 * math.exp(-t * 12))
    return lowpass(out, 0.5)


def drum():
    # 大ピーク来店：どどん
    n = int(SR * 1.4)
    out = [0.0] * n
    for s0 in [0.0, 0.22, 0.44]:
        s = int(SR * s0)
        for j in range(n - s):
            t = j / SR
            out[s + j] += sine(70 - 30 * t, t) * math.exp(-t * 5) + 0.3 * random.uniform(-1, 1) * math.exp(-t * 25)
    return lowpass(out, 0.3)


def fanfare():
    seq = [(0.0, 523.3, 0.14), (0.15, 659.3, 0.14), (0.3, 784.0, 0.14), (0.45, 1046.5, 0.6), (0.45, 784.0, 0.6), (0.45, 659.3, 0.6)]
    n = int(SR * 1.3)
    out = [0.0] * n
    for s0, f, d in seq:
        s = int(SR * s0)
        for j in range(int(SR * (d + 0.3))):
            if s + j >= n:
                break
            t = j / SR
            e = min(1.0, t / 0.01) * (1.0 if t < d else math.exp(-(t - d) * 10))
            out[s + j] += 0.5 * e * (tri(f, t) + 0.3 * square(f, t) * 0.5)
    return out


def lose():
    seq = [(0.0, 392.0), (0.3, 370.0), (0.6, 349.2), (0.9, 293.7)]
    n = int(SR * 1.8)
    out = [0.0] * n
    for s0, f in seq:
        s = int(SR * s0)
        for j in range(int(SR * 0.8)):
            if s + j >= n:
                break
            t = j / SR
            out[s + j] += 0.5 * math.exp(-t * 3) * tri(f * (1 - 0.03 * t), t)
    return out


def crash():
    # 店が叩かれた
    n = int(SR * 0.45)
    out = []
    for i in range(n):
        t = i / SR
        out.append(random.uniform(-1, 1) * math.exp(-t * 10) + 0.5 * sine(110, t) * math.exp(-t * 14))
    return lowpass(out, 0.5)


def levelup():
    n = int(SR * 0.5)
    out = []
    for i in range(n):
        t = i / SR
        f = 523.3 * (2 ** (int(t / 0.07) * 4 / 12))
        out.append(square(f, t) * 0.35 * math.exp(-t * 4))
    return lowpass(out, 0.45)


def tap():
    n = int(SR * 0.06)
    return [sine(1200, i / SR) * math.exp(-i / SR * 70) for i in range(n)]


def deny():
    n = int(SR * 0.16)
    return [square(180, i / SR) * 0.4 * math.exp(-i / SR * 14) for i in range(n)]


def battle_loop():
    # 大ピークの曲：軽快な 4 小節ループ（BPM 132）
    bpm = 132
    beat = 60 / bpm
    bars = 4
    n = int(SR * beat * 4 * bars)
    out = [0.0] * n
    bass = [130.8, 130.8, 174.6, 196.0]  # C C F G
    chords = [[261.6, 329.6, 392.0], [261.6, 329.6, 392.0], [349.2, 440.0, 523.3], [392.0, 493.9, 587.3]]
    mel = [784, 0, 659, 784, 880, 784, 659, 0, 698, 0, 659, 587, 523, 587, 659, 0,
           784, 0, 659, 784, 880, 1046, 880, 0, 784, 698, 659, 587, 523, 0, 523, 0]
    for b in range(bars):
        for k in range(8):
            s = int(SR * (b * 4 + k * 0.5) * beat)
            f = bass[b] * (1 if k % 2 == 0 else 2)
            for j in range(int(SR * beat * 0.45)):
                if s + j < n:
                    t = j / SR
                    out[s + j] += 0.32 * tri(f, t) * math.exp(-t * 6)
        # 裏拍のコード
        for k in range(4):
            s = int(SR * (b * 4 + k + 0.5) * beat)
            for j in range(int(SR * beat * 0.25)):
                if s + j < n:
                    t = j / SR
                    for f in chords[b]:
                        out[s + j] += 0.07 * square(f, t) * math.exp(-t * 18)
        # ドラム
        for k in range(4):
            s = int(SR * (b * 4 + k) * beat)
            for j in range(int(SR * 0.15)):
                if s + j < n:
                    t = j / SR
                    if k % 2 == 0:
                        out[s + j] += 0.5 * sine(60 - 80 * t, t) * math.exp(-t * 25)
                    else:
                        out[s + j] += 0.25 * random.uniform(-1, 1) * math.exp(-t * 30)
            s2 = int(SR * (b * 4 + k + 0.5) * beat)
            for j in range(int(SR * 0.04)):
                if s2 + j < n:
                    out[s2 + j] += 0.08 * random.uniform(-1, 1) * math.exp(-j / SR * 80)
    # メロディ（8分）
    for i, f in enumerate(mel):
        if f == 0:
            continue
        s = int(SR * i * 0.5 * beat)
        for j in range(int(SR * beat * 0.42)):
            if s + j < n:
                t = j / SR
                out[s + j] += 0.16 * (square(f, t) * 0.5 + tri(f, t)) * min(1, t / 0.005) * math.exp(-t * 5)
    return lowpass(out, 0.55)


def calm_loop():
    # 休憩室と地図の曲：ゆったり（BPM 84）
    bpm = 84
    beat = 60 / bpm
    bars = 4
    n = int(SR * beat * 4 * bars)
    out = [0.0] * n
    chords = [[261.6, 329.6, 392.0], [220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7]]
    mel = [659, 0, 587, 523, 587, 0, 659, 0, 523, 0, 440, 0, 392, 0, 0, 0,
           440, 0, 523, 587, 659, 0, 587, 0, 523, 0, 587, 0, 523, 0, 0, 0]
    for b in range(bars):
        for k in range(8):
            s = int(SR * (b * 4 + k * 0.5) * beat)
            f = chords[b][k % 3]
            for j in range(int(SR * beat * 0.9)):
                if s + j < n:
                    t = j / SR
                    out[s + j] += 0.12 * sine(f, t) * math.exp(-t * 3)
    for i, f in enumerate(mel):
        if f == 0:
            continue
        s = int(SR * i * 0.5 * beat)
        for j in range(int(SR * beat * 0.9)):
            if s + j < n:
                t = j / SR
                out[s + j] += 0.2 * (sine(f, t) + 0.3 * sine(f * 2, t)) * min(1, t / 0.01) * math.exp(-t * 3)
    return out


write("c_pop", pop())
write("c_hit", hit(), 0.6)
write("c_heavy", heavy())
write("c_zap", zap())
write("c_bell", bell())
write("c_whoosh", whoosh(), 0.6)
write("c_coin", coin(), 0.5)
write("c_drum", drum())
write("c_fanfare", fanfare())
write("c_lose", lose())
write("c_crash", crash(), 0.7)
write("c_levelup", levelup(), 0.6)
write("c_tap", tap(), 0.5)
write("c_deny", deny(), 0.5)
write("c_battle_loop", battle_loop(), 0.6)
write("c_calm_loop", calm_loop(), 0.5)
print("wrote C sfx to", OUT)
