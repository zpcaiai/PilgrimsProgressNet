#!/usr/bin/env python3
"""
gen_audio.py — procedural original audio for "Pilgrim's Road — Burden Fallen".

Synthesizes per-chapter MUSIC loops, per-chapter AMBIENT beds, and event SFX,
then encodes them to .ogg (libvorbis) at exactly the res:// paths the game's
AudioManager already references. 100% original, public-domain-safe, no samples.

Usage:
    python3 gen_audio.py music   [start] [count]
    python3 gen_audio.py ambient [start] [count]
    python3 gen_audio.py sfx
    python3 gen_audio.py all

Requires: numpy, ffmpeg (libvorbis). No scipy/soundfile needed.
"""
import os, sys, wave, struct, subprocess, tempfile
import numpy as np

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
ADIR = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(20240614)

# ---------------------------------------------------------------------------
# Core DSP helpers
# ---------------------------------------------------------------------------
def midi_freq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)

SCALES = {
    "major":  [0, 2, 4, 5, 7, 9, 11],
    "minor":  [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "sus":    [0, 2, 5, 7, 9, 11, 14],
    "phryg":  [0, 1, 3, 5, 7, 8, 10],
}

def chord_notes(root, scale_name, degree, voicing=(0, 2, 4)):
    sc = SCALES[scale_name]
    out = []
    for v in voicing:
        idx = degree + v
        octv = idx // 7
        out.append(root + sc[idx % 7] + 12 * octv)
    return out

def adsr(n, a, d, s, r):
    a = max(1, int(a * SR)); d = max(1, int(d * SR)); r = max(1, int(r * SR))
    sus = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, s, d, endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, r),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]

def additive(freq, dur, harmonics, amps, vib_rate=0.0, vib_depth=0.0, detune=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1.0 + vib_depth * np.sin(2 * np.pi * vib_rate * t) if vib_rate > 0 else 1.0
    sig = np.zeros(n)
    for h, a in zip(harmonics, amps):
        f = freq * h * (1.0 + detune)
        phase = 2 * np.pi * f * t * vib + rng.uniform(0, 2 * np.pi)
        sig += a * np.sin(phase)
    return sig

def pad_chord(notes, dur, warmth=0.5, brightness=0.5, voice="organ", level=0.5):
    """A sustained chord blending organ/strings/choir character."""
    if voice == "strings":
        harm = [1, 2, 3, 4, 5, 6]; base = [1, .55, .38, .26, .16, .1]
        a, d, s, r = 0.7, 0.6, 0.85, 1.6; vib = (5.4, 0.004)
    elif voice == "choir":
        harm = [1, 2, 3, 4, 5]; base = [1, .5, .32, .18, .1]
        a, d, s, r = 0.9, 0.5, 0.9, 1.8; vib = (5.0, 0.006)
    else:  # organ
        harm = [1, 2, 3, 4, 6, 8]; base = [1, .5, .3, .2, .12, .08]
        a, d, s, r = 0.35, 0.4, 0.9, 1.2; vib = (0.0, 0.0)
    amps = [b * (brightness if i >= 2 else 1.0) for i, b in enumerate(harm and base)]
    n = int(dur * SR)
    env = adsr(n, a, d, s, r)
    out = np.zeros(n)
    for m in notes:
        f = midi_freq(m)
        tone = additive(f, dur, harm, amps, vib[0], vib[1], detune=0.0)
        out += tone
    # warm body: add a soft sub an octave below the lowest note
    sub = additive(midi_freq(min(notes) - 12), dur, [1, 2], [1, 0.3]) * (0.4 * warmth)
    out = (out + sub) * env
    return out * level / max(1, len(notes))

def bell(note, dur, level=0.5):
    f = midi_freq(note)
    n = int(dur * SR)
    t = np.arange(n) / SR
    partials = [(1.0, 1.0, 1.0), (2.0, 0.6, 1.4), (2.76, 0.4, 1.9),
                (5.4, 0.25, 2.6), (8.1, 0.15, 3.4)]
    sig = np.zeros(n)
    for ratio, amp, decay in partials:
        sig += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay)
    sig *= np.exp(-t * 0.6)
    return sig * level

