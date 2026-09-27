"""効果音を合成して assets/sfx に WAV で出す（やわらかい木琴・カリンバ・泡の音でそろえる）。

    uv run --with numpy --with scipy python3 tools/gen_sfx.py            # 全部つくる
    uv run --with numpy --with scipy python3 tools/gen_sfx.py --report   # つくらずに、いまの WAV の大きさと高い音の量を出す

- 音ごとに乱数の種を分けているので、どれか 1 つを変えても、ほかの音は同じバイト列のまま。
- 大きさは BS.1770 の K 特性で測った「瞬間の最大ラウドネス（M, 400 ms）」でそろえる。
  BGM は -16 LUFS（music.gd の db とつまみで、画面では -22〜-26 くらい）。UI の音はその少し下（-25〜-22）、ごほうびは少し上。
- UI の音は 7 kHz より上を切る（高いキーンという音を出さない）。ループ（川・夜の水辺）は 16〜22 kHz で小さく作る。
- 鳴らす側の名前（Kit.play の name）は scripts/sfx.gd の一覧を見る。
"""

import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
SR = 44100


# ---------------------------------------------------------------- 測る（BS.1770 の K 特性）

def _k_filters(sr):
    # 高域のシェルフ
    g, q, fc = 3.99984385397, 0.7071752369554193, 1681.9744509555319
    a_ = 10 ** (g / 40)
    w0 = 2 * np.pi * fc / sr
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    b1 = [a_ * ((a_ + 1) + (a_ - 1) * c + 2 * np.sqrt(a_) * al), -2 * a_ * ((a_ - 1) + (a_ + 1) * c), a_ * ((a_ + 1) + (a_ - 1) * c - 2 * np.sqrt(a_) * al)]
    a1 = [(a_ + 1) - (a_ - 1) * c + 2 * np.sqrt(a_) * al, 2 * ((a_ - 1) - (a_ + 1) * c), (a_ + 1) - (a_ - 1) * c - 2 * np.sqrt(a_) * al]
    # 低域を切る
    q, fc = 0.5003270373253953, 38.13547087613982
    w0 = 2 * np.pi * fc / sr
    al = np.sin(w0) / (2 * q)
    b2 = [1.0, -2.0, 1.0]
    a2 = [1 + al, -2 * np.cos(w0), 1 - al]
    return (b1, a1), (b2, a2)


def _kw(x, sr):
    (b1, a1), (b2, a2) = _k_filters(sr)
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x))


def lufs_m_max(x, sr=SR):
    """瞬間（400 ms）ラウドネスの最大"""
    w = int(0.4 * sr)
    y = _kw(np.concatenate([x, np.zeros(w)]), sr) ** 2
    c = np.concatenate([[0.0], np.cumsum(y)])
    ms = (c[w:] - c[:-w]) / w
    return -0.691 + 10 * np.log10(max(ms.max(), 1e-12))


def lufs_i(x, sr=SR):
    """ループ用：全体の平均（ゲートなしの簡易版。静かなループなので十分）"""
    return -0.691 + 10 * np.log10(max(np.mean(_kw(x, sr) ** 2), 1e-12))


def true_peak_db(x):
    return 20 * np.log10(max(np.abs(signal.resample_poly(x, 4, 1)).max(), 1e-9))


def above_db(x, sr, hz=8000.0):
    """hz より上のエネルギーが全体の何 dB 下か"""
    f, p = signal.welch(x, sr, nperseg=min(2048, len(x)))
    hi = p[f >= hz].sum() if (f >= hz).any() else 0.0
    return 10 * np.log10(max(hi, 1e-20) / max(p.sum(), 1e-20))


# ---------------------------------------------------------------- 部品

def tt(dur, sr=SR):
    return np.arange(int(sr * dur)) / sr


def env(t, attack, tau):
    """やわらかい立ち上がり（半分の余弦）＋指数の減衰"""
    a = np.where(t < attack, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(attack, 1e-6), 0, 1)), 1.0)
    return a * np.exp(-np.maximum(t - attack, 0) / tau)


