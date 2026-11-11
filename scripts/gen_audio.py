#!/usr/bin/env python3
"""Synthesises the built-in sound set of NOIR LEDGER (effects, rain bed, music loop) into App/Resources/Audio.

Everything is generated from formulas in this file: no samples, no third-party material, no licence to track.
Run it again after changing a sound; a better recording with the same file name simply replaces the synthetic one.
"""
import pathlib
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "App" / "Resources" / "Audio"
rng = np.random.default_rng(1936)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack=0.004, decay=6.0):
    x = np.arange(n) / SR
    return np.minimum(1, x / max(attack, 1e-6)) * np.exp(-decay * x)


def tone(freq, seconds, decay=6.0, attack=0.004, harmonics=(1.0, 0.35, 0.12)):
    x = t(seconds)
    y = sum(a * np.sin(2 * np.pi * freq * (i + 1) * x) for i, a in enumerate(harmonics))
    return y * env(len(x), attack, decay)


def noise(seconds, smooth=1):
    y = rng.standard_normal(int(SR * seconds))
    if smooth > 1:
        y = np.convolve(y, np.ones(smooth) / smooth, mode="same")
    return y


def mix(*parts):
    """Each part is (offset seconds, samples)."""
    n = max(int(o * SR) + len(y) for o, y in parts)
    out = np.zeros(n)
    for o, y in parts:
        i = int(o * SR)
        out[i:i + len(y)] += y
    return out


def save(name, y, peak=0.85):
    y = np.asarray(y, dtype=float)
    m = np.max(np.abs(y))
    if m > 0:
        y = y / m * peak
    fade = min(len(y) // 2, int(0.004 * SR))
    if fade:
        y[-fade:] *= np.linspace(1, 0, fade)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype("<i2").tobytes())


def sweep(f0, f1, seconds, decay=3.0):
    x = t(seconds)
    f = f0 + (f1 - f0) * (x / seconds)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.01, decay)


def effects():
    save("sfx_tap", mix((0, noise(0.02, 3) * env(int(0.02 * SR), 0.001, 160)), (0, tone(880, 0.06, 55) * 0.6)), 0.6)
    save("sfx_batch", mix((0, tone(110, 0.12, 30, harmonics=(1, 0.5))), (0, noise(0.03, 8) * env(int(0.03 * SR), 0.001, 90) * 0.4)), 0.6)
    save("sfx_buy", mix((0, tone(1318, 0.16, 22)), (0.06, tone(1976, 0.22, 16))), 0.7)
    save("sfx_reject", mix((0, np.sign(np.sin(2 * np.pi * 130 * t(0.16))) * env(int(0.16 * SR), 0.005, 14) * 0.5),
                           (0, tone(98, 0.16, 12))), 0.55)
    save("sfx_claim", mix((0, tone(784, 0.3, 9)), (0.09, tone(1175, 0.45, 7))), 0.75)
    save("sfx_boost", mix((0, sweep(300, 1400, 0.42, 2.5)), (0.3, tone(1568, 0.35, 9) * 0.6)), 0.7)
    save("sfx_decision", mix(*[(o, noise(0.06, 2) * env(int(0.06 * SR), 0.004, 45) * a)
                               for o, a in ((0, 1), (0.07, 0.6), (0.16, 0.9), (0.24, 0.5))]), 0.5)
    bell = [523.25, 659.25, 783.99, 1046.5]
    save("sfx_milestone", mix(*[(i * 0.09, tone(f, 0.9, 4.5)) for i, f in enumerate(bell)],
                              (0.36, tone(1568, 0.9, 4) * 0.5)), 0.85)
    save("sfx_purchase", mix((0, tone(2093, 0.5, 7, harmonics=(1, 0.6, 0.3, 0.2))), (0.05, tone(2637, 0.5, 8) * 0.7),
                             (0.18, noise(0.05, 2) * env(int(0.05 * SR), 0.002, 70) * 0.5), (0.22, tone(1318, 0.4, 9) * 0.6)), 0.8)
    chord = [220.0, 261.63, 329.63, 493.88]
    save("sfx_chapter", mix((0, tone(55, 0.35, 14, harmonics=(1, 0.6)) * 1.4), (0, noise(0.05, 10) * env(int(0.05 * SR), 0.001, 60)),
                            *[(0.08 + i * 0.03, tone(f, 1.6, 2.6, attack=0.01)) for i, f in enumerate(chord)]), 0.85)
    save("sfx_prestige", mix((0, noise(1.2, 30) * np.linspace(0, 1, int(1.2 * SR)) ** 2 * 0.5), (0, sweep(110, 880, 1.2, 0.2) * 0.4),
                             *[(1.15 + i * 0.05, tone(f, 1.4, 2.4)) for i, f in enumerate([440.0, 554.37, 659.25, 880.0])]), 0.85)
    save("sfx_raid", mix((0, tone(46, 1.1, 3.2, harmonics=(1, 0.7, 0.3)) * 1.6), (0, noise(0.5, 12) * env(int(0.5 * SR), 0.002, 7)),
                         (0.25, sweep(700, 180, 0.8, 2.2) * 0.35)), 0.9)
    x = t(0.9)
    siren = np.sin(2 * np.pi * np.cumsum(520 + 90 * np.sign(np.sin(2 * np.pi * 2.2 * x))) / SR)
    save("sfx_alarm", siren * np.minimum(1, x / 0.03) * np.minimum(1, (0.9 - x) / 0.2) + tone(65, 0.9, 3) * 0.6, 0.6)


