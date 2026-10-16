"""Synthesises every v0.8 music stem and sound effect from scratch (numpy + scipy, no samples).
Music: 80 BPM, D minor, 16 bars (48 s), four stems that loop seamlessly and stay in sync.
Run: python tools/synth_v8.py   ->  project/assets/audio_v8/*.wav"""
from pathlib import Path
import numpy as np
from scipy import signal
import wave

SR = 44100
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "project/assets/audio_v8"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(1702)

def write(name, data, stereo=False):
    data = np.asarray(data, dtype=np.float64)
    if not name.startswith("music"):
        # Short fades so one-shots never click at their edges.
        n = len(data); fi = min(n // 4, int(0.001 * SR)); fo = min(n // 3, int(0.006 * SR))
        data = data.copy(); data[:fi] *= np.linspace(0, 1, fi); data[n - fo:] *= np.linspace(1, 0, fo)
        data -= np.mean(data)
    if stereo and data.ndim == 1:
        data = np.stack([data, data], axis=1)
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * 0.89  # -1 dBFS
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())

def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR

def env_adsr(n, a, d, s, r, sustain_len=None):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    s_len = n - a - d - r if sustain_len is None else int(sustain_len * SR)
    s_len = max(0, s_len)
    e = np.concatenate([np.linspace(0, 1, max(a, 1)), np.linspace(1, s, max(d, 1)), np.full(s_len, s), np.linspace(s, 0, max(r, 1))])
    return np.pad(e, (0, max(0, n - len(e))))[:n]

def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x, axis=0)

def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x, axis=0)

def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x, axis=0)

def saw(freq_t, t):
    phase = np.cumsum(freq_t) / SR if np.ndim(freq_t) else freq_t * t
    return 2 * (phase % 1.0) - 1

def tri(phase):
    return 2 * np.abs(2 * (phase % 1.0) - 1) - 1

def note(n):  # MIDI note -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)

def reverb_ir(seconds=2.6, decay=3.2, stereo=True):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    chans = []
    for _ in range(2 if stereo else 1):
        ir = rng.standard_normal(n) * np.exp(-decay * t)
        ir = lowpass(ir, 6500)
        ir[:int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        chans.append(ir / np.sqrt(np.sum(ir ** 2)))
    return np.stack(chans, axis=1) if stereo else chans[0]

IR = reverb_ir()

def reverb(x, mix=0.3, ir=IR):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    wet = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], axis=1)
    return x * (1 - mix) + wet * mix

def loop_wrap(x, n):
    """Fold the tail past the loop point back onto the start so the loop is seamless."""
    out = x[:n].copy()
    tail = x[n:]
    k = min(len(tail), n)
    out[:k] += tail[:k]
    return out

# ---------------------------------------------------------------------------- music
BPM = 80
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 16
LOOP = BAR * BARS                       # 48 s
N = int(LOOP * SR)
TAIL = int(4 * SR)
T = np.arange(N + TAIL) / SR
# Dm9 | Bbmaj7 | Gm9 | A7sus4, each held four bars.
CHORDS = [[50, 57, 60, 64, 65], [46, 53, 57, 60, 62], [43, 50, 53, 57, 58], [45, 52, 55, 59, 62]]

