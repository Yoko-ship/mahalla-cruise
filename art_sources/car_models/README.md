# Car Models for the Garage Renders

Put one downloaded 3D model per car here, named by car id:

| File name | Car | Look for |
| --- | --- | --- |
| `matiz.*` | Daewoo/Chevrolet Matiz | first-generation Matiz (1998–2008), the common Uzbek one |
| `spark.*` | Chevrolet Spark | 2010–2015 Spark (M300) |
| `nexia.*` | Daewoo Nexia | classic 1995–2008 Nexia (Opel Kadett E shape) |
| `cobalt.*` | Chevrolet Cobalt | 2011+ Cobalt sedan (the Uzbek one) |
| `gentra.*` | Daewoo Gentra / Chevrolet Lacetti | Lacetti/Gentra sedan |
| `malibu.*` | Chevrolet Malibu | 2016+ Malibu |

Accepted formats: `.blend`, `.glb`/`.gltf`, `.fbx`, `.obj` (with its `.mtl` and textures next
to it). Sketchfab's "Download → glTF" works well. Only use models whose license allows
commercial use in a game (for example CC-BY with credit, or royalty-free); note the source,
author, and license of each model in the table at the end of this file. Model files are
ignored by git (licenses may forbid redistribution); only the rendered sprites are committed.

Render and pack (from the repository root):

```sh
~/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/roster_cars.py -- \
    build/roster_renders
./scripts/godot.sh --headless --path . --script scripts/render_roster_cars.gd
```

Cars without a model here keep the simple built-in Blender shape. If a model faces the wrong
way or a material is misread, set `yaw`, `materials`, or `hide` for that car in
`scripts/blender/roster_cars.py`; the render log lists every material and how it was used.

## Sources

| Car | Source URL | Author | License |
| --- | --- | --- | --- |