def drone(note, dur, level=0.4, motion=0.08):
    f = midi_freq(note)
    n = int(dur * SR); t = np.arange(n) / SR
    lfo = 1.0 + motion * np.sin(2 * np.pi * (1.0 / dur) * t)  # one slow cycle/loop
    sig = (np.sin(2 * np.pi * f * t)
           + 0.5 * np.sin(2 * np.pi * f * 1.5 * t)      # fifth
           + 0.3 * np.sin(2 * np.pi * f * 2 * t))
    return sig * lfo * level

def pink(n):
    # Voss-ish pink noise via filtered white (simple 1/f weighting in freq domain)
    white = rng.standard_normal(n)
    f = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n) + 1e-6
    f /= np.sqrt(freqs)
    out = np.fft.irfft(f, n)
    return out / (np.max(np.abs(out)) + 1e-9)

def brown(n):
    w = rng.standard_normal(n)
    b = np.cumsum(w)
    b -= np.linspace(b[0], b[-1], n)  # detrend so it loops flat
    return b / (np.max(np.abs(b)) + 1e-9)

def bandpass_fft(x, lo, hi):
    n = len(x)
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(n, 1 / SR)
    mask = (fr >= lo) & (fr <= hi)
    f *= mask
    return np.fft.irfft(f, n)