def fade_end(x, sec=0.015, sr=SR):
    """おしまいを半分の余弦で消す（途中で切れて「ぷつっ」と鳴らないように）"""
    n = min(len(x), int(sec * sr))
    if n > 1:
        x = x.copy()
        x[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


def mallet(f, dur, tau, partials, attack=0.004, rng=None, thock=0.0):
    """板や棒をやわらかいバチでたたいた音。partials = [(倍率, 大きさ, 減衰の倍率)]"""
    t = tt(dur)
    out = np.zeros_like(t)
    for ratio, amp, tr in partials:
        fr = f * ratio
        if fr > 7000:
            continue
        out += amp * np.sin(2 * np.pi * fr * t) * env(t, attack, tau * tr)
    if thock > 0 and rng is not None:
        # バチが当たる「ことっ」。低めの帯域だけ
        n = rng.standard_normal(len(t))
        sos = signal.butter(4, [max(80, f * 0.5), min(1600, f * 2.0)], "bandpass", fs=SR, output="sos")
        out += thock * signal.sosfilt(sos, n) * env(t, 0.002, 0.008)
    return fade_end(out, min(0.04, dur * 0.3))


def marimba(f, dur=0.35, tau=0.09, bright=1.0, rng=None, thock=0.25):
    return mallet(f, dur, tau, [(1.0, 1.0, 1.0), (3.93, 0.22 * bright, 0.28), (9.2, 0.05 * bright, 0.1)], 0.003, rng, thock)


def kalimba(f, dur=0.6, tau=0.22, bright=1.0, rng=None, thock=0.15):
    return mallet(f, dur, tau, [(1.0, 1.0, 1.0), (2.0, 0.06, 0.6), (5.93, 0.12 * bright, 0.18)], 0.0025, rng, thock)


def felt(f, dur=0.3, tau=0.08, rng=None):
    """フェルトのバチ（まるい・低め）"""
    return mallet(f, dur, tau, [(1.0, 1.0, 1.0), (2.76, 0.08, 0.3)], 0.006, rng, 0.12)


def bell_fm(f, dur=1.2, tau=0.45, index=1.4, ratio=3.5):
    """やさしい鐘（FM を小さく）"""
    t = tt(dur)
    e = env(t, 0.004, tau)
    mod = index * np.exp(-t / (tau * 0.4)) * np.sin(2 * np.pi * f * ratio * t)
    return fade_end(e * np.sin(2 * np.pi * f * t + mod), 0.05)


def bubble(f0, f1, dur, tau, attack=0.004):
    """泡：音の高さがすっと動く正弦波"""
    t = tt(dur)
    fr = f0 * (f1 / f0) ** np.clip(t / dur, 0, 1)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    return fade_end(np.sin(ph) * env(t, attack, tau), min(0.03, dur * 0.3))


def band_noise(rng, dur, lo, hi, sr=SR, order=2):
    n = rng.standard_normal(int(sr * dur))
    sos = signal.butter(order, [lo, hi], "bandpass", fs=sr, output="sos")
    return signal.sosfilt(sos, n)


def at(dst, src, sec, gain=1.0, sr=SR):
    s = int(sr * sec)
    e = min(len(dst), s + len(src))
    if e > s:
        dst[s:e] += gain * fade_end(src[: e - s], 0.02, sr)
    return dst


def room(x, rng, wet=0.12, rt=0.35, lp=3500, sr=SR):
    """小さな部屋の響き（減衰する雑音をたたみこむ）"""
    t = tt(rt, sr)
    ir = rng.standard_normal(len(t)) * np.exp(-6.9 * t / rt)
    ir = signal.sosfilt(signal.butter(2, lp, fs=sr, output="sos"), ir)
    ir[: int(0.006 * sr)] = 0.0 # 直接音のすぐ後は空ける（にごらないように）
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.concatenate([x, np.zeros(len(t))])
    return y + wet * signal.fftconvolve(y, ir)[: len(y)]


def finish(x, target, lp=7000, hp=90, peak_db=-3.0, sr=SR):
    """仕上げ：帯域を整え、しっぽを切り、M の最大を target にそろえる"""
    x = np.asarray(x, dtype=np.float64)
    if lp:
        x = signal.sosfilt(signal.butter(4, lp, fs=sr, output="sos"), x)
    if hp:
        x = signal.sosfilt(signal.butter(2, hp, "highpass", fs=sr, output="sos"), x)
    # -70 dB より小さいしっぽを落とし、最後は 8 ms で消す
    a = np.abs(x) / max(np.abs(x).max(), 1e-12)
    idx = np.nonzero(a > 10 ** (-70 / 20))[0]
    x = x[: (idx[-1] + 1) if len(idx) else len(x)]
    f = min(len(x), int(0.008 * sr))
    x[-f:] *= np.linspace(1, 0, f)
    x *= 10 ** ((target - lufs_m_max(x, sr)) / 20)
    tp = true_peak_db(x)
    if tp > peak_db:
        x *= 10 ** ((peak_db - tp) / 20)
    return x


def finish_loop(x, target, sr):
    """ループ：全体の平均ラウドネスを target に。端は輪になっているので切らない"""
    x = x - x.mean()
    x *= 10 ** ((target - lufs_i(x, sr)) / 20)
    return x


def write(name, x, sr=SR):
    rng = np.random.default_rng(12345)
    # 三角分布のディザで 16 bit に
    d = (rng.random(len(x)) - rng.random(len(x)))
    q = np.clip(np.round(x * 32767 + d), -32768, 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(q.tobytes())


def nt(m):
    """MIDI の番号 → Hz"""
    return 440.0 * 2 ** ((m - 69) / 12)


# ---------------------------------------------------------------- UI の音（短く・やわらかく）
# 音の高さは F の長調のペンタトニック（F G A C D）。どれが続けて鳴ってもにごらない

def s_tap(rng):
    """選ぶ：木琴を 1 つ、軽く"""
    x = marimba(nt(81), 0.2, 0.05, 0.7, rng, 0.3) # A5
    return finish(room(x, rng, 0.08, 0.2), -24)


def s_confirm(rng):
    """決める：下から上へ 2 つ（C5 → F5）"""
    out = np.zeros(int(SR * 0.3))
    at(out, marimba(nt(72), 0.25, 0.06, 0.8, rng), 0.0, 0.8)
    at(out, marimba(nt(77), 0.25, 0.08, 0.8, rng), 0.055, 1.0)
    return finish(room(out, rng, 0.1, 0.25), -22)


def s_back(rng):
    """もどる・やめる：上から下へ 2 つ、少し小さく（D5 → A4）"""
    out = np.zeros(int(SR * 0.28))
    at(out, felt(nt(74), 0.22, 0.05, rng), 0.0, 1.0)
    at(out, felt(nt(69), 0.22, 0.06, rng), 0.06, 0.8)
    return finish(room(out, rng, 0.08, 0.2), -25)


def s_toggle(rng):
    """切りかえ：木のブロック＋小さな泡"""
    out = np.zeros(int(SR * 0.14))
    at(out, mallet(nt(79), 0.1, 0.018, [(1.0, 1.0, 1.0), (2.3, 0.3, 0.5)], 0.002, rng, 0.25), 0.0) # G5
    at(out, bubble(700, 1100, 0.07, 0.02), 0.015, 0.25)
    return finish(room(out, rng, 0.06, 0.15), -25)


def s_tab(rng):
    """タブ：カリンバを 1 つ（F5）"""
    x = kalimba(nt(77), 0.22, 0.06, 0.6, rng)
    return finish(room(x, rng, 0.08, 0.2), -25)


def s_open(rng):
    """カードを開く：泡が上へ＋木琴"""
    out = np.zeros(int(SR * 0.26))
    at(out, bubble(420, 880, 0.12, 0.05), 0.0, 0.7)
    at(out, marimba(nt(84), 0.2, 0.05, 0.5, rng, 0.1), 0.045, 0.5) # C6
    return finish(room(out, rng, 0.1, 0.22), -24)


def s_close(rng):
    """カードを閉じる：泡が下へ"""
    out = np.zeros(int(SR * 0.2))
    at(out, bubble(820, 400, 0.11, 0.045), 0.0, 1.0)
    return finish(room(out, rng, 0.08, 0.18), -26)


def s_error(rng):
    """まちがい：低いフェルトで 2 つ、半音さがる（やさしく）"""
    out = np.zeros(int(SR * 0.34))
    at(out, felt(nt(62), 0.25, 0.07, rng), 0.0, 1.0) # D4
    at(out, felt(nt(61), 0.28, 0.09, rng), 0.1, 0.9) # C#4
    return finish(room(out, rng, 0.08, 0.2), -24, lp=4000)


def s_coin(rng):
    """ごほうび（コイン・ポイ）：カリンバで 3 つ上へ＋小さなきらめき"""
    out = np.zeros(int(SR * 0.6))
    for k, m in enumerate([77, 81, 84]): # F5 A5 C6
        at(out, kalimba(nt(m), 0.45, 0.14 + 0.04 * k, 0.5, rng), 0.06 * k, 0.8 + 0.1 * k)
    at(out, kalimba(nt(89), 0.35, 0.1, 0.3, rng, 0.0), 0.2, 0.25) # F6
    return finish(room(out, rng, 0.14, 0.4), -20)


def s_toast(rng):
    """小さな知らせ：カリンバを 1 つ、遠めに（D5）"""
    x = kalimba(nt(74), 0.5, 0.16, 0.5, rng, 0.05)
    return finish(room(x, rng, 0.18, 0.4), -26)


def s_pop(rng):
    """ぽこっ：泡がはじける（いろいろな高さで鳴らされる）"""
    out = np.zeros(int(SR * 0.16))
    at(out, bubble(380, 760, 0.1, 0.03, 0.003), 0.0, 1.0)
    at(out, bubble(900, 1300, 0.04, 0.012, 0.002), 0.02, 0.15)
    return finish(room(out, rng, 0.07, 0.15), -23)


# ---------------------------------------------------------------- 見せ場の音

def s_chime(rng):
    """できた：カリンバの和音をすこしずらして（F5 A5 C6 F6）"""
    out = np.zeros(int(SR * 1.3))
    for k, m in enumerate([77, 81, 84, 89]):
        at(out, kalimba(nt(m), 1.0, 0.32, 0.7, rng, 0.08), 0.075 * k, 0.9 - 0.1 * k)
    return finish(room(out, rng, 0.18, 0.7), -20)


def s_bell(rng):
    """鐘：やわらかい FM の鐘（A5）"""
    out = np.zeros(int(SR * 1.4))
    at(out, bell_fm(nt(81), 1.3, 0.42, 0.8, 3.5), 0.0, 1.0)
    at(out, bell_fm(nt(88), 0.9, 0.22, 0.4, 3.5), 0.0, 0.15)
    return finish(room(out, rng, 0.16, 0.6), -21, lp=5000)


def s_sparkle(rng):
    """きらきら：高すぎないカリンバの粒を 7 つ"""
    out = np.zeros(int(SR * 1.0))
    notes = [84, 86, 89, 91, 93, 96, 89] # C6 D6 F6 G6 A6 C7 F6
    for k, m in enumerate(notes):
        at(out, kalimba(nt(m), 0.4, 0.09, 0.25, rng, 0.0), 0.05 + k * 0.075 + rng.uniform(0, 0.02), 0.5 + 0.08 * rng.random())
    return finish(room(out, rng, 0.2, 0.5, lp=3000), -22, lp=8000)


def s_splash(rng):
    """水しぶき：低めの水音＋泡"""
    out = np.zeros(int(SR * 0.7))
    body = band_noise(rng, 0.45, 200, 2400) * env(tt(0.45), 0.006, 0.09)
    at(out, body, 0.0, 1.0)
    for k in range(5):
        f0 = rng.uniform(380, 700)
        at(out, bubble(f0, f0 * rng.uniform(1.5, 2.0), 0.08, 0.025), 0.06 + k * 0.07 + rng.uniform(0, 0.03), 0.35 * body.std() / 0.2)
    return finish(room(out, rng, 0.12, 0.35), -21, lp=4500)


def s_hatch(rng):
    """孵化：殻が割れる（木の音 3 つ）→ カリンバが上へ → きらめき"""
    out = np.zeros(int(SR * 1.5))
    for k in range(3):
        at(out, mallet(rng.uniform(600, 900), 0.06, 0.012, [(1.0, 1.0, 1.0), (2.4, 0.4, 0.5)], 0.0015, rng, 0.5), 0.03 + 0.06 * k, 0.5 + 0.2 * k)
    for k, m in enumerate([72, 77, 81, 84, 89]): # C5 F5 A5 C6 F6
        at(out, kalimba(nt(m), 1.0, 0.3, 0.7, rng, 0.05), 0.24 + 0.07 * k, 0.8)
    at(out, bell_fm(nt(89), 0.8, 0.3, 0.5, 3.5), 0.62, 0.25)
    return finish(room(out, rng, 0.2, 0.7), -18)


def s_lift(rng):
    """持ちあげる：ふわっと上がる風と泡"""
    out = np.zeros(int(SR * 0.45))
    t = tt(0.35)
    swoosh = band_noise(rng, 0.35, 300, 1800) * np.sin(np.pi * t / 0.35) ** 2
    at(out, swoosh, 0.0, 0.6)
    at(out, bubble(330, 660, 0.25, 0.08, 0.05), 0.08, 0.5 * swoosh.std() / 0.15)
    return finish(room(out, rng, 0.1, 0.25), -24, lp=5000)


def s_tear(rng):
    """ポイが破れる（庭の雷では 0.35 倍の高さでゴロゴロ）：紙のくしゃっ"""
    dur = 0.4
    t = tt(dur)
    n = rng.standard_normal(len(t))
    gate = (rng.random(len(t)) < 0.18).astype(float)
    crackle = signal.sosfilt(signal.butter(2, [250, 2800], "bandpass", fs=SR, output="sos"), n * gate)
    body = band_noise(rng, dur, 120, 900) * 0.6
    x = (crackle + body) * env(t, 0.004, 0.12)
    return finish(room(x, rng, 0.1, 0.3), -24, lp=4500)


def s_grow(rng):
    """庭が育つ：木琴が 5 つ上へ（F4 A4 C5 F5 A5）"""
    out = np.zeros(int(SR * 1.3))
    for k, m in enumerate([65, 69, 72, 77, 81]):
        at(out, marimba(nt(m), 0.8, 0.22, 0.7, rng, 0.15), k * 0.085, 0.8)
    return finish(room(out, rng, 0.16, 0.6), -20)


def s_night(rng):
    """夜になる：カリンバで 3 つ下へ（C5 A4 F4）、長めの響き"""
    out = np.zeros(int(SR * 2.0))
    for k, m in enumerate([72, 69, 65]):
        at(out, kalimba(nt(m), 1.4, 0.5, 0.5, rng, 0.05), k * 0.32, 1.0)
    return finish(room(out, rng, 0.22, 1.0, lp=2500), -21)


def s_dream(rng):
    """夢：カリンバがゆっくり上がって下がる"""
    out = np.zeros(int(SR * 2.6))
    for k, m in enumerate([72, 77, 81, 84, 81, 77]):
        at(out, kalimba(nt(m), 1.2, 0.4, 0.5, rng, 0.05), k * 0.22, 0.8)
    return finish(room(out, rng, 0.22, 1.0, lp=2500), -22)


# ---------------------------------------------------------------- ごほうびの音（重ねて・高さを変えて鳴らす。scripts/sfx.gd の Sfx.catch など）
# 鳴らす側で音の高さを上げる（連続ですくう・コインの粒）ものは、上げても 7 kHz を超えないよう先に低めで切っておく

def s_catch(rng):
    """すくえた：泡がぽこっ＋カリンバを 1 オクターブで 2 つ（F5 F6）。
    連続ですくうと F のペンタトニック（F G A C D F）で 2 倍まで上がる。オクターブの 2 音なので、どの高さでも曲とにごらない。
    2 倍にしても 7 kHz を超えないよう 3.5 kHz で切る"""
    out = np.zeros(int(SR * 0.7))
    at(out, bubble(380, 900, 0.07, 0.022, 0.002), 0.0, 0.8)
    at(out, kalimba(nt(77), 0.5, 0.16, 0.5, rng, 0.12), 0.02, 1.0)
    at(out, kalimba(nt(89), 0.55, 0.2, 0.3, rng, 0.0), 0.07, 0.6)
    return finish(room(out, rng, 0.14, 0.4), -19, lp=3500)


def s_coin_tick(rng):
    """コインの粒：小さく高いカリンバ＋少しだけ金物っぽい倍音（C6）。粒ごとに C D F G A と 5/3 倍まで上がるので 4.5 kHz で切る"""
    out = np.zeros(int(SR * 0.22))
    at(out, mallet(nt(84), 0.2, 0.05, [(1.0, 1.0, 1.0), (2.76, 0.18, 0.4), (5.4, 0.05, 0.2)], 0.0015, rng, 0.08), 0.0)
    return finish(room(out, rng, 0.08, 0.18), -25, lp=4500)


def s_riser(rng):
    """ためる（玉が震えてから割れるまで）：カリンバの粒がだんだん速く・高く＋ふくらむ風。いちばん大きいところで終わる。
    鳴らす側は「割れるまでの秒数」だけ後ろを切り出して鳴らす（Sfx.hatch_build）ので、どこから鳴らしても割れる瞬間が頂点"""
    dur = 1.2
    out = np.zeros(int(SR * dur))
    notes = [65, 67, 69, 72, 74, 77, 79, 81, 84, 86, 89] # F4 から F6 までのペンタトニック
    t0, gap = 0.0, 0.15
    k = 0
    while t0 < dur - 0.03:
        m = notes[min(k, len(notes) - 1)]
        amp = 0.25 + 0.75 * (t0 / dur) ** 1.5
        at(out, kalimba(nt(m), 0.25, 0.06, 0.4, rng, 0.05), t0, amp)
        t0 += gap
        gap = max(0.032, gap * 0.84)
        k += 1
    t = tt(dur)
    swell = (t / dur) ** 2.2
    lo = band_noise(rng, dur, 250, 900) * swell
    hi = band_noise(rng, dur, 900, 2600) * swell ** 2.0
    tone = bubble(260, 620, dur, 10.0, 0.4) * swell * (0.75 + 0.25 * np.sin(2 * np.pi * 11 * t))
    at(out, 0.5 * lo / max(lo.std(), 1e-9) * 0.12, 0.0)
    at(out, 0.4 * hi / max(hi.std(), 1e-9) * 0.12, 0.0)
    at(out, 0.18 * tone, 0.0)
    return finish(room(out, rng, 0.12, 0.35), -21, lp=5500)


def s_crack(rng):
    """割れる：殻がぱきっ（木の音 3 つを速く）＋泡がはじけて上へ＋高いカリンバがきらっ"""
    out = np.zeros(int(SR * 0.6))
    for k in range(3):
        at(out, mallet(rng.uniform(700, 1100), 0.05, 0.01, [(1.0, 1.0, 1.0), (2.4, 0.4, 0.5)], 0.001, rng, 0.6), 0.022 * k, 0.6 + 0.2 * k)
    at(out, bubble(500, 1400, 0.09, 0.03, 0.002), 0.05, 0.7)
    at(out, kalimba(nt(93), 0.4, 0.12, 0.4, rng, 0.0), 0.07, 0.45) # A6
    at(out, kalimba(nt(89), 0.45, 0.15, 0.4, rng, 0.0), 0.07, 0.35) # F6
    return finish(room(out, rng, 0.16, 0.45), -18, lp=6000)


def s_crack_big(rng):
    """大きく割れる（レア）：やわらかい低いどん＋ぱきっ＋きらめきの粒がぱっと広がる＋鐘"""
    out = np.zeros(int(SR * 1.6))
    t = tt(0.5)
    thump = np.sin(2 * np.pi * np.cumsum(110 * (0.5 ** np.clip(t / 0.25, 0, 1))) / SR) * env(t, 0.004, 0.12)
    at(out, thump, 0.0, 0.9)
    for k in range(4):
        at(out, mallet(rng.uniform(650, 1050), 0.05, 0.01, [(1.0, 1.0, 1.0), (2.4, 0.4, 0.5)], 0.001, rng, 0.6), 0.018 * k, 0.5 + 0.15 * k)
    at(out, bubble(450, 1500, 0.1, 0.035, 0.002), 0.04, 0.6)
    for k, m in enumerate([84, 89, 91, 93, 96, 93]): # C6 F6 G6 A6 C7 A6
        at(out, kalimba(nt(m), 0.5, 0.12, 0.3, rng, 0.0), 0.06 + 0.035 * k + rng.uniform(0, 0.01), 0.4)
    at(out, bell_fm(nt(77), 1.2, 0.45, 0.6, 3.5), 0.05, 0.35) # F5
    return finish(room(out, rng, 0.2, 0.8), -17, lp=6000, hp=50)


def s_boom(rng):
    """いちばんの見せ場の下に敷く：ふわっとふくらむ低い音（どーん、ではなく、ふぉーん）"""
    dur = 1.6
    t = tt(dur)
    e = env(t, 0.03, 0.45)
    x = (np.sin(2 * np.pi * 87.3 * t) + 0.5 * np.sin(2 * np.pi * 174.6 * t) + 0.2 * np.sin(2 * np.pi * 261.6 * t)) * e # F2 の和音
    air = band_noise(rng, dur, 150, 700) * env(t, 0.05, 0.3)
    x = x + 0.25 * air / max(air.std(), 1e-9) * 0.3
    return finish(room(x, rng, 0.2, 0.9, lp=1500), -20, lp=2500, hp=40)


def s_reveal(rng):
    """出てきた（いつもの子・島の材料）：木琴 2 つで「たたっ」→ カリンバの和音「たーん」＋きらめき 3 つ"""
    out = np.zeros(int(SR * 1.5))
    at(out, marimba(nt(72), 0.2, 0.05, 0.7, rng), 0.0, 0.6) # C5
    at(out, marimba(nt(77), 0.2, 0.05, 0.7, rng), 0.07, 0.7) # F5
    for k, m in enumerate([77, 81, 84]): # F5 A5 C6
        at(out, kalimba(nt(m), 1.0, 0.32, 0.6, rng, 0.06), 0.16 + 0.012 * k, 0.7)
    at(out, bell_fm(nt(89), 0.9, 0.3, 0.5, 3.5), 0.16, 0.2) # F6
    for k, m in enumerate([89, 93, 96]):
        at(out, kalimba(nt(m), 0.35, 0.08, 0.25, rng, 0.0), 0.32 + 0.06 * k, 0.28)
    return finish(room(out, rng, 0.18, 0.7), -19, lp=6500)


def s_reveal_rare(rng):
    """レアが出てきた：3 連の呼び込み → 低い音から F の大きな和音＋鐘 → きらめきが上へのぼる"""
    out = np.zeros(int(SR * 2.4))
    for k, m in enumerate([72, 74, 77]): # C5 D5 F5
        at(out, marimba(nt(m), 0.2, 0.05, 0.7, rng), 0.065 * k, 0.55 + 0.1 * k)
    at(out, felt(nt(53), 1.2, 0.5, rng), 0.21, 0.7) # F3
    for k, m in enumerate([65, 77, 81, 84, 89]): # F4 F5 A5 C6 F6
        at(out, kalimba(nt(m), 1.6, 0.5, 0.6, rng, 0.06), 0.21 + 0.01 * k, 0.6)
    at(out, bell_fm(nt(81), 1.6, 0.55, 0.6, 3.5), 0.21, 0.3)
    for k, m in enumerate([84, 86, 89, 91, 93, 96, 98, 101]): # C6 から F7 へのぼる
        at(out, kalimba(nt(m), 0.4, 0.09, 0.2, rng, 0.0), 0.42 + 0.055 * k, 0.22 + 0.02 * k)
    return finish(room(out, rng, 0.22, 1.0), -17, lp=6000, hp=60)


def s_levelup(rng):
    """島が広がる・育った：木琴が速く 8 つかけのぼる → 低い根音と和音で着地 → 鐘ときらめき"""
    out = np.zeros(int(SR * 2.3))
    run = [65, 67, 69, 72, 74, 77, 79, 81] # F4 G4 A4 C5 D5 F5 G5 A5
    for k, m in enumerate(run):
        at(out, marimba(nt(m), 0.3, 0.07, 0.7, rng, 0.15), 0.045 * k, 0.55 + 0.04 * k)
    land = 0.045 * len(run) + 0.03
    at(out, felt(nt(53), 1.2, 0.5, rng), land, 0.7) # F3
    for k, m in enumerate([77, 81, 84, 89]): # F5 A5 C6 F6
        at(out, kalimba(nt(m), 1.5, 0.45, 0.6, rng, 0.06), land + 0.012 * k, 0.65)
    at(out, bell_fm(nt(89), 1.3, 0.45, 0.5, 3.5), land, 0.22)
    for k in range(5):
        at(out, kalimba(nt([91, 93, 96, 93, 98][k]), 0.35, 0.08, 0.2, rng, 0.0), land + 0.2 + 0.07 * k + rng.uniform(0, 0.015), 0.22)
    return finish(room(out, rng, 0.2, 0.9), -17, lp=6000, hp=60)


def s_place(rng):
    """島に置く：フェルトの低い「とん」＋土にふれる小さな音＋泡がぽこ"""
    out = np.zeros(int(SR * 0.35))
    at(out, felt(nt(60), 0.28, 0.06, rng), 0.0, 1.0) # C4
    t = tt(0.1)
    thud = band_noise(rng, 0.1, 80, 500) * env(t, 0.002, 0.02)
    at(out, 0.35 * thud / max(thud.std(), 1e-9) * 0.3, 0.0)
    at(out, bubble(600, 950, 0.06, 0.02, 0.002), 0.035, 0.3)
    return finish(room(out, rng, 0.1, 0.25), -22, lp=5000, hp=60)


def s_equip(rng):
    """着がえ：布がふわっ＋カリンバ 2 つ（A5 → D6）＋きらっ"""
    out = np.zeros(int(SR * 0.8))
    t = tt(0.2)
    swish = band_noise(rng, 0.2, 500, 3000) * np.sin(np.pi * t / 0.2) ** 2
    at(out, 0.5 * swish / max(swish.std(), 1e-9) * 0.15, 0.0)
    at(out, kalimba(nt(81), 0.5, 0.14, 0.5, rng, 0.08), 0.1, 0.8)
    at(out, kalimba(nt(86), 0.55, 0.18, 0.5, rng, 0.05), 0.17, 0.85)
    at(out, kalimba(nt(93), 0.3, 0.07, 0.2, rng, 0.0), 0.25, 0.25)
    return finish(room(out, rng, 0.14, 0.4), -21, lp=6000)


def s_press(rng):
    """ボタンを押しこむ（離したときの音の前に、ごく小さく）：フェルトの G4 を短く"""
    x = mallet(nt(67), 0.08, 0.014, [(1.0, 1.0, 1.0), (2.3, 0.2, 0.5)], 0.0015, rng, 0.3)
    return finish(x, -30, lp=4000)


# ---------------------------------------------------------------- ループ（端がつながるように、輪の上で作る）

def loop_noise(rng, n, sr, shape):
    """周波数の上で形をつけた雑音（ちょうど n サンプルで輪になる）"""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / sr)
    return np.fft.irfft(spec * shape(f), n)


def wrap_add(dst, src, start):
    idx = (start + np.arange(len(src))) % len(dst)
    np.add.at(dst, idx, src)


def loop_room(x, rng, sr, wet, rt, lp):
    """輪のまま響きをつける（はみ出たしっぽは頭へ）"""
    t = tt(rt, sr)
    ir = rng.standard_normal(len(t)) * np.exp(-6.9 * t / rt)
    ir = signal.sosfilt(signal.butter(2, lp, fs=sr, output="sos"), ir)
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(x)
    y = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(ir, n)))
    return x + wet * y


