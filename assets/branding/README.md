# Boot presentation

`boot_splash.png` is rendered from the original geometric `assets/icon.svg`,
Godot's bundled fallback font, and the menu palette. It introduces Mahalla Cruise
while the engine initializes. It contains no button, percentage, or localized
instruction. The name is the same in each supported language.

Rebuild it from the repository root with the pinned engine:

```sh
./scripts/godot.sh --path . --script scripts/render_boot_splash.gd
```

This uses a temporary rendering window and writes the 1024 × 1024 PNG. It does not
load the game or read/write player progress. On Windows, the equivalent command is
`.venv/Scripts/python.exe scripts/godot.py --path . --script scripts/render_boot_splash.gd`.

Godot's boot image requires PNG; the generator preserves the editable vector and
native text source. The background matches `application/boot_splash/bg_color` so
other aspect ratios blend cleanly. Minimum display time stays zero: loading adds
no intentional delay. Source: [Godot boot splash settings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-image).
