# Angled 2D Runtime Artwork

Implemented 2026-10-06 following the user's request to implement the complete
angled gameplay concept. Generated using the built-in image generation tool.

## Active Assets

- `cars/vehicles_aligned.png`: transparent Damas/sedan atlas, 1774 × 887.
  Player and traffic face straight up, viewed from an elevated centered rear
  camera. The atlas regions are selected by Godot; originals are preserved.
- `scenery/mahalla_street.png`: connected environment, 941 × 1672. Runtime uses
  its first 1540 rows, ending at the repeated courtyard wall, for a 720-pixel loop.
  Scenery maps the two painted curbs to the route resource's edges. The road
  module draws lane markings, and the scenery module draws a native NON sign.
- Both textures have mipmaps and linear filtering. Vehicle shadows are drawn
  separately, with the same lower-right light direction as the environment.

The concept in `docs/art-direction/` guided palette, lighting, camera and scale.
Runtime uses parallel curbs rather than the concept's tapered road, keeping
steering and collision geometry consistent. Buildings, road texture and trees
form a connected environment layer; player, traffic, shadows, lane markings
and HUD remain independently rendered and move through game logic.

Older individual sprites remain as source history and are no longer referenced
by runtime scenes. There are no new dependencies.

## Original Generator Files

Under `/Users/airm4/.codex/generated_images/01a11073-43b0-7df1-b0e8-4d3e80efee87/`:

- Vehicles: `exec-292f58e0-ac25-43bd-ba83-b1ba00c7729d.png`
- Initial street: `exec-e498eacb-eb16-4ccf-9b92-9b0c08c1d5e0.png` (rejected road taper)
- Corrected street: `exec-b14cdc0f-e7bc-4538-b225-b3a710371697.png`

The vehicle and initial street calls used the complete concept as a visual
reference. The street correction used the initial street as its edit target.
The concept's official Damas photo sources are recorded in
`docs/art-direction/README.md`. No reference photographs are runtime textures.

## Exact Prompts

### Vehicle Atlas

```text
Use case: stylized-concept. Production transparent sprite atlas for a 2D mobile driving game.
Reference image is ONLY the approved world art style: warm softly painted realistic miniature Uzbekistan mahalla. Generate TWO separate vehicle sprites side by side on a genuinely transparent background, with wide empty gap and padding. Left: classic white Uzbekistan Chevrolet Damas microvan, boxy tall short cabin, orange/navy stripe, upright large dark rear glass, vertical narrow red/clear rear lamps, black rear bumper, tiny black wheels. Right: light neutral silver Chevrolet Nexia-like compact sedan, squared rear trunk and red tail lights. Both SAME apparent width; Damas slightly taller.
CRITICAL CAMERA: elevated DIRECTLY BEHIND, camera centered over vehicle longitudinal axis, looking down at 50 degrees. Orthographic 2D illustration. Both vehicles driving straight toward exact 12 o'clock. Front center, roof center, rear window center and bumper center all lie on same vertical line. Rear bumper exactly horizontal. LEFT AND RIGHT SIDES equally visible, symmetric geometry, no yaw, no diagonal orientation, no 3/4 side-view. Show roof and rear body, not just top. No wheels turned.
Match reference's illustrated material quality, softened edges, ivory paint and dark blue-gray windows, simplified detail readable at 48px width, softly painted shaded surfaces, subtle upper-left warm light. No road, no buildings, no drop shadow, no floor, no labels, no text, no badges or logo, no outline glow, no fake checkerboard. Both objects fully contained, separate, isolated with transparent alpha, centered in their own half. Wide landscape canvas.
```

### Initial Environment

```text
Use case: stylized-concept. Production game environment texture, NOT a mockup. Reference provides art style only. Create a portrait 2D scrolling Uzbekistan mahalla street background, 9:16 ratio.
Camera elevated 50 degrees, directly behind traffic heading up, orthographic projection with PARALLEL VERTICAL road edges. No vanishing point, no horizon, no narrowing road toward top. Same world scale throughout.
EXACT LAYOUT: asphalt road entirely plain and empty from x=21% to x=79% of image width, edges vertical top to bottom. Warm stone sidewalks OUTSIDE that corridor. Continuous neighborhood blocks fill outer left 21% and right 21%: cropped terracotta roofs, connected warm plaster courtyard walls, teal gates, bakery and tea veranda facing road, grapevines, sage green trees with visible trunks, a tapchan. The buildings continue past outer screen edges. Cars would be about 10% image width; houses occupy 25-40% width and are partly cropped. Arrange three different blocks down the strip, NON bakery near top left, courtyard near middle, CHOYXONA veranda bottom right.
Soft hand-painted game illustration matching the reference, consistent sun upper left and soft contact shadows lower right. Muted sand, ivory, terracotta, teal, sage and dusty warm gray asphalt. Connected grounded objects, believable scale. No thick outlines, no plastic cartoon geometric placeholders. Road surface softly textured, no markings at all, no manholes. No vehicles, no people, no UI or title, no distance, no controls, no watermark. Only optional small NON and CHOYXONA storefront signs.
VERTICAL LOOP TILE: top and bottom edges must match seamlessly when stacked, at equal road width, sidewalk paving and continuous cream courtyard wall with gardens outside at BOTH ends. Keep large trees/buildings away from topmost and bottommost 4% to permit clean join. No border or frame. Asphalt same color all along. Deliver a single connected environment without vehicles; gameplay cars and lane markings will be separate runtime layers.
```

### Environment Geometry Correction

```text
Use case: precise-object-edit. Edit this production 2D game environment tile.
Correct road geometry and loop edges while preserving the warm painted mahalla style and all local architecture.
CRITICAL: the road must be a PERFECT RECTANGLE from x=25% to x=75% across the full image. Both curb lines exactly VERTICAL AND PARALLEL, same x position in every row, from top to bottom. ORTHOGRAPHIC view 50 degrees down. No perspective convergence, no narrowing, no vanishing point. Buildings same scale at top as bottom. Recompose the side architecture to follow these parallel curbs, with roof/rear-side elevation remaining consistent. Asphalt remains empty without markings or cars.
Make a vertically seamless texture: the topmost and bottommost 10% must depict IDENTICAL, simple straight cream courtyard walls on both outer sides, stone paving and quiet low gardens, so bottom connects to top as a continuous street. Keep complete trees, roofs, gates, verandas between y=15% and y=85%; no major objects crossing the top/bottom boundary. One NON bakery, one teal gate and one CHOYXONA veranda down the middle stretch of this long block, cropped at left/right edges. No UI, no vehicles. Road surface same subtle muted grey all along, finer and less noisy than reference.
Keep the 9:16 portrait aspect ratio. Deliver the corrected production environment, not a screenshot mockup.
```
