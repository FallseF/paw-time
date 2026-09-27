"""Bake the Paw Time BGM (Google Lyria 3 mp3 -> loop-ready OGG Vorbis at -16 LUFS).

  python tools/bake_music.py <dir with title/island/night/work/reveal.mp3> [quality 0..1, default 0.6]
  (numpy + soundfile; ffmpeg on PATH)

Writes assets/music/*.ogg. Each looping track is cut at E and its last XF seconds are crossfaded with the XF
seconds that lead into S, so the jump from the file end back to S (AudioStreamOggVorbis.loop_offset, set in
scripts/music.gd) is seamless. S/E sit where the song repeats itself (same bar phase; beat-synchronous chroma and
waveform correlation), then S is nudged +-40 ms to the best sample alignment. Copy the printed loop offsets into
Music.TRACKS. reveal: the first phrase only (ends ~6.6 s, at the gap before the second phrase) with a 0.8 s fade.
"""
import os
import numpy as np, soundfile as sf, subprocess, json, re, sys
SR=44100
HERE=os.path.dirname(os.path.abspath(__file__))
OUT=os.path.join(HERE, "..", "assets", "music")
SRC=sys.argv[1]
Q=float(sys.argv[2]) if len(sys.argv)>2 else 0.6
# name: (trim_head, loop_start S, loop_end E) in source seconds; reveal: (0, None, cut)
CFG = {
  "title":  (1.0, 18.39, 78.39),
  "island": (0.0, 35.99, 88.35),
  "night":  (0.0, 55.10, 112.25),
  "work":   (0.0, 21.42, 97.43),
  "reveal": (0.0, None, 6.6),
}
XF = 1.5
TARGET = -16.0
def load(n):
    raw = subprocess.run(["ffmpeg","-v","error","-i",os.path.join(SRC, f"{n}.mp3"),"-f","f32le","-ac","2","-ar",str(SR),"-"],capture_output=True,check=True).stdout
    return np.frombuffer(raw,dtype=np.float32).reshape(-1,2).copy()
def lufs(path):
    out = subprocess.run(["ffmpeg","-hide_banner","-nostats","-i",path,"-af","ebur128=peak=true","-f","null","-"],capture_output=True,text=True).stderr
    i = float(re.findall(r"I:\s+(-?[\d.]+) LUFS",out)[-1]); p = float(re.findall(r"Peak:\s+(-?[\d.]+) dBFS",out)[-1])
    return i,p
meta={}
TMP=os.path.join(OUT, "_tmp.wav")
for n,(head,S,E) in CFG.items():
    x = load(n)
    x = x[int(head*SR):]
    if S is None:
        e = int(E*SR); f=int(0.8*SR)
        y = x[:e].copy(); y[e-f:] *= (np.cos(np.linspace(0,np.pi/2,f))**2)[:,None]
        loop=None
    else:
        s = int((S-head)*SR); e = int((E-head)*SR)
        # sample-align S to E by cross-correlation (+-40ms) on mono
        m = x.mean(1); w=int(0.6*SR); L=int(0.04*SR)
        ref = m[e-w:e]
        best=(-1e9,0)
        for lag in range(-L,L+1,4):
            seg = m[s+lag-w:s+lag]
            c = float(np.dot(ref,seg)/(np.linalg.norm(ref)*np.linalg.norm(seg)+1e-9))
            if c>best[0]: best=(c,lag)
        lo=max(best[1]-4,-L); hi=min(best[1]+4,L)
        for lag in range(lo,hi+1):
            seg = m[s+lag-w:s+lag]; c=float(np.dot(ref,seg)/(np.linalg.norm(ref)*np.linalg.norm(seg)+1e-9))
            if c>best[0]: best=(c,lag)
        s += best[1]
        f=int(XF*SR)
        # tail [e-f,e) crossfades into [s-f,s) so the jump e->s is continuous. correlated material -> equal-gain raised cosine
        ph = np.linspace(0,1,f)
        fo = 0.5*(1+np.cos(np.pi*ph)); fi = 1-fo
        y = x[:e].copy()
        y[e-f:e] = x[e-f:e]*fo[:,None] + x[s-f:s]*fi[:,None]
        loop = s/SR
        print(n, "corr", round(best[0],3), "lag ms", round(best[1]/SR*1000,1))
    sf.write(TMP, y, SR, subtype="FLOAT")
    i,p = lufs(TMP)
    g = TARGET - i
    y = y * (10**(g/20))
    peak = np.abs(y).max()
    if peak > 0.97: y *= 0.97/peak
    y = y.astype(np.float32)
    with sf.SoundFile(os.path.join(OUT, f"{n}.ogg"),"w",SR,2,format="OGG",subtype="VORBIS",compression_level=Q) as fo_:
        for k in range(0,len(y),4096): fo_.write(y[k:k+4096])
    i2,p2 = lufs(os.path.join(OUT, f"{n}.ogg"))
    meta[n]={"loop_offset":loop,"length":len(y)/SR,"lufs":i2,"peak":p2}
    print(n, meta[n])
os.remove(TMP)
print(json.dumps(meta, indent=1))