def pad_stem():
    out = np.zeros((N + TAIL, 2))
    for ci, chord in enumerate(CHORDS):
        start = int(ci * 4 * BAR * SR)
        length = int(4 * BAR * SR) + int(1.5 * SR)
        t = np.arange(length) / SR
        e = env_adsr(length, 1.8, 1.0, 0.85, 1.5, sustain_len=4 * BAR - 2.8)
        for li, m in enumerate(chord):
            f = note(m)
            for side, cents in ((0, -7), (1, +7)):
                wob = 1 + 0.0025 * np.sin(2 * np.pi * 0.21 * t + li + side)  # tape wow
                fr = f * 2 ** (cents / 1200) * wob
                voice = saw(fr, t) * 0.5 + np.sin(2 * np.pi * np.cumsum(fr) / SR) * 0.5
                end = min(start + length, N + TAIL)
                out[start:end, side] += (voice * e)[: end - start] * (0.22 if li == 0 else 0.14)
    # Slowly breathing filter, so the pad never sits still.
    cut = 900 + 500 * np.sin(2 * np.pi * T / (BAR * 4))
    sos_out = np.zeros_like(out)
    block = int(0.05 * SR)
    for c in range(2):
        zi = None
        b0, a0 = signal.butter(2, 900 / (SR / 2), "low")
        zi = signal.lfilter_zi(b0, a0) * 0
        for s in range(0, len(out), block):
            b, a = signal.butter(2, cut[min(s, len(cut) - 1)] / (SR / 2), "low")
            seg, zi = signal.lfilter(b, a, out[s:s + block, c], zi=zi)
            sos_out[s:s + block, c] = seg
    return sos_out

def sub_bass():
    out = np.zeros(N + TAIL)
    for ci, chord in enumerate(CHORDS):
        for bar in range(4):
            start = int((ci * 4 + bar) * BAR * SR)
            length = int(BAR * SR)
            t = np.arange(length) / SR
            f = note(chord[0] - 12)
            e = env_adsr(length, 0.05, 0.4, 0.7, 0.4)
            out[start:start + length] += np.sin(2 * np.pi * f * t) * e * 0.55
    return out

def rain_layer():
    n = N + TAIL
    pink = np.cumsum(rng.standard_normal(n)) * 0.002
    pink = highpass(pink, 300) + rng.standard_normal(n) * 0.02
    rain = lowpass(bandpass(pink, 600, 6000), 4800) * (0.7 + 0.3 * np.sin(2 * np.pi * T / 11.0))
    drops = np.zeros(n)
    for i in rng.integers(0, n - 2000, 900):
        d = np.exp(-np.arange(1600) / 120.0) * np.sin(2 * np.pi * rng.uniform(2500, 5200) * np.arange(1600) / SR)
        drops[i:i + 1600] += d * rng.uniform(0.02, 0.08)
    crackle = np.zeros(n)
    idx = rng.integers(0, n, 2600)
    crackle[idx] = rng.uniform(-0.25, 0.25, len(idx))
    crackle = highpass(crackle, 2000)
    return rain * 0.3 + drops * 0.7 + crackle * 0.25

def base_stem():
    pad = pad_stem()
    bass = sub_bass()
    rain = rain_layer()
    mix = reverb(pad, 0.35) * 0.9
    mix[:, 0] += bass + rain * 0.55
    mix[:, 1] += bass + np.roll(rain, 913) * 0.55
    return loop_wrap(mix, N)

def kick(length=0.45):
    t = t_axis(length)
    f = 48 + 70 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)

def hat(length=0.06, bright=1.0):
    t = t_axis(length)
    return highpass(rng.standard_normal(len(t)), 6000 * bright) * np.exp(-t * 70)

