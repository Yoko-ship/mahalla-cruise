#!/usr/bin/env python3
"""Generate original pickup chimes and the close-call whoosh using only Python's stdlib."""

import math
import random
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100


def write_chime(name, notes, duration):
    samples = []
    for index in range(round(duration * RATE)):
        time = index / RATE
        value = 0.0
        for start, frequency, gain in notes:
            elapsed = time - start
            if elapsed < 0:
                continue
            attack = min(1.0, elapsed / 0.004)
            tail = max(0.0, min(1.0, (duration - time) / 0.025))
            envelope = attack * math.exp(-elapsed / 0.065) * tail
            tone = math.sin(math.tau * frequency * elapsed)
            tone += 0.16 * math.sin(math.tau * frequency * 2 * elapsed)
            value += gain * envelope * tone
        samples.append(value)
    write_samples(name, samples, duration)


def write_whoosh(name, duration):
    """Filtered noise sweeping upward with a soft rising tone: a quick pass-by."""
    noise = random.Random(2026)
    samples = []
    low = 0.0
    phase = 0.0
    for index in range(round(duration * RATE)):
        progress = index / (duration * RATE)
        # One-pole low-pass whose cutoff opens as the car passes.
        cutoff = 0.02 + 0.22 * progress
        low += cutoff * (noise.uniform(-1.0, 1.0) - low)
        phase += math.tau * (420 + 680 * progress * progress) / RATE
        envelope = math.sin(math.pi * progress) ** 1.6
        samples.append(envelope * (1.6 * low + 0.35 * math.sin(phase)))
    write_samples(name, samples, duration)


def write_samples(name, samples, duration):
    peak = max(abs(value) for value in samples)
    # Leave headroom for overlapping pickups; runtime volume is lower still.
    pcm = b"".join(struct.pack("<h", round(value / peak * 0.55 * 32767)) for value in samples)
    output = ROOT / "assets/audio" / name
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(RATE)
        sound.writeframes(pcm)
    print(f"Generated {output.relative_to(ROOT)} ({duration:.2f}s)")


if __name__ == "__main__":
    write_chime("som_pickup.wav", [(0.0, 1046.50, 1.0), (0.045, 1318.51, 0.65)], 0.20)
    write_chime(
        "dollar_pickup.wav",
        [(0.0, 1318.51, 0.8), (0.055, 1567.98, 0.85), (0.11, 2093.00, 0.7)],
        0.30,
    )
    write_whoosh("close_call.wav", 0.28)