def make_ir(decay=1.6, length=2.0, predelay=0.02, seed=0):
    r = np.random.default_rng(1000 + seed)
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = r.standard_normal(n) * np.exp(-t / decay)
    pre = int(predelay * SR)
    ir = np.concatenate([np.zeros(pre), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    return ir

def fftconv(a, b):
    n = len(a) + len(b) - 1
    return np.fft.irfft(np.fft.rfft(a, n) * np.fft.rfft(b, n), n)

def reverb_loop(x, wet=0.3, decay=1.8):
    """Seamless reverberant loop: tile, convolve, take 2nd copy so the tail wraps."""
    n = len(x)
    irL = make_ir(decay, min(2.4, decay * 1.3), 0.015, seed=1)
    irR = make_ir(decay, min(2.4, decay * 1.3), 0.022, seed=2)
    xt = np.concatenate([x, x])
    wetL = fftconv(xt, irL)[n:2 * n]
    wetR = fftconv(xt, irR)[n:2 * n]
    dry = x
    L = dry * (1 - wet) + wetL * wet
    R = dry * (1 - wet) + wetR * wet
    st = np.stack([L, R], axis=1)
    # tiny equal-power crossfade over the seam
    xf = int(0.012 * SR)
    fade = np.linspace(0, 1, xf)[:, None]
    head = st[:xf].copy()
    st[:xf] = st[:xf] * fade + st[-xf:][::-1] * 0  # keep head; ensure continuity
    st[-xf:] = st[-xf:] * (1 - fade) + head[::-1] * 0 + st[-xf:] * fade
    return st

def reverb_tail(x, wet=0.3, decay=1.8, seed=7):
    ir = make_ir(decay, decay * 1.4, 0.01, seed=seed)
    wetsig = fftconv(x, ir)[:len(x)]
    return x * (1 - wet) + wetsig * wet

def stereo(x):
    return np.stack([x, x], axis=1)

def normalize(st, peak=0.89):
    m = np.max(np.abs(st)) + 1e-9
    return st * (peak / m)

def soft_clip(st):
    return np.tanh(st * 1.1) * 0.95

def save_ogg(st, relpath, quality=4):
    st = np.clip(st, -1, 1)
    pcm = (st * 32767.0).astype('<i2')
    outpath = os.path.join(ADIR, relpath)
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wavpath = tf.name
    with wave.open(wavpath, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wavpath,
         "-c:a", "libvorbis", "-q:a", str(quality), outpath],
        check=True)
    os.unlink(wavpath)
    kb = os.path.getsize(outpath) / 1024
    print(f"  ✓ {relpath}  ({kb:.0f} KB)")

# ---------------------------------------------------------------------------
# MUSIC — per-chapter mood (user's plan)
# ---------------------------------------------------------------------------
# root midi notes: A2=45 C3=48 D3=50 E3=52 F3=53 G3=55 A3=57
MUSIC = {
    "city_of_destruction": dict(root=50, scale="minor", prog=[0, 5, 3, 4], bar=6.2,
        voice="strings", warmth=.6, bright=.35, drone=.5, pulse=0, bells="toll",
        wet=.34, decay=2.2, gain=.85),
    "wilderness_road": dict(root=48, scale="minor", prog=[0, 6, 0, 5], bar=6.0,
        voice="strings", warmth=.55, bright=.3, drone=.55, pulse=0.5, bells=None,
        wet=.32, decay=2.0, gain=.85),
    "slough_of_despond": dict(root=45, scale="phryg", prog=[0, 1, 0, 6], bar=6.6,
        voice="organ", warmth=.7, bright=.22, drone=.7, pulse=0.4, bells=None,
        wet=.36, decay=2.4, gain=.82),
    "wicket_gate": dict(root=55, scale="sus", prog=[0, 3, 4, 0], bar=5.6,
        voice="choir", warmth=.5, bright=.55, drone=.3, pulse=0, bells="sparse",
        wet=.4, decay=2.4, gain=.82),
    "cross_and_tomb": dict(root=50, scale="major", prog=[0, 3, 4, 0, 5, 4], bar=4.6,
        voice="choir", warmth=.7, bright=.7, drone=.3, pulse=0, bells="melody",
        wet=.42, decay=2.6, gain=.9, shimmer=True),
    "interpreter_house": dict(root=53, scale="major", prog=[0, 5, 1, 4], bar=5.2,
        voice="organ", warmth=.55, bright=.5, drone=.25, pulse=0, bells="sparse",
        wet=.38, decay=2.2, gain=.82),
    "hill_difficulty": dict(root=50, scale="dorian", prog=[0, 3, 5, 6], bar=5.0,
        voice="strings", warmth=.5, bright=.45, drone=.4, pulse=0.6, bells=None,
        wet=.34, decay=2.0, gain=.85),
    "palace_beautiful": dict(root=55, scale="major", prog=[0, 4, 5, 3], bar=5.6,
        voice="choir", warmth=.7, bright=.6, drone=.3, pulse=0, bells="sparse",
        wet=.42, decay=2.6, gain=.86),
    "valley_humiliation": dict(root=45, scale="minor", prog=[0, 1, 6, 0], bar=5.4,
        voice="strings", warmth=.55, bright=.3, drone=.65, pulse=0.7, bells=None,
        wet=.32, decay=2.0, gain=.85),
    "valley_shadow_death": dict(root=43, scale="phryg", prog=[0, 0, 6, 0], bar=7.0,
        voice="organ", warmth=.6, bright=.2, drone=.8, pulse=0, bells="far",
        wet=.45, decay=3.0, gain=.8),
    "vanity_fair": dict(root=52, scale="dorian", prog=[0, 4, 2, 5, 1], bar=3.6,
        voice="organ", warmth=.45, bright=.6, drone=.3, pulse=1.6, bells="motif",
        wet=.3, decay=1.6, gain=.84),
    "doubting_castle": dict(root=43, scale="minor", prog=[0, 6, 0, 1], bar=6.4,
        voice="organ", warmth=.6, bright=.18, drone=.85, pulse=0, bells=None,
        wet=.46, decay=3.2, gain=.8),
    "delectable_mountains": dict(root=57, scale="major", prog=[0, 4, 1, 5], bar=5.4,
        voice="choir", warmth=.65, bright=.7, drone=.25, pulse=0, bells="melody",
        wet=.44, decay=2.8, gain=.88),
    "enchanted_ground": dict(root=53, scale="dorian", prog=[0, 5, 3, 4], bar=6.4,
        voice="choir", warmth=.6, bright=.4, drone=.45, pulse=0.3, bells="haze",
        wet=.46, decay=2.8, gain=.82),
    "river_of_death": dict(root=45, scale="minor", prog=[0, 5, 3, 4], bar=6.8,
        voice="strings", warmth=.65, bright=.35, drone=.6, pulse=0, bells="far",
        wet=.42, decay=2.8, gain=.84),
    "celestial_city": dict(root=50, scale="major", prog=[0, 3, 4, 0, 4, 5], bar=4.4,
        voice="choir", warmth=.75, bright=.85, drone=.35, pulse=0, bells="melody",
        wet=.46, decay=3.0, gain=.92, shimmer=True),
    "title": dict(root=50, scale="major", prog=[0, 5, 3, 4], bar=6.0,
        voice="choir", warmth=.7, bright=.6, drone=.35, pulse=0, bells="sparse",
        wet=.44, decay=2.8, gain=.86),
}

def render_music(p):
    bar = p["bar"]; prog = p["prog"]
    total = bar * len(prog)
    n = int(total * SR)
    mono = np.zeros(n)
    melody_notes = []  # (start_time, midi)
    for i, deg in enumerate(prog):
        notes = chord_notes(p["root"], p["scale"], deg, (0, 2, 4))
        seg = pad_chord(notes, bar, p["warmth"], p["bright"], p["voice"], level=.5)
        s0 = int(i * bar * SR)
        mono[s0:s0 + len(seg)] += seg[:n - s0]
        melody_notes.append((i * bar, notes))
    # drone on tonic
    if p["drone"] > 0:
        mono += drone(p["root"] - 12, total, level=p["drone"] * 0.5)
    # slow pulse
    if p["pulse"] > 0:
        t = np.arange(n) / SR
        pl = 0.5 + 0.5 * (np.sin(2 * np.pi * p["pulse"] * t - np.pi / 2))
        pulsetone = drone(p["root"], total, level=0.22) * (pl ** 2)
        mono += pulsetone
    # bells / melody
    style = p["bells"]
    if style:
        for i, (t0, notes) in enumerate(melody_notes):
            if style == "toll" and i % 2 == 0:
                seg = bell(p["root"] - 12, min(4.0, bar), 0.3)
            elif style == "sparse" and i % 2 == 1:
                seg = bell(notes[-1] + 12, min(3.0, bar), 0.22)
            elif style == "far":
                seg = bell(notes[0] + 12, min(4.0, bar), 0.14)
            elif style in ("melody", "motif", "haze"):
                # a small ascending figure across the chord tones
                seg = np.zeros(int(min(bar, 4.0) * SR))
                steps = [0, 2, 4, 2] if style != "motif" else [4, 2, 4, 0]
                for k, sd in enumerate(steps):
                    bn = chord_notes(p["root"], p["scale"], prog[i] + sd, (0,))[0] + 12
                    b = bell(bn, 1.4, 0.2 if style != "haze" else 0.12)
                    off = int(k * 0.42 * SR)
                    if off + len(b) <= len(seg):
                        seg[off:off + len(b)] += b
            else:
                continue
            s0 = int(t0 * SR)
            mono[s0:s0 + len(seg)] += seg[:n - s0]
    if p.get("shimmer"):
        t = np.arange(n) / SR
        sh = (np.sin(2 * np.pi * midi_freq(p["root"] + 24) * t)
              + 0.6 * np.sin(2 * np.pi * midi_freq(p["root"] + 31) * t))
        sh *= 0.5 + 0.5 * np.sin(2 * np.pi * 0.12 * t)
        mono += sh * 0.035
    mono *= p["gain"]
    st = reverb_loop(mono, wet=p["wet"], decay=p["decay"])
    st = soft_clip(normalize(st, 0.9))
    return st

# ---------------------------------------------------------------------------
# AMBIENT — per-chapter environment beds (seamless)
# ---------------------------------------------------------------------------
def amb_wind(n, lo=120, hi=900, level=0.5, gust=0.25):
    base = bandpass_fft(pink(n), lo, hi)
    t = np.arange(n) / SR
    g = 1.0 + gust * np.sin(2 * np.pi * (1.0 / (n / SR)) * t * 2) \
            + gust * 0.5 * np.sin(2 * np.pi * (1.0 / (n / SR)) * t * 3)
    return base * g * level

def amb_water(n, level=0.5):
    w = bandpass_fft(brown(n), 80, 1600)
    rip = bandpass_fft(pink(n), 800, 4000) * 0.3
    return (w + rip) * level

def amb_drips(n, rate=0.6, level=0.4):
    out = np.zeros(n)
    dur = n / SR
    k = max(1, int(dur * rate))
    for _ in range(k):
        t0 = rng.uniform(0, dur - 0.3)
        f = rng.uniform(700, 1400)
        ln = int(0.18 * SR); tt = np.arange(ln) / SR
        d = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 24)
        s0 = int(t0 * SR)
        out[s0:s0 + ln] += d * rng.uniform(0.5, 1.0)
    return out * level

