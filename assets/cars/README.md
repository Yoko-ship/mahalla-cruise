# Damas Player Artwork

The current Damas and sedan use `vehicles_aligned.png`. See
[ANGLED_ART.md](../ANGLED_ART.md) for the full prompts and rendering details.
The previous `damas_white_rear.png` pointed diagonally and has been superseded.
[DAMAS_REVISION.md](DAMAS_REVISION.md) preserves that version's source record.

## Garage Roster Art

Cobalt now uses [five consistent Blender steering views](COBALT_DRIVING.md) in
`cobalt_driving.png`, with natural proportions and a projected plate. Its painted
versions remain as history; the other five cars still use the painted atlas below.

The active garage atlas is now `roster_painted.png` (2026-10-22), with six painted
adaptations matching the Damas. Original PNGs, exact prompts, reference roles, and
generation paths are in [painted/README.md](painted/README.md). They use the existing
Blender renders as identity references, so the model author attributions below
remain applicable. The Damas, car tuning, factory paints, and atlas regions are unchanged.
High-resolution sources are excluded from runtime import; the packed atlas uses mipmaps.

```sh
./scripts/godot.sh --headless --path . --script scripts/render_roster_cars.gd -- --painted
```

### Preserved Blender Version

`roster_cars.png` holds the Matiz, Cobalt, Gentra, Spark, Nexia, and Malibu (2026-10-12),
rendered in Blender 4.2 LTS (Cycles) from downloaded 3D models of the real cars. Every model
is CC Attribution 4.0 (commercial use allowed, author must be credited); authors and links
are in [`art_sources/car_models/CREDITS.md`](../../art_sources/car_models/CREDITS.md), and the
game must show those credits. The model files themselves stay out of git.

Pipeline, from the repository root:

```sh
.venv/bin/python scripts/fetch_car_models.py      # needs SKETCHFAB_API_TOKEN in .env
~/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/roster_cars.py -- \
    build/roster_renders
./scripts/godot.sh --headless --path . --script scripts/render_roster_cars.gd
```

`scripts/blender/model_import.py` stands each model up, turns it nose-forward, scales it to
the real length, deletes badges and lettering (small separate pieces in the middle of the
rear face above the bumper, plus parts named logo/emblem/badge), and swaps body paint,
window glass (solid dark), tyres, and plates for the shared render materials; other parts
are made opaque so no pixel shows the road through the car. Per-car fixes (`rotate_x`,
`yaw`, `hide`, `paint_parts`, `materials`) live in `IMPORTS` in `roster_cars.py`. The camera
and light match the painted Damas: perspective, directly behind, 34° above the horizon, warm
sun from the upper left. Body paint renders neutral white so the game's paint shader colors
it. `render_roster_cars.gd` crops each render, scales its length to the collision length at
`sprite_scale` 0.1, caps width at the collision width plus 10 game pixels (as on the Damas),
and prints the regions used in `default_garage.tres`.

Model choice: the generation sold in Uzbekistan (classic Matiz, 2013 Spark/Ravon R2,
Nexia 2, 2011+ Cobalt, Gentra, 2016+ Malibu). Uploads that looked like re-uploaded store
models (store file names, store watermarks) were rejected. Review before a public release:
the Nexia 2 uses the same standard material names as those store models, the Gentra looks
converted from a game mod, and the Cobalt and Malibu sources could not be fully confirmed;
car-name trademarks also apply. The Gentra needed repairs (`fix_normals` for dark bumper
triangles, hidden trunk-hinge brackets, the trunk strip as chrome, and an added plate,
`plate_z`); its tuned diffuser remains. A small dark speck remains low on the Malibu bumper,
not visible at road size. Painted replacements can still be made from
`docs/art-direction/CAR_ROSTER_ART.md`.

## Superseded First Draft

`damas_white.png` is AI-generated artwork created for Mahalla Cruise on
2026-10-06 with the built-in image generation tool. No reference photographs or
third-party asset packs were used. It is a stylized interpretation of the Damas,
not an official manufacturer asset; no manufacturer endorsement is implied.
No separate stock-asset license applies; retain this generation record.

The original PNG is preserved with alpha transparency. Godot imports it at a
maximum edge of 512 pixels with mipmaps, and the player scene displays the
vehicle at approximately 45 × 90 game pixels. Keep the import settings alongside
the PNG: changing the import size also requires reviewing the sprite scale.
The car visual draws the ground shadow separately.

## Generation Prompt

Use case: stylized-concept
Asset type: production 2D vehicle sprite for Mahalla Cruise, an Android overhead driving game set in Uzbekistan.
Primary request: one recognizable white Chevrolet/Daewoo Damas microvan, driving toward the top of the image.
Scene/backdrop: genuinely transparent background. Isolated vehicle only, no ground or scene.
Subject: the narrow boxy Uzbekistan Damas cab-over microvan, compact flat nose without a long hood, white body, broad dark muted teal windshield near the front/top, long white roof with three subtle pressed ribs, tiny side mirrors, four small charcoal tires, black bumpers, square warm ivory headlights at the top, small red tail lights at the bottom. A restrained orange and charcoal band along the side body edges suggests the familiar Damas side stripe. No roof rack.
Style/medium: clean hand illustrated mobile game sprite, confident simple silhouettes, flat warm ivory and muted teal colors, restrained two-tone shading, thin dark green-gray edge outlines, crisp readable at 48 by 86 game pixels. Match a simple flat 2D neighborhood with warm beige buildings and desaturated green road. No photorealism.
Composition/framing: strictly directly overhead orthographic view, roof seen from straight above. Front at 12 o'clock. Bilaterally symmetric vertical silhouette, no diagonal rotation, no perspective or isometric view. Car length about twice body width. One centered vehicle, whole vehicle and mirrors fully visible, tight framing with small transparent margins.
Lighting: subtle upper-left highlight within body. No external cast shadow (game renders shadow).
Constraints: one sprite only, actual alpha transparency, no checkerboard painted in image, no text, no logos, no watermarks, no labels, no sheet, no scenery. This must depict a Damas microvan, not a long-hood sedan or generic delivery truck.

Regular AI traffic now uses the [consistent rendered traffic atlas](TRAFFIC_REALISTIC.md)
and the Cobalt straight view. Player/garage sprites retain their existing artwork.