def lap(rng, sr, dur, lo, hi):
    """水がよせる音：帯域をしぼった雑音を、ふくらんでしぼむ形で"""
    t = tt(dur, sr)
    n = band_noise(rng, dur, lo, hi, sr)
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2 * np.exp(-t / (dur * 0.9))
    return n * shape


def s_river_loop(rng):
    """夜の川（すくう画面）：さらさら流れる水＋ときどき小さな泡。虫の声は入れない"""
    sr = 22050
    n = int(sr * 8.0)
    tl = np.arange(n) / sr
    bed = loop_noise(rng, n, sr, lambda f: np.where(f < 60, 0, 1.0) / (1 + (f / 700) ** 2))
    bed /= bed.std()
    mod = 0.75 + 0.15 * np.sin(2 * np.pi * 3 * tl / 8.0) + 0.1 * np.sin(2 * np.pi * 7 * tl / 8.0 + 1.3)
    x = bed * mod * 0.5
    for k in range(9):
        f0 = rng.uniform(300, 650)
        b = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.8 * tt(0.08, sr) / 0.08)) / sr) * env(tt(0.08, sr), 0.004, 0.02)
        wrap_add(x, 0.25 * b, int(rng.uniform(0, n)))
    for k in range(4):
        wrap_add(x, 0.6 * lap(rng, sr, rng.uniform(0.9, 1.5), 180, 1000), int(rng.uniform(0, n)))
    x = loop_room(x, rng, sr, 0.15, 0.4, 2000)
    x = np.fft.irfft(np.fft.rfft(x) * (1 / (1 + (np.fft.rfftfreq(n, 1 / sr) / 2500) ** 8)), n) # 2.5 kHz より上を落とす（輪のまま）
    return finish_loop(x, -30, sr), sr


