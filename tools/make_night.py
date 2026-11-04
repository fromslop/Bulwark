"""Synthesise the home's night ambience (assets/music/amb_night.ogg): a fire crackling in
the hearth and crickets outside the window, as one seamless stereo loop.

    python tools/make_night.py

No recordings needed: everything is built from noise and sine waves with a fixed seed, so
the file comes out the same every time.
- the fire: a low, slowly breathing roar of filtered noise, plus crackles (short bursts of
  bright noise, mostly small, now and then a louder pop), panned a little left of centre
  like the hearth.
- the crickets: three of them at different pitches and rhythms, out through the window on
  the right, softened as if heard through glass; each chirp is a quick train of pulses.
The loop is built a few seconds long and the tail crossfaded into the head.
"""
import os
import numpy as np
import soundfile as sf

SR = 44100
LENGTH = 48.0  # seconds in the loop
XFADE = 3.0
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music", "amb_night.ogg")


def onepole_lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):  # slow but simple; the loop is short
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def fast_lowpass(x, cutoff):
    # one-pole lowpass via a few passes of a moving average: close enough for noise beds
    w = max(1, int(SR / (cutoff * 2.0)))
    k = np.ones(w) / w
    y = x
    for _ in range(3):
        y = np.convolve(y, k, mode="same")
    return y


def fire(n):
    t = np.arange(n) / SR
    roar = fast_lowpass(rng.standard_normal(n), 180.0)
    roar /= np.max(np.abs(roar)) + 1e-9
    breathe = 0.55 + 0.25 * np.sin(2 * np.pi * 0.11 * t) + 0.2 * np.sin(2 * np.pi * 0.037 * t + 1.3)
    out = roar * breathe * 0.35
    # crackles: Poisson-timed bursts of bright noise
    crackle = np.zeros(n)
    count = rng.poisson(9.0 * n / SR)
    for _ in range(count):
        at = rng.integers(0, n - 4000)
        big = rng.random() < 0.08
        length = int(SR * (rng.uniform(0.02, 0.06) if big else rng.uniform(0.002, 0.012)))
        burst = rng.standard_normal(length)
        burst -= fast_lowpass(burst, 1500.0)  # keep it bright
        env = np.exp(-np.linspace(0, 6 if big else 9, length))
        amp = rng.uniform(0.6, 1.0) if big else rng.uniform(0.05, 0.35)
        crackle[at:at + length] += burst * env * amp
    out += crackle * 0.5
    return out


def cricket(n, pitch, period, pulses, pulse_rate, gain, jitter):
    out = np.zeros(n)
    t = 0.0
    while t < n / SR:
        start = int(t * SR)
        for p in range(pulses):
            ps = start + int(p * SR / pulse_rate)
            plen = int(SR / pulse_rate * 0.55)
            if ps + plen >= n:
                break
            tt = np.arange(plen) / SR
            env = np.sin(np.pi * np.arange(plen) / plen) ** 2
            tone = np.sin(2 * np.pi * pitch * tt) + 0.3 * np.sin(2 * np.pi * pitch * 2.0 * tt)
            out[ps:ps + plen] += tone * env * gain * rng.uniform(0.7, 1.0)
        t += period * rng.uniform(1.0 - jitter, 1.0 + jitter)
    # heard through the window: soften the top
    return fast_lowpass(out, 6000.0)


def main():
    n = int((LENGTH + XFADE) * SR)
    f = fire(n)
    c1 = cricket(n, 4300.0, 0.62, 3, 32.0, 0.05, 0.08)
    c2 = cricket(n, 4750.0, 0.9, 4, 28.0, 0.035, 0.15)
    c3 = cricket(n, 3900.0, 1.4, 2, 36.0, 0.025, 0.25)
    # stereo: the hearth left of centre, the window (and its crickets) to the right
    left = f * 0.85 + c1 * 0.35 + c2 * 0.25 + c3 * 0.55
    right = f * 0.6 + c1 * 0.75 + c2 * 0.8 + c3 * 0.4
    x = np.stack([left, right], axis=1)
    # loop: crossfade the tail into the head (equal power)
    k = int(XFADE * SR)
    body = x[: int(LENGTH * SR)].copy()
    ramp = np.linspace(0.0, 1.0, k)[:, None]
    body[:k] = body[:k] * np.sqrt(ramp) + x[int(LENGTH * SR): int(LENGTH * SR) + k] * np.sqrt(1.0 - ramp)
    body *= 10 ** (-3.0 / 20.0) / (np.max(np.abs(body)) + 1e-9)  # peak at -3 dBFS
    # libsndfile's Vorbis encoder overflows the stack on one big write: feed it in blocks
    with sf.SoundFile(OUT, "w", SR, 2, format="OGG", subtype="VORBIS") as fh:
        for i in range(0, len(body), 8192):
            fh.write(body[i:i + 8192].astype(np.float32))
    print("wrote", os.path.normpath(OUT), "%.1f s" % (len(body) / SR))


if __name__ == "__main__":
    main()
