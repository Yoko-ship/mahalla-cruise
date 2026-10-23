# Rendered traffic sprites

Regular traffic uses six cars rendered from the existing 3D source models: Matiz,
Spark, Nexia, Cobalt, Gentra, and Malibu. The Damas remains a player option; its
painted image is excluded from this traffic set so the rendering style is consistent.
These are transparent 2D sprites at runtime, not live 3D meshes.

`traffic_realistic.png` contains five new renders. Cobalt reuses the straight view
in `src/driving/cobalt_art.tres`. Source models, authors, and CC-BY-4.0 records are in
[the model credits](../../art_sources/car_models/CREDITS.md). Existing attribution
and provenance review remains part of release preparation.

The Blender render uses the same 38-degree orthographic rear camera, AgX display
transform, warm sun, softbox, fill light, coated neutral paint, and dark reflective
windows as the Cobalt. Rear lamps have no artificial daytime emission. Geometry,
trim, and lens details come from the existing source models.

Packing crops transparent margins and scales uniformly to a 720-pixel body height,
with eight transparent pixels around each frame. It never separately compresses
width. Traffic fits the frames within 60 by 72 game pixels: the wider allowance
accommodates the hatchbacks' mirrors while preserving visible body length. Collision
boxes remain 40 by 72 pixels. Each car owns its paint material; a restrained seven-color
palette preserves variety. A tighter shadow follows the rendered sprite size.

Rebuild from the project root with the existing downloaded models and Blender:

```sh
~/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/traffic_cars.py
./scripts/godot.sh --headless --path . --script scripts/pack_traffic_cars.gd
./scripts/godot.sh --headless --editor --path . --quit
```

Keep mipmaps enabled in `traffic_realistic.png.import`. Raw renders are ignored under
`build/traffic_renders/`; the atlas and five `src/traffic/art/*.tres` resources are
tracked outputs. Player/garage artwork is unchanged by this traffic update.