def loopable(y, cross):
    """Cross-fades the tail into the head so the buffer loops without a seam."""
    n = int(cross * SR)
    head, tail = y[:n], y[-n:]
    ramp = np.linspace(0, 1, n)
    y = y[:-n].copy()
    y[:n] = head * ramp + tail * (1 - ramp)
    return y


def rain():
    seconds = 9.0
    hiss = noise(seconds, 2) - noise(seconds, 40)
    rumble = noise(seconds, 400) * 6
    drops = np.zeros(int(seconds * SR))
    for _ in range(260):
        i = rng.integers(0, len(drops) - 400)
        f = rng.uniform(1800, 5200)
        d = np.sin(2 * np.pi * f * t(0.012)) * env(int(0.012 * SR), 0.0005, 400)
        drops[i:i + len(d)] += d * rng.uniform(0.15, 0.6)
    save("amb_rain", loopable(hiss * 0.5 + rumble + drops, 1.0), 0.5)


def music():
    """Eight slow bars in A minor: electric-piano chords, a walking bass and brushed time. Loops seamlessly."""
    bpm = 72
    beat = 60 / bpm
    bars = 8
    n = int(bars * 4 * beat * SR)
    out = np.zeros(n)

    def put(offset, y, gain=1.0):
        i = int(offset * SR) % n
        idx = (i + np.arange(len(y))) % n
        np.add.at(out, idx, y * gain)

    def hz(midi):
        return 440 * 2 ** ((midi - 69) / 12)

    chords = [  # (root for the bass, chord tones)
        (45, [57, 60, 64, 67]),   # Am7
        (50, [57, 60, 65, 69]),   # Dm7
        (41, [57, 60, 64, 65]),   # Fmaj7
        (40, [56, 59, 62, 64]),   # E7
    ]
    for bar in range(bars):
        root, tones = chords[bar % 4]
        start = bar * 4 * beat
        for hit, length in ((0, 2.6), (2.5, 1.4)):
            for k, m in enumerate(tones):
                y = tone(hz(m), length * beat, 1.6 / beat, attack=0.012, harmonics=(1, 0.45, 0.08, 0.05))
                trem = 1 + 0.12 * np.sin(2 * np.pi * 4.6 * np.arange(len(y)) / SR + k)
                put(start + hit * beat + k * 0.012, y * trem, 0.16)
        walk = [root, root + 7, root + 12, root + 10] if bar % 2 == 0 else [root, root + 3, root + 7, root + 11]
        for b, m in enumerate(walk):
            put(start + b * beat, tone(hz(m), beat * 0.95, 4.5, attack=0.008, harmonics=(1, 0.5, 0.15)), 0.5)
        for b in range(4):
            put(start + b * beat, noise(0.09, 2) * env(int(0.09 * SR), 0.01, 38), 0.05)
            put(start + (b + 2 / 3) * beat, noise(0.05, 2) * env(int(0.05 * SR), 0.004, 70), 0.035)
        if bar % 2 == 1:
            lead = [76, 72, 69, 71] if bar % 4 == 1 else [72, 71, 69, 64]
            for b, m in enumerate(lead):
                put(start + (b + 0.5) * beat, tone(hz(m), beat * 1.4, 3.0, attack=0.03, harmonics=(1, 0.2)), 0.1)
    crackle = np.zeros(n)
    for _ in range(140):
        crackle[rng.integers(0, n)] = rng.uniform(-1, 1)
    out += np.convolve(crackle, np.ones(3) / 3, mode="same") * 0.05
    save("music_main", out, 0.7)


if __name__ == "__main__":
    effects()
    rain()
    music()
    for f in sorted(OUT.glob("*.wav")):
        print(f"{f.name}: {f.stat().st_size // 1024} KiB")