def pulse_stem():
    out = np.zeros((N + TAIL, 2))
    duck = np.ones(N + TAIL)
    k = kick() * 0.9
    for beat in range(BARS * 4):
        s = int(beat * BEAT * SR)
        if beat % 4 in (0, 2) or (beat % 8 == 7):
            out[s:s + len(k), 0] += k; out[s:s + len(k), 1] += k
            dl = int(0.35 * SR)
            duck[s:s + dl] = np.minimum(duck[s:s + dl], 1 - 0.6 * np.exp(-np.arange(dl) / (0.08 * SR)))
        if beat % 4 in (1, 3):
            rim = bandpass(rng.standard_normal(int(0.05 * SR)), 1500, 4000) * np.exp(-np.arange(int(0.05 * SR)) / 220.0) * 0.35
            out[s:s + len(rim), 0] += rim * 0.8; out[s:s + len(rim), 1] += rim
        for half in range(2):
            swing = 0.0 if half == 0 else BEAT * 0.56
            hs = int((beat * BEAT + swing) * SR)
            h = lowpass(hat(bright=1.0 if half else 1.2), 11000) * (0.14 if half else 0.10)
            pan = 0.7 if half else 0.4
            out[hs:hs + len(h), 0] += h * pan; out[hs:hs + len(h), 1] += h * (1 - pan + 0.3)
    # Eighth-note bass pulse on the chord root, ducked by the kick.
    bass = np.zeros(N + TAIL)
    for ci, chord in enumerate(CHORDS):
        for eighth in range(32):
            s = int((ci * 4 * BAR + eighth * BEAT / 2) * SR)
            ln = int(BEAT / 2 * SR)
            t = np.arange(ln) / SR
            f = note(chord[0] - 12) * (2 if eighth % 8 == 6 else 1)
            v = lowpass(saw(f, t), 420) * np.exp(-t * 6) * 0.5
            bass[s:s + ln] += v
    bass *= duck
    out[:, 0] += bass; out[:, 1] += bass
    return loop_wrap(out, N)

# D dorian-ish phrase, one note per half bar; None rests. Two eight-bar phrases.
MELODY = [74, None, 72, 69, 77, 76, None, 74, 72, None, 69, 67, 69, None, None, None,
          74, 76, 77, None, 79, 77, 76, 74, 72, 74, None, 69, 67, 65, 64, None]

def lead_stem():
    out = np.zeros(N + TAIL)
    step = BAR / 2
    for i, m in enumerate(MELODY):
        if m is None:
            continue
        s = int(i * step * SR)
        ln = int(step * 1.6 * SR)
        t = np.arange(ln) / SR
        f = note(m)
        # Balatro-ish warble: slow vibrato plus a wobble that drifts the pitch a few cents.
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 2, 0, 1) + 0.004 * np.sin(2 * np.pi * 0.7 * t + i)
        ph = np.cumsum(f * vib) / SR
        tone = 0.6 * np.sin(2 * np.pi * ph + 1.4 * np.sin(2 * np.pi * ph * 2) * np.exp(-t * 3)) + 0.25 * tri(ph * 0.5 + 0.25)
        e = env_adsr(ln, 0.02, 0.3, 0.55, 0.6)
        out[s:s + ln] += lowpass(tone, 2600) * e * 0.5
    st = np.stack([out, out], axis=1)
    # Ping-pong dotted-eighth delay.
    d = int(BEAT * 0.75 * SR)
    for k in range(1, 5):
        g = 0.42 ** k
        st[d * k:, k % 2] += out[:len(out) - d * k] * g
    return loop_wrap(reverb(st, 0.4), N)

def tension_stem():
    out = np.zeros((N + TAIL, 2))
    t = T
    # Minor-second drone high up, with tremolo.
    for f, pan in ((note(86), 0.3), (note(87), 0.7)):
        trem = 0.6 + 0.4 * np.sin(2 * np.pi * 6.0 * t + pan * 3)
        tone = np.sin(2 * np.pi * f * t) * trem * 0.12
        out[:, 0] += tone * (1 - pan); out[:, 1] += tone * pan
    # Reverse swells into every fourth bar.
    for bar in range(0, BARS, 4):
        end = int((bar + 4) * BAR * SR)
        ln = int(2.5 * SR)
        sw = bandpass(rng.standard_normal(ln), 400, 5000) * np.linspace(0, 1, ln) ** 3 * 0.5
        out[end - ln:end, 0] += sw; out[end - ln:end, 1] += sw[::-1] * 0.2 + sw * 0.8
    # Clock ticks on sixteenths, very quiet.
    for six in range(BARS * 16):
        s = int(six * BEAT / 4 * SR)
        tk = bandpass(rng.standard_normal(300), 3000, 8000) * np.exp(-np.arange(300) / 40.0) * (0.25 if six % 4 == 0 else 0.1)
        out[s:s + 300, six % 2] += tk
    return loop_wrap(reverb(out, 0.3), N)

