# Pickup Chimes

Original synthesized sounds created for Mahalla Cruise on 2026-10-06.
No recordings, third-party samples, or external packages are used.

- `som_pickup.wav`: 0.20-second two-note chime.
- `dollar_pickup.wav`: 0.30-second brighter three-note chime.
- `mahalla_loop.wav`: 19.2-second seamless music loop (Karplus-Strong plucked
  melody, drone, and doira-style drums), 22.05 kHz; imported with forward looping.
- `damas_horn.wav`: 0.34-second two-tone horn.
- `close_call.wav`: 0.28-second rising filtered-noise whoosh for near misses.
  Runtime pitch rises 6% per combo step; Android adds a 12 ms pulse.
- `bump.wav`: 0.22-second low falling thud with a short noise rattle for potholes
  and road works; Android adds a 40 ms pulse.
- `camera_flash.wav`: 0.18-second speed-camera shutter: two noise clicks over a short
  rising flash whine, played with a speeding fine.
- `police_whistle.wav`: 0.48-second pea whistle (2.9 kHz tone warbling at 31 Hz) in two
  short blasts, played when a GAI officer fines a driver who did not stop.

The pickup files are mono 44.1 kHz, 16-bit PCM WAV. Smooth attacks and tails avoid abrupt
waveform edges. Source peak is 0.55; runtime gain defaults to -8 dB.

Regenerate with `python3 scripts/generate_pickup_audio.py` and
`python3 scripts/generate_music_audio.py`. The generator uses
Python's standard library and is the editable source for these assets.

`src/pickups/pickup_feedback.tscn` owns two bounded audio players.
`default_feedback.tres` stores gain, the 80 ms burst limit, and 16/26 ms
vibration durations at 0.25 strength. Runtime toggles never mutate this resource.
Crash, restart, and focus loss stop playback.

Android export enables VIBRATE, as required by
[Godot's vibration API](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-vibrate-handheld).
See also [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)
for bounded playback. Physical vibration strength requires testing on a phone.
