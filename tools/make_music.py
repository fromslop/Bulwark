"""Cut the Ableton stems into the game's music files (assets/music/*.ogg).

    python tools/make_music.py "<folder with the Live export>" [--cinder A-amb-Cinder.wav] [--tunnel A-amb-tunnel.wav]

The export is one pass of "All Individual Tracks" from 1.1.1, 118 bars, 44.1 kHz float
(see "EXPORT FOR BULWARK.txt" in the Live project). Everything below is in beats at 120 BPM,
so a beat is exactly 0.5 s and a bar 2 s. scripts/music.gd assumes the same grid.

- base_bass / base_pluck: bars 1-61 as one loop; the 4 bars after the loop (reverb tails,
  the last notes ringing) are folded back onto the start so the seam is seamless.
- drum_kick / drum_full / drum_claps: 4-bar windows cut from the middle of each section of
  the arrangement, where the previous bar's tails are already ringing into it, so the cut
  loops on its own. Each is one 1-bar pattern four times, so any bar can bring it in.
- lead_*: each guitar clip from its 8-bar slot, starting PRE_ROLL early (so the
  game can start it a hair early and land the downbeat exactly) and the tail kept.
- amb_cinder / amb_tunnel: the ambience recordings looped with an equal-power crossfade.

One gain is applied to all the music files together, so your mix between tracks survives;
it just keeps the loudest peak under -1 dBFS.
"""
import argparse, os, sys
import numpy as np
import soundfile as sf

SR = 44100
BEAT = SR // 2  # 120 BPM
BAR = 4 * BEAT
PRE_ROLL = int(0.05 * SR)  # must match Music.PRE_ROLL
LOOP_BEATS = 244  # bars 1-61
TAIL_BEATS = 16

# (output name, track name in the export file, slot start bar)
LEADS = [("lead_forge", 71), ("lead_battle", 79), ("lead_minstrel", 87),
         ("lead_bridge", 95), ("lead_arp_a", 103), ("lead_arp_b", 111)]
# (output name, track, first beat of the 4-bar window)
DRUMS = [("drum_kick", "4-Halfstep Kit", 96), ("drum_full", "4-Halfstep Kit", 128),
         ("drum_claps", "5-Halfstep Kit", 200)]


def find(folder, track):
    hits = [f for f in os.listdir(folder) if f.lower().endswith(".wav") and track.lower() in f.lower()]
    if len(hits) != 1:
        sys.exit(f"expected one WAV for '{track}' in {folder}, found {hits}")
    data, sr = sf.read(os.path.join(folder, hits[0]), dtype="float32", always_2d=True)
    if sr != SR:
        sys.exit(f"{hits[0]} is {sr} Hz; export at {SR}")
    return data


def take(data, start, length):
    out = np.zeros((length, data.shape[1]), np.float32)
    chunk = data[start:start + length]
    out[:len(chunk)] = chunk
    return out


def seam(loop, n=64):
    """A few-sample crossfade of the end into the start, for windows that are steady-state cuts."""
    ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    head = loop[:n].copy()
    loop[:n] = head * ramp + loop[-n:] * (1.0 - ramp)
    return loop


def trim_tail(x, floor_db=-70.0):
    level = np.abs(x).max(axis=1)
    loud = np.nonzero(level > 10 ** (floor_db / 20))[0]
    end = min(len(x), (loud[-1] + SR // 10) if len(loud) else len(x))
    x = x[:end].copy()
    fade = min(SR // 10, len(x))
    x[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)[:, None]
    return x


def ambience_loop(path, xfade_s=4.0):
    data, sr = sf.read(path, dtype="float32", always_2d=True)
    if sr != SR:
        sys.exit(f"{path} is {sr} Hz; expected {SR}")
    n = int(xfade_s * SR)
    body, tail = data[:-n], data[-n:]
    t = np.linspace(0.0, np.pi / 2, n, dtype=np.float32)[:, None]
    body = body.copy()
    body[:n] = body[:n] * np.sin(t) + tail * np.cos(t)  # the end fades into the start
    return body


def write_ogg(path, x):
    # libsndfile's Vorbis encoder overflows the stack on one big write, so feed it in blocks
    with sf.SoundFile(path, "w", SR, x.shape[1], format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(x), 8192):
            f.write(x[i:i + 8192])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stems")
    ap.add_argument("--cinder", default=os.path.expanduser("~/Desktop/Ableton/exports/A-amb-Cinder.wav"))
    ap.add_argument("--tunnel", default=os.path.expanduser("~/Desktop/A-amb-tunnel.wav"))
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "assets", "music"))
    a = ap.parse_args()

    music = {}
    for name, track in [("base_bass", "3-Thick Bass"), ("base_pluck", "7-Basic Pluck Arp")]:
        d = find(a.stems, track)
        loop = take(d, 0, LOOP_BEATS * BEAT)
        loop[:TAIL_BEATS * BEAT] += take(d, LOOP_BEATS * BEAT, TAIL_BEATS * BEAT)
        music[name] = loop
    for name, track, beat in DRUMS:
        music[name] = seam(take(find(a.stems, track), beat * BEAT, 16 * BEAT))
    guitar = find(a.stems, "6-Guitar Electric Clean")
    for name, bar in LEADS:
        # from PRE_ROLL before the downbeat: the pick's attack starts a hair early, and the
        # window stops short of the next slot's own early attack
        music[name] = trim_tail(take(guitar, (bar - 1) * BAR - PRE_ROLL, 8 * BAR))

    peak = max(float(np.abs(x).max()) for x in music.values())
    gain = min(1.0, 10 ** (-1 / 20) / max(peak, 1e-9))
    os.makedirs(a.out, exist_ok=True)
    print(f"music peak {20 * np.log10(peak):+.1f} dBFS, gain {20 * np.log10(gain):+.1f} dB")
    for name, x in music.items():
        write_ogg(os.path.join(a.out, name + ".ogg"), x * gain)
        print(f"  {name}.ogg  {len(x) / SR:7.2f} s")
    for name, path in [("amb_cinder", a.cinder), ("amb_tunnel", a.tunnel)]:
        if os.path.exists(path):
            x = ambience_loop(path)
            write_ogg(os.path.join(a.out, name + ".ogg"), x)
            print(f"  {name}.ogg  {len(x) / SR:7.2f} s")
        else:
            print(f"  skipped {name}: {path} not found")


if __name__ == "__main__":
    main()
