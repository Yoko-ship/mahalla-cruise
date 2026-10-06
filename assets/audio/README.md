# Pickup Chimes

Original synthesized sounds created for Mahalla Cruise on 2026-10-06.
No recordings, third-party samples, or external packages are used.

- `som_pickup.wav`: 0.20-second two-note chime.
- `dollar_pickup.wav`: 0.30-second brighter three-note chime.

Both files are mono 44.1 kHz, 16-bit PCM WAV. Smooth attacks and tails avoid abrupt
waveform edges. Source peak is 0.55; runtime gain defaults to -8 dB.

Regenerate with `python3 scripts/generate_pickup_audio.py`. The generator uses
Python's standard library and is the editable source for these assets.

`src/pickups/pickup_feedback.tscn` owns two bounded audio players.
`default_feedback.tres` stores gain, the 80 ms burst limit, and 16/26 ms
vibration durations at 0.25 strength. Runtime toggles never mutate this resource.
Crash, restart, and focus loss stop playback.

Android export enables VIBRATE, as required by
[Godot's vibration API](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-vibrate-handheld).
See also [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)
for bounded playback. Physical vibration strength requires testing on a phone.