def amb_birds(n, rate=0.5, level=0.3):
    out = np.zeros(n); dur = n / SR
    for _ in range(max(1, int(dur * rate))):
        t0 = rng.uniform(0, dur - 0.5)
        ln = int(rng.uniform(0.08, 0.18) * SR); tt = np.arange(ln) / SR
        f0 = rng.uniform(2200, 3600); f1 = f0 * rng.uniform(0.7, 1.4)
        f = np.linspace(f0, f1, ln)
        chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(ln)
        s0 = int(t0 * SR)
        out[s0:s0 + ln] += chirp * rng.uniform(0.4, 1.0)
    return out * level

def amb_crowd(n, level=0.4):
    base = bandpass_fft(pink(n), 200, 1500)
    t = np.arange(n) / SR
    mod = 1 + 0.3 * np.sin(2 * np.pi * 0.7 * t) + 0.2 * np.sin(2 * np.pi * 1.3 * t)
    return base * mod * level

def amb_tone(note, n, level=0.3):
    return drone(note, n / SR, level=level, motion=0.05)

def amb_bell_tolls(n, note, rate=0.2, level=0.25):
    out = np.zeros(n); dur = n / SR
    for _ in range(max(1, int(dur * rate))):
        t0 = rng.uniform(0, dur - 2.0)
        b = bell(note, 3.5, level)
        s0 = int(t0 * SR)
        out[s0:s0 + len(b)] += b[:n - s0]
    return out