def s_night_amb(rng):
    """夜の庭の環境音：静かな波うちぎわ＋遠くのふくろう（ほんのたまに）。
    鳴らす側は -14 dB で出すので、画面では BGM より 20 dB 以上小さい"""
    sr = 16000
    secs = 18.0
    n = int(sr * secs)
    tl = np.arange(n) / sr
    bed = loop_noise(rng, n, sr, lambda f: np.where(f < 50, 0, 1.0) / (1 + (f / 350) ** 2))
    bed /= bed.std()
    x = bed * (0.8 + 0.2 * np.sin(2 * np.pi * 2 * tl / secs)) * 0.25
    # よせる波：2.5〜4.5 秒おき（大きい波のあとに小さな返し）
    t0 = 0.0
    while t0 < secs - 0.5:
        d = rng.uniform(1.0, 1.6)
        wrap_add(x, rng.uniform(0.7, 1.0) * lap(rng, sr, d, 160, 900), int(t0 * sr))
        wrap_add(x, 0.35 * lap(rng, sr, 0.5, 250, 1100), int((t0 + d * 0.7) * sr))
        t0 += rng.uniform(2.5, 4.5)
    # 遠くのふくろう「ほー、ほー」（ループに 1 回だけ）
    owl = np.zeros(int(sr * 1.2))
    for k, (f, d) in enumerate([(415.0, 0.32), (392.0, 0.45)]):
        t = tt(d, sr)
        ph = 2 * np.pi * np.cumsum(f * (1 + 0.01 * np.sin(2 * np.pi * 5 * t))) / sr
        tone = (np.sin(ph) + 0.15 * np.sin(2 * ph)) * np.sin(np.pi * t / d) ** 1.5
        at(owl, tone, 0.1 + k * 0.5, 1.0, sr)
    wrap_add(x, 0.05 * owl, int(sr * rng.uniform(6.0, 12.0)))
    x = loop_room(x, rng, sr, 0.3, 0.8, 1500)
    x = np.fft.irfft(np.fft.rfft(x) * (1 / (1 + (np.fft.rfftfreq(n, 1 / sr) / 1500) ** 8)), n)
    return finish_loop(x, -32, sr), sr


