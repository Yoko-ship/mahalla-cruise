# Cobalt Driving Views

Implemented 2026-10-22 after the user disliked the flat appearance in motion.
`cobalt_driving.png` contains five views at -10°, -5°, 0°, 5°, and 10° steering.
These are real Blender renders of one mesh, not generated image variants.

The camera is orthographic, 38° above the horizon. All frames use one camera,
origin, light rig, and scale. The packer scales both axes equally so the straight
car is 78 game pixels long; its natural width is about 49.6 pixels including mirrors.
The wider turning frames share a canvas to keep the car from shifting between views.

Model: [Chevrolet Cobalt LTZ 2014 by Q.SARDOR](https://sketchfab.com/3d-models/chevrolet-cobalt-ltz-2014-f91cbef731444f939e263041400216ca),
CC-BY-4.0; [full credits](../../art_sources/car_models/CREDITS.md).
Existing source-provenance review and in-game author attribution remain release tasks.
This pass retains badge stripping, removes overlapping wheel sets, uses darker alloy
and rubber materials, adds red/clear rear lens bands and a blank bumper plate, and
uses AgX, soft area lighting, reflective dark windows, and coated neutral body paint.

## Rebuild

From the repository root, with the previously downloaded model in
`art_sources/car_models/cobalt/` and the already installed Blender 4.2 LTS:

```sh
~/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/cobalt_driving.py
./scripts/godot.sh --headless --path . --script scripts/pack_cobalt_views.gd
./scripts/godot.sh --headless --editor --path . --quit
```

Raw frames, projected plate corners, and the editable Blender scene are written to
ignored `build/cobalt_driving/`. The packer writes the PNG and the typed
`src/driving/cobalt_art.tres` resource. Keep mipmaps enabled in the PNG import settings.

`DirectionalCarTexture` supplies the straight menu preview, five driving textures,
plate quadrilaterals, steering response, and shadow size. State stays on `CarVisual`.
`PlayerCar` supplies steering through a child method; movement and collision settings
are unchanged. The painted Cobalt remains in the old atlas for comparison/history.

Preview: [steering in the actual street](../../docs/art-direction/cobalt-driving-preview.gif).