AMB = {
    "city_of_destruction": lambda n: amb_wind(n, 100, 700, .4) + amb_crowd(n, .18) + amb_bell_tolls(n, 38, .12, .18),
    "wilderness_road":     lambda n: amb_wind(n, 140, 1100, .5, .35) + amb_birds(n, .25, .12),
    "slough_of_despond":   lambda n: amb_wind(n, 80, 500, .35) + amb_drips(n, 1.2, .35) + amb_tone(33, n, .18),
    "wicket_gate":         lambda n: amb_wind(n, 160, 1200, .35) + amb_bell_tolls(n, 64, .15, .1),
    "cross_and_tomb":      lambda n: amb_wind(n, 200, 1400, .28) + amb_tone(62, n, .12),
    "interpreter_house":   lambda n: amb_tone(48, n, .12) + amb_drips(n, .3, .15) + amb_wind(n, 300, 900, .12),
    "hill_difficulty":     lambda n: amb_wind(n, 120, 1300, .55, .4) + amb_birds(n, .18, .1),
    "palace_beautiful":    lambda n: amb_tone(55, n, .14) + amb_bell_tolls(n, 60, .1, .12) + amb_wind(n, 250, 800, .12),
    "valley_humiliation":  lambda n: amb_wind(n, 70, 600, .5) + amb_tone(31, n, .25),
    "valley_shadow_death": lambda n: amb_wind(n, 50, 450, .55) + amb_tone(29, n, .3) + amb_drips(n, .8, .25),
    "vanity_fair":         lambda n: amb_crowd(n, .5) + amb_bell_tolls(n, 50, .3, .14),
    "doubting_castle":     lambda n: amb_tone(28, n, .35) + amb_drips(n, 1.0, .3) + amb_wind(n, 60, 400, .3),
    "delectable_mountains":lambda n: amb_wind(n, 180, 1400, .4, .35) + amb_birds(n, .4, .16) + amb_bell_tolls(n, 67, .12, .08),
    "enchanted_ground":    lambda n: amb_tone(53, n, .2) + amb_wind(n, 200, 1000, .25) + amb_birds(n, .2, .06),
    "river_of_death":      lambda n: amb_water(n, .5) + amb_tone(33, n, .22),
    "celestial_city":      lambda n: amb_tone(74, n, .12) + amb_bell_tolls(n, 72, .25, .14) + amb_wind(n, 400, 2000, .14),
}

def render_ambient(name, dur=18.0):
    n = int(dur * SR)
    mono = AMB[name](n)
    mono = mono / (np.max(np.abs(mono)) + 1e-9) * 0.7
    st = reverb_loop(mono, wet=0.25, decay=2.0)
    return soft_clip(normalize(st, 0.82))

# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------
def sfx_blip(freqs, durs, level=0.7, decay=12):
    parts = []
    for f, d in zip(freqs, durs):
        ln = int(d * SR); t = np.arange(ln) / SR
        s = np.sin(2 * np.pi * f * t) * np.exp(-t * decay) * level
        parts.append(s)
    return np.concatenate(parts)