# ---------------------------------------------------------------------------- effects
def bell(f, length, decay=6.0, ratio=3.5, index=2.0):
    t = t_axis(length)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t * decay * 1.5)
    return np.sin(2 * np.pi * f * t + mod) * np.exp(-t * decay)

def effects():
    fx = {}
    t = t_axis(0.03)
    fx["hover"] = np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 180) * 0.6 + highpass(rng.standard_normal(len(t)), 5000) * np.exp(-t * 400) * 0.2
    t = t_axis(0.08)
    f = 620 * np.exp(-t * 18) + 280
    fx["press"] = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 55) + highpass(rng.standard_normal(len(t)), 3000) * np.exp(-t * 600) * 0.3
    t = t_axis(0.035)
    fx["click"] = np.sin(2 * np.pi * 1400 * t) * np.exp(-t * 160) * 0.7
    t = t_axis(0.16)
    whoosh = bandpass(rng.standard_normal(len(t)), 500, 3500) * np.sin(np.pi * t / t[-1]) ** 2
    fx["pick"] = whoosh * 0.6 + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 60) * 0.25
    t = t_axis(0.2)
    thunk = np.sin(2 * np.pi * np.cumsum(150 * np.exp(-t * 10) + 70) / SR) * np.exp(-t * 22)
    fx["drop"] = thunk + bandpass(rng.standard_normal(len(t)), 200, 1200) * np.exp(-t * 80) * 0.5 + np.sin(2 * np.pi * 320 * t) * np.exp(-t * 40) * 0.3
    a = bell(note(88), 0.5, 7)
    b = np.pad(bell(note(95), 0.45, 7), (int(0.06 * SR), 0))[: len(a)]
    fx["slot"] = (a * 0.6 + b * 0.5)
    t = t_axis(0.18)
    f = 420 - 140 * (t / t[-1])
    fx["reject"] = lowpass(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)), 1200) * np.exp(-t * 14) * 0.6
    t = t_axis(0.6)
    boom = np.sin(2 * np.pi * np.cumsum(45 + 80 * np.exp(-t * 25)) / SR) * np.exp(-t * 6)
    slap = bandpass(rng.standard_normal(len(t)), 900, 3500) * np.exp(-t * 45)
    fx["stamp"] = reverb(boom + slap * 0.8 + np.sin(2 * np.pi * 180 * t) * np.exp(-t * 30) * 0.4, 0.2)[:, 0]
    sparkle = np.zeros(int(0.55 * SR))
    for k, m in enumerate([84, 88, 91, 96]):
        s = int(k * 0.045 * SR)
        b = bell(note(m), 0.4, 9, ratio=2.0, index=1.2)
        sparkle[s:s + len(b)] += b[: len(sparkle) - s] * (0.5 - k * 0.07)
    fx["coin"] = sparkle + np.pad(bell(note(79), 0.3, 12), (0, len(sparkle) - int(0.3 * SR))) * 0.4
    t = t_axis(0.22)
    tone = np.sin(2 * np.pi * 520 * t) * (t < 0.08) + np.sin(2 * np.pi * 390 * t) * (t >= 0.1)
    fx["spend"] = lowpass(tone, 2000) * np.exp(-((t % 0.1) * 30)) * 0.5
    t = t_axis(0.018)
    fx["type"] = highpass(rng.standard_normal(len(t)), 2500) * np.exp(-t * 300) * 0.5
    t = t_axis(0.45)
    noise = rng.standard_normal(len(t))
    crushed = np.round(noise * 3) / 3 * (np.sin(2 * np.pi * 37 * t) > 0)
    ring = np.sin(2 * np.pi * 900 * t) * np.sin(2 * np.pi * 63 * t)
    stutter = (np.floor(t * 28) % 2)
    fx["glitch"] = (crushed * 0.5 + ring * 0.4) * stutter * np.exp(-t * 4)
    t = t_axis(0.7)
    swell = bandpass(rng.standard_normal(len(t)), 300, 6000) * (t / t[-1]) ** 2.5
    fx["withdraw"] = reverb(swell + np.sin(2 * np.pi * np.cumsum(200 + 900 * (t / t[-1]) ** 2) / SR) * (t / t[-1]) ** 2 * 0.4, 0.3)[:, 0][::-1][::-1]
    shimmer = np.zeros(int(1.1 * SR))
    for k, m in enumerate([74, 81, 86, 89, 93]):
        s = int(k * 0.07 * SR)
        b = bell(note(m), 0.8, 4.5, ratio=2.01, index=0.8)
        shimmer[s:s + len(b)] += b[: len(shimmer) - s] * 0.35
    fx["reveal"] = reverb(shimmer, 0.35)[:, 0]
    t = t_axis(0.06)
    fx["sign_hold"] = np.sin(2 * np.pi * 660 * t) * np.exp(-t * 45) * 0.6
    t = t_axis(0.3)
    fx["error"] = lowpass(signal.square(2 * np.pi * 110 * t), 900) * np.exp(-t * 8) * 0.5
    t = t_axis(0.2)
    pop = np.sin(2 * np.pi * np.cumsum(1400 * np.exp(-t * 40) + 500) / SR) * np.exp(-t * 30)
    fx["combo"] = pop * 0.6 + bell(note(84), 0.2, 14) * 0.5
    t = t_axis(0.22)
    fx["miss"] = np.sin(2 * np.pi * 95 * t) * np.exp(-t * 18) + lowpass(signal.sawtooth(2 * np.pi * 116 * t), 700) * np.exp(-t * 12) * 0.3
    t = t_axis(1.8)
    boom = np.sin(2 * np.pi * np.cumsum(38 + 60 * np.exp(-t * 12)) / SR) * np.exp(-t * 2.5)
    fx["beat"] = reverb(boom + bell(note(62), 1.8, 1.6, ratio=1.5, index=1.5) * 0.35 + bandpass(rng.standard_normal(len(t)), 2000, 8000) * np.exp(-t * 18) * 0.3, 0.35)[:, 0]
    t = t_axis(1.2)
    f = 900 * np.exp(-t * 2.4) + 40
    fx["reboot"] = lowpass(signal.sawtooth(2 * np.pi * np.cumsum(f) / SR), 2400) * (1 - t / t[-1]) * 0.6 + bandpass(rng.standard_normal(len(t)), 1000, 5000) * (1 - t / t[-1]) * 0.25
    t = t_axis(0.3)
    fx["scan"] = np.sin(2 * np.pi * np.cumsum(800 + 1200 * t / t[-1]) / SR) * np.sin(np.pi * t / t[-1]) * 0.5
    t = t_axis(1.0)
    chord = sum(np.sin(2 * np.pi * note(m) * t * (1 - 0.06 * t)) for m in (62, 65, 69)) / 3
    fx["forget"] = np.round(chord * (1 - t) * 6) / 6 * 0.6
    t = t_axis(0.6)
    thump = lambda o: np.sin(2 * np.pi * 52 * (t - o)) * np.exp(-np.clip(t - o, 0, None) * 18) * (t >= o)
    fx["heart"] = thump(0.0) + thump(0.18) * 0.7
    return fx

if __name__ == "__main__":
    write("music_base", base_stem(), stereo=True)
    write("music_pulse", pulse_stem(), stereo=True)
    write("music_lead", lead_stem(), stereo=True)
    write("music_tension", tension_stem(), stereo=True)
    for name, data in effects().items():
        write(name, data)
    print("wrote", len(list(OUT.glob("*.wav"))), "files to", OUT)
