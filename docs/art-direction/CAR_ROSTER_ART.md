# Car Roster Artwork Brief

Status: **brief only; final artwork not produced yet.** Written 2026-10-07. Matiz,
Cobalt, and Gentra currently use temporary recolored-sedan test sprites (see
`assets/cars/README.md`). Colors below are proposals awaiting user approval.

## Must match the existing cars

Use `assets/cars/vehicles_aligned.png` (Damas and traffic sedan) as the style and
camera reference. Every new car must have:

- the same elevated camera **directly behind** the car, looking down about 50°,
  facing straight up, perfectly symmetric, with no yaw or 3/4 view;
- the same softly painted miniature style, warm upper-left light, dark blue-gray
  glass, and detail that reads at about 48 px wide;
- a transparent background, with no drop shadow (the game draws shadows), road,
  text, logos, badges, or readable plates (plates stay blank);
- a clear difference from the **silver traffic sedan**, so players never lose
  track of their own car.

## Each car's look

| Car | Body shape (rear view) | Recognizable details | Proposed color | Size vs Damas |
| --- | --- | --- | --- | --- |
| Matiz | Tiny, tall, rounded hatchback; narrow track; roof nearly as wide as the body | Big, near-vertical rounded tail lamps up the rear pillars; small rounded rear window; short round bumper; tiny wheels | Cherry red (stands out; Matiz comes in many bright colors) | About 85% width, 80% length |
| Cobalt | Modern compact sedan with a tall, high trunk | Large tail lamps wrapping from the fenders onto the trunk; thin chrome strip across the trunk lid (no badge); slightly raised trunk edge | Pearl white (the most common Cobalt color in Uzbekistan) | Same width, slightly longer |
| Gentra | Classic mid-size sedan, smooth and slightly longer | Rounded tail-lamp clusters with a chrome trim bar; gently sloping rear window; body-color bumper | Glossy black with soft highlights, so it reads on dark asphalt | Same width, longest |

A black car on gray asphalt needs a subtle light rim on the roof and trunk edges,
so it stays visible at phone size.

## Generation prompt (one atlas, three cars)

```text
Use case: stylized-concept. Production transparent sprite atlas for a 2D mobile driving game.
Reference image is the approved vehicle atlas (white Damas and silver sedan): match its exact camera, scale, painted material quality and lighting. Generate THREE separate vehicle sprites side by side on a genuinely transparent background, with wide empty gaps and padding.
Left: cherry red Chevrolet Matiz-like tiny rounded city hatchback, tall short body, narrow, big near-vertical rounded tail lamps on the rear pillars, small rounded rear window, short round bumper, tiny wheels. About 85% of the reference Damas width and 80% of its length.
Middle: pearl white Chevrolet Cobalt-like modern compact sedan, tall high trunk, large tail lamps wrapping from fenders onto the trunk lid, thin chrome strip across the trunk, same width as the Damas, slightly longer.
Right: glossy black Chevrolet Gentra/Lacetti-like mid-size sedan, smooth rounded rear, rounded tail-lamp clusters joined by a chrome trim bar, gently sloping rear window, same width as the Damas and the longest of the three. Subtle light rim highlights on roof and trunk edges so the black body reads against dark asphalt.
CRITICAL CAMERA: elevated DIRECTLY BEHIND, camera centered over each vehicle's longitudinal axis, looking down at 50 degrees. Orthographic 2D illustration. All vehicles driving straight toward exact 12 o'clock. Roof center, rear window center and bumper center on one vertical line. Rear bumper exactly horizontal. Left and right sides equally visible, symmetric, no yaw, no diagonal, no 3/4 side view. Show roof and rear body. Wheels straight.
Softly painted shaded surfaces, subtle upper-left warm light, dark blue-gray glass, simplified detail readable at 48px width. No road, no ground, no drop shadow, no labels, no text, no badges or logos, blank license plates, no outline glow, no fake checkerboard. Each car fully contained and isolated with transparent alpha, centered in its own third. Wide landscape canvas.
```

## After the artwork arrives

1. Save the original as `assets/cars/roster_aligned.png`, with its prompt and
   source in `assets/ANGLED_ART.md`; keep mipmaps and linear filtering.
2. Add an `AtlasTexture` per car in `default_garage.tres` and set `sprite_scale`
   so on-screen size matches each car's collision box.
3. Inspect each car on the road, in the garage, and on the start screen; check
   that it is distinct from traffic, then run `./scripts/check.sh`.
4. Before a public release, review the use of real model names and look-alike
   designs (trademarks).