def mix(*arrs):
    m = max(len(a) for a in arrs)
    out = np.zeros(m)
    for a in arrs:
        out[:len(a)] += a
    return out

def sfx_arp(notes, step=0.09, decay=8, level=0.6):
    out = []
    for m in notes:
        out.append(bell(m, 0.5, level))
    sig = np.zeros(int((len(notes) * step + 0.6) * SR))
    for i, b in enumerate(out):
        s0 = int(i * step * SR)
        sig[s0:s0 + len(b)] += b
    return sig

def make_sfx():
    items = {}
    items["ui_select"] = sfx_blip([880, 1320], [0.05, 0.07], 0.5, 28)
    items["interact"]  = sfx_blip([520, 700], [0.07, 0.1], 0.55, 18)
    items["quest_complete"] = sfx_arp([62, 66, 69, 74], 0.1, level=0.5)
    items["promise"]   = mix(bell(69, 1.2, 0.6), bell(76, 1.2, 0.3))
    # burden_fall: a low rolling descent + soft thud
    n = int(1.3 * SR); t = np.arange(n) / SR
    desc = np.sin(2 * np.pi * np.cumsum(np.linspace(220, 70, n)) / SR) * np.exp(-t * 1.6) * 0.6
    roll = bandpass_fft(brown(n), 60, 300) * np.exp(-t * 2.0) * 0.5
    items["burden_fall"] = mix(desc, roll)
    # cross_grace: radiant choir swell + bell
    ch = pad_chord(chord_notes(62, "major", 0, (0, 2, 4, 6)), 1.8, .7, .8, "choir", .6)
    items["cross_grace"] = mix(ch, bell(86, 1.6, 0.3))
    # collapse: dark downward hit
    n = int(1.1 * SR); t = np.arange(n) / SR
    hit = np.sin(2 * np.pi * np.cumsum(np.linspace(160, 45, n)) / SR) * np.exp(-t * 2.4) * 0.7
    items["collapse"] = mix(hit, bandpass_fft(brown(n), 40, 200) * np.exp(-t * 3) * 0.4)
    # victory: triumphant chord stack
    vic = mix(pad_chord(chord_notes(62, "major", 0, (0, 2, 4)), 1.4, .7, .8, "organ", .5),
              sfx_arp([62, 66, 69, 74, 81], 0.11, level=0.4))
    items["victory"] = vic
    items["save"] = sfx_blip([660, 990], [0.06, 0.1], 0.45, 16)

    # --- extended gameplay SFX (referenced by chapter mechanics) ---
    def sweep(f0, f1, dur, decay, level=0.5):
        n = int(dur * SR); t = np.arange(n) / SR
        ph = np.cumsum(np.linspace(f0, f1, n)) / SR
        return np.sin(2 * np.pi * ph) * np.exp(-t * decay) * level

    # chapel_kneel: a soft reverent settle + low warm note
    n = int(0.5 * SR); t = np.arange(n) / SR
    kneel = bandpass_fft(brown(n), 50, 180) * np.exp(-t * 5) * 0.5
    items["chapel_kneel"] = mix(kneel, bell(50, 1.0, 0.16))
    # blessing: gentle choir swell + high bell (briefer than cross_grace)
    items["blessing"] = mix(pad_chord(chord_notes(64, "major", 0, (0, 2, 4)), 1.1, .7, .7, "choir", .5),
                            bell(83, 1.0, 0.2))
    # lantern_word: a small kindling of light — high bell + rising shine
    items["lantern_word"] = mix(bell(88, 1.3, 0.35), sweep(520, 1100, 0.5, 3.0, 0.18))
    # vanity_buy: an enticing but slightly sour metallic ring
    items["vanity_buy"] = mix(bell(96, 0.5, 0.3), bell(101, 0.5, 0.22),
                              bandpass_fft(pink(int(0.4 * SR)), 3000, 6000) * np.exp(-np.arange(int(0.4 * SR)) / SR * 16) * 0.2)
    # vanity_lay_down: a soft setting-down / refusal (gentle descent)
    items["vanity_lay_down"] = mix(sweep(420, 190, 0.7, 3.2, 0.4), bell(45, 0.8, 0.12))
    # river_cross: water motion + a hopeful warm swell
    nw = int(1.2 * SR)
    items["river_cross"] = mix(bandpass_fft(brown(nw), 90, 1500) * np.exp(-np.arange(nw) / SR * 1.2) * 0.5,
                               pad_chord(chord_notes(57, "major", 0, (0, 2, 4)), 1.2, .7, .6, "choir", .4))
    # sleep_fail: a drowsy slump (slow blurred descent)
    ns = int(1.1 * SR); ts = np.arange(ns) / SR
    drowse = np.sin(2 * np.pi * (np.cumsum(np.linspace(300, 120, ns)) / SR) * (1 + 0.03 * np.sin(2 * np.pi * 3 * ts))) * np.exp(-ts * 2.2) * 0.5
    items["sleep_fail"] = mix(drowse, bandpass_fft(brown(ns), 40, 260) * np.exp(-ts * 3) * 0.3)
    # shadow_snuff: a quick snuffed-out hiss + low thud
    nn = int(0.3 * SR); tn = np.arange(nn) / SR
    items["shadow_snuff"] = mix(bandpass_fft(pink(nn), 200, 2200) * np.exp(-tn * 18) * 0.5,
                                np.sin(2 * np.pi * 90 * tn) * np.exp(-tn * 22) * 0.3)
    # message_in: soft incoming-message blip; mention: brighter attention ping
    items["message_in"] = sfx_blip([720, 920], [0.05, 0.07], 0.4, 20)
    items["mention"] = mix(bell(84, 0.5, 0.3), sfx_blip([988, 1320], [0.06, 0.09], 0.4, 16))

    # --- combat feedback SFX (SymbolicEnemy hit / block / hurt / defeat) ---
    ni = int(0.28 * SR); ti = np.arange(ni) / SR
    items["impact"] = mix(
        bandpass_fft(pink(ni), 800, 4500) * np.exp(-ti * 34) * 0.6,
        np.sin(2 * np.pi * 180 * ti) * np.exp(-ti * 26) * 0.5,
        sweep(900, 300, 0.12, 22, 0.35))
    items["block"] = mix(bell(79, 0.5, 0.34), bell(86, 0.5, 0.2),
        bandpass_fft(pink(int(0.2 * SR)), 2500, 6500) * np.exp(-np.arange(int(0.2 * SR)) / SR * 24) * 0.22)
    nh = int(0.35 * SR); th = np.arange(nh) / SR
    items["player_hurt"] = mix(sweep(300, 90, 0.3, 9, 0.55),
        bandpass_fft(brown(nh), 60, 400) * np.exp(-th * 10) * 0.4)
    items["enemy_defeat"] = mix(
        bandpass_fft(pink(int(0.3 * SR)), 300, 3000) * np.exp(-np.arange(int(0.3 * SR)) / SR * 12) * 0.4,
        pad_chord(chord_notes(57, "major", 0, (0, 2, 4)), 0.9, .6, .6, "choir", .35))

    for name, mono in items.items():
        mono = np.asarray(mono, dtype=float)
        mono = mono / (np.max(np.abs(mono)) + 1e-9) * 0.85
        st = reverb_tail(mono, wet=0.18, decay=1.2, seed=hash(name) % 50)
        # fade in/out to avoid clicks
        xf = int(0.005 * SR)
        st[:xf] *= np.linspace(0, 1, xf)
        st[-xf:] *= np.linspace(1, 0, xf)
        save_ogg(stereo(st), os.path.join("sfx", name + ".ogg"), quality=5)

# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def main():
    group = sys.argv[1] if len(sys.argv) > 1 else "all"
    start = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 999

    if group in ("music", "all"):
        keys = list(MUSIC.keys())[start:start + count]
        print(f"[music] {keys}")
        for k in keys:
            save_ogg(render_music(MUSIC[k]), os.path.join("music", k + ".ogg"))
    if group in ("ambient", "all"):
        keys = list(AMB.keys())[start:start + count]
        print(f"[ambient] {keys}")
        for k in keys:
            save_ogg(render_ambient(k), os.path.join("ambient", k + ".ogg"))
    if group in ("sfx", "all"):
        print("[sfx]")
        make_sfx()
    print("done.")

if __name__ == "__main__":
    main()
