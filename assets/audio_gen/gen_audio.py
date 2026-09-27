#!/usr/bin/env python3
"""Generate the game's calm, royalty-free audio assets from scratch.

Everything here is synthesized with plain math (layered detuned sine /
triangle-ish waves) — no samples, no copyrighted material. Re-run any time
to tweak the soundscape:

    python3 assets/audio_gen/gen_audio.py

Assets produced (mono, 22050 Hz):
    assets/audio/ambient_loop.ogg  ~72 s seamless ambient pad loop
    assets/audio/place.wav          quiet soft "tock" on piece placement
    assets/audio/clear.wav          warm swelling chime on line clear
                                    (pitched up in-game per combo level)
    assets/audio/gameover.wav       soft low tone for game over
    assets/audio/tap.wav            feather-light UI tick

The ambient loop is first rendered as WAV, then encoded to OGG Vorbis with
ffmpeg for size. SFX stay as tiny WAVs.
"""

import math
import os
import struct
import subprocess
import wave

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "audio"))


def write_wav(name, samples):
    path = os.path.join(OUT_DIR, name)
    os.makedirs(OUT_DIR, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.85 / peak
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * gain)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples) / SR:.2f}s)")
    return path


def sine(freq, t):
    return math.sin(2.0 * math.pi * freq * t)


# ------------------------------------------------------------------ ambient

# Warm, slow progression (each chord gets 18 s):
#   Am9 -> Fmaj9 -> Cmaj9 -> G6/9. No beats, no melody hooks.
CHORDS = [
    [110.00, 164.81, 196.00, 246.94, 261.63],  # Am9
    [87.31, 130.81, 164.81, 196.00, 220.00],   # Fmaj9
    [130.81, 196.00, 246.94, 293.66, 329.63],  # Cmaj9
    [98.00, 146.83, 220.00, 246.94, 329.63],   # G6/9
]
CHORD_DUR = 18.0
LOOP_DUR = CHORD_DUR * len(CHORDS)  # 72 s


def pad_note(freq, t, attack=5.0, release=5.0, dur=CHORD_DUR):
    """One soft pad voice: detuned sine pair + gentle harmonics."""
    v = 0.0
    for cents in (-4.0, 4.0):  # slow-beating detune for airiness
        f = freq * (2.0 ** (cents / 1200.0))
        v += sine(f, t)
    v *= 0.5
    v += 0.22 * sine(freq * 2.0, t) + 0.08 * sine(freq * 3.0, t)
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return v * a * a * r * r  # slow, gentle swells


def gen_ambient():
    # Render the progression plus the first chord once more (8 s tail) so
    # we can crossfade the tail into the head for a seamless loop.
    total = int((LOOP_DUR + 8.0) * SR)
    samples = [0.0] * total
    seq = CHORDS + [CHORDS[0]]
    for i, chord in enumerate(seq):
        start = int(i * CHORD_DUR * SR)
        n = int(CHORD_DUR * SR)
        for f in chord:
            for j in range(n):
                idx = start + j
                if idx < total:
                    samples[idx] += pad_note(f, j / SR) / len(chord)
    # Slow "breathing" LFO. Exactly 3 cycles per loop so the loop point
    # stays seamless.
    lfo_hz = 3.0 / LOOP_DUR
    for i in range(total):
        t = i / SR
        samples[i] *= 1.0 + 0.12 * math.sin(2.0 * math.pi * lfo_hz * t)
    # Equal-power crossfade: last 8 s (re-rendered chord 1) into first 8 s.
    loop_n = int(LOOP_DUR * SR)
    xf_n = int(8.0 * SR)
    out = samples[:loop_n]
    for i in range(xf_n):
        k = i / xf_n
        g_out = math.cos(k * math.pi / 2.0) ** 2
        g_in = math.sin(k * math.pi / 2.0) ** 2
        out[i] = out[i] * g_out + samples[loop_n + i] * g_in
    return out


# --------------------------------------------------------------------- sfx


def gen_place():
    """Quiet soft tock: short sine burst, fast decay."""
    n = int(0.14 * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / 0.028)
        v = sine(620.0, t) * 0.7 + sine(1240.0, t) * 0.25
        out.append(v * env * 0.6)
    return out


def gen_clear():
    """Warm swelling chime (E5 + harmonics). In-game it is pitched up
    with playbackRate as the combo streak grows."""
    n = int(1.6 * SR)
    out = []
    for i in range(n):
        t = i / SR
        atk = min(1.0, t / 0.09)
        env = atk * math.exp(-t / 0.55)
        v = sine(659.26, t) + 0.4 * sine(987.77, t) + 0.18 * sine(1318.5, t)
        out.append(v * env * 0.5)
    return out


def gen_gameover():
    """Soft low tone with a slow bloom and long release."""
    dur = 2.4
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        atk = min(1.0, t / 0.45)
        rel = min(1.0, (dur - t) / 1.3)
        env = atk * atk * rel * rel
        v = sine(196.0, t) * 0.7 + sine(293.66, t) * 0.35 + sine(392.0, t) * 0.15
        out.append(v * env * 0.55)
    return out


def gen_tap():
    """Feather-light UI tick."""
    n = int(0.07 * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / 0.016)
        out.append(sine(880.0, t) * env * 0.45)
    return out


# --------------------------------------------------------------------- main


def encode_ogg(wav_path, ogg_name):
    ogg_path = os.path.join(OUT_DIR, ogg_name)
    try:
        subprocess.run(
            [
                "ffmpeg", "-y", "-v", "error",
                "-i", wav_path,
                "-c:a", "libvorbis", "-q:a", "4",
                ogg_path,
            ],
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"ffmpeg ogg encode failed ({e}); keeping WAV")
        return wav_path
    os.remove(wav_path)
    size_kb = os.path.getsize(ogg_path) / 1024
    print(f"encoded {ogg_path} ({size_kb:.0f} KB)")
    return ogg_path


def main():
    ambient_wav = write_wav("ambient_loop.wav", gen_ambient())
    write_wav("place.wav", gen_place())
    write_wav("clear.wav", gen_clear())
    write_wav("gameover.wav", gen_gameover())
    write_wav("tap.wav", gen_tap())

    final_ambient = encode_ogg(ambient_wav, "ambient_loop.ogg")

    total_kb = 0
    for name in sorted(os.listdir(OUT_DIR)):
        kb = os.path.getsize(os.path.join(OUT_DIR, name)) / 1024
        total_kb += kb
        print(f"  {name}: {kb:.1f} KB")
    print(f"total audio: {total_kb / 1024:.2f} MB")
    print(f"ambient asset to reference: {os.path.basename(final_ambient)}")


if __name__ == "__main__":
    main()
