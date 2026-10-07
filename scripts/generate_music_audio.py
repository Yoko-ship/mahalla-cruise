#!/usr/bin/env python3
"""Generate the original music loop and Damas horn using only Python's standard library."""

import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
RATE = 22050
BPM = 100
BEAT = 60 / BPM
BARS = 8
# D-based scale with a raised third, common in Central Asian melodies (MIDI numbers).
SCALE = [62, 63, 66, 67, 69, 70, 72, 74]
# Eighth-note scale degrees per bar; None is a rest. Hand-written, not random.
MELODY = [
    [0, None, 2, 3, 4, 3, 2, None],
    [3, 4, 5, 4, 3, None, 2, None],
    [0, None, 2, 3, 4, 5, 6, 7],
    [6, 5, 4, None, 3, 2, 1, None],
    [4, None, 4, 5, 6, 5, 4, None],
    [3, 4, 3, 2, 1, None, 0, None],
    [2, 3, 4, None, 5, 4, 3, 2],
    [1, 2, 1, 0, None, None, 0, None],
]
# Doira pattern per beat: "dum" on 1 and 3, "tak" on the off-beats.
DRUMS = [("dum", 0.0), ("tak", 0.5), ("tak", 1.5), ("dum", 2.0), ("tak", 2.75), ("tak", 3.5)]


def midi_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def pluck(frequency, duration, gain, noise):
    """Karplus-Strong plucked string, close to a dutar."""
    period = max(2, round(RATE / frequency))
    ring = [noise.uniform(-1.0, 1.0) for _ in range(period)]
    out = []
    for index in range(round(duration * RATE)):
        value = ring[index % period]
        following = ring[(index + 1) % period]
        ring[index % period] = 0.497 * (value + following)
        out.append(gain * value)
    return out


def drum(kind, noise):
    out = []
    length = 0.22 if kind == "dum" else 0.08
    for index in range(round(length * RATE)):
        time = index / RATE
        if kind == "dum":
            value = math.sin(math.tau * (95 - 40 * time / length) * time) * math.exp(-time / 0.07)
            out.append(0.9 * value)
        else:
            out.append(0.35 * noise.uniform(-1.0, 1.0) * math.exp(-time / 0.018))
    return out


def mix_into(track, start, samples):
    offset = round(start * RATE)
    for index, value in enumerate(samples):
        if 0 <= offset + index < len(track):
            track[offset + index] += value


def render_loop():
    noise = random.Random(1991)
    loop = BARS * 4 * BEAT
    # Three repetitions; the middle one already contains the previous loop's tails.
    track = [0.0] * round(loop * 3 * RATE)
    for repeat in range(3):
        base = repeat * loop
        for bar, notes in enumerate(MELODY):
            bar_start = base + bar * 4 * BEAT
            mix_into(track, bar_start, pluck(midi_hz(SCALE[0] - 24), 4 * BEAT, 0.35, noise))
            for step, degree in enumerate(notes):
                if degree is not None:
                    note = pluck(midi_hz(SCALE[degree]), 1.2, 0.55, noise)
                    mix_into(track, bar_start + step * BEAT / 2, note)
            for kind, beat in DRUMS:
                mix_into(track, bar_start + beat * BEAT, drum(kind, noise))
    start = round(loop * RATE)
    return track[start : start + round(loop * RATE)]


def horn():
    out = []
    duration = 0.34
    for index in range(round(duration * RATE)):
        time = index / RATE
        envelope = min(1.0, time / 0.01) * min(1.0, (duration - time) / 0.04)
        value = 0.0
        for frequency in (415.0, 495.0):
            phase = (frequency * time) % 1.0
            value += 0.5 * (1.0 if phase < 0.5 else -1.0) + 0.3 * (2 * phase - 1)
        out.append(envelope * value)
    return out


def write(name, samples, peak_level):
    peak = max(abs(value) for value in samples) or 1.0
    pcm = b"".join(struct.pack("<h", round(v / peak * peak_level * 32767)) for v in samples)
    output = ROOT / "assets/audio" / name
    with wave.open(str(output), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(RATE)
        sound.writeframes(pcm)
    print(f"Generated {output.relative_to(ROOT)} ({len(samples) / RATE:.2f}s)")


if __name__ == "__main__":
    write("mahalla_loop.wav", render_loop(), 0.6)
    write("damas_horn.wav", horn(), 0.5)