# ---------------------------------------------------------------- 一覧

SOUNDS = {
    "tap": s_tap, "confirm": s_confirm, "back": s_back, "toggle": s_toggle, "tab": s_tab,
    "open": s_open, "close": s_close, "error": s_error, "coin": s_coin, "toast": s_toast, "pop": s_pop,
    "chime": s_chime, "bell": s_bell, "sparkle": s_sparkle, "splash": s_splash, "hatch": s_hatch,
    "lift": s_lift, "tear": s_tear, "grow": s_grow, "night": s_night, "dream": s_dream,
    "catch": s_catch, "coin_tick": s_coin_tick, "riser": s_riser, "crack": s_crack, "crack_big": s_crack_big,
    "boom": s_boom, "reveal": s_reveal, "reveal_rare": s_reveal_rare, "levelup": s_levelup, "place": s_place,
    "equip": s_equip, "press": s_press,
}
LOOPS = {"river_loop": s_river_loop, "night_amb": s_night_amb}


def _seed(name):
    return sum((i + 1) * ord(c) for i, c in enumerate(name))


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        write(name, fn(np.random.default_rng(_seed(name))))
    for name, fn in LOOPS.items():
        x, sr = fn(np.random.default_rng(_seed(name)))
        write(name, x, sr)
    print("wrote", len(SOUNDS) + len(LOOPS), "sounds to", OUT)


def report():
    print(f"{'name':12s} {'sec':>5s} {'kHz':>4s} {'LUFS':>6s} {'peak':>6s} {'>8k dB':>7s} {'>6k dB':>7s} {'>5k dB':>7s}  kB")
    for name in list(SOUNDS) + list(LOOPS):
        p = OUT / f"{name}.wav"
        with wave.open(str(p)) as w:
            sr = w.getframerate()
            x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768
        lu = lufs_i(x, sr) if name in LOOPS else lufs_m_max(x, sr)
        print(f"{name:12s} {len(x) / sr:5.2f} {sr / 1000:4.1f} {lu:6.1f} {true_peak_db(x):6.1f} {above_db(x, sr, 8000):7.1f} {above_db(x, sr, 6000):7.1f} {above_db(x, sr, 5000):7.1f}  {p.stat().st_size // 1024}")


if __name__ == "__main__":
    if "--report" not in sys.argv:
        build()
    report()
