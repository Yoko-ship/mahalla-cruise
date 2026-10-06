# Mahalla Scenery Artwork

The active environment is `mahalla_street.png`, a connected painted street.
See [ANGLED_ART.md](../ANGLED_ART.md) for its sources, exact prompts and runtime
mapping. The following individual sprites and their rendering notes are
superseded source history.

## Earlier Individual Buildings

Created for Mahalla Cruise on 2026-10-06 with the built-in image generation tool.
No reference photographs or third-party asset packs were used. These are
stylized fictional neighborhood buildings, not reconstructions of real shops.
Keep this generation record with the assets.

| File | Use |
| --- | --- |
| `mahalla_gate.png` | Courtyard entrance with teal double doors and terracotta canopy. |
| `non_shop.png` | Neighborhood bakery with non breads and a tandir. |
| `choyxona.png` | Teahouse with a tapchan, carved columns, and tea service. |

Original PNGs retain transparency. Godot imports each at a maximum edge of
512 pixels with mipmaps. Scenery renders them at 80 pixels wide while preserving
their aspect ratio. Shop signs are drawn in Godot as NON and CHOYXONA.
The three-building pattern repeats every 720 travel pixels; roadside trees
remain simple procedural artwork.

## Generation Prompts

### gate

Use case: stylized-concept
Asset type: a single transparent roadside scenery sprite for Mahalla Cruise, a portrait 2D driving game set in an Uzbek mahalla.
Style: warm hand-painted game illustration matching a cream-white illustrated Damas microvan; crisp dark green-gray outlines, restrained two-tone shading, warm sand plaster, ivory details, muted teal and terracotta, gentle upper-left light. Readable when displayed only 80 pixels wide. Simplify small details, no photorealism.
Camera: high overhead view with a little front facade visible toward the BOTTOM of the image, parallel orthographic edges. Building aligned square to image, no diagonal isometric rotation. Roof occupies upper half; front entrance occupies lower half.
Composition: one centered complete small structure in a roughly 3:4 width-to-height silhouette, tightly framed with small clear margins. Actual alpha transparency, isolated cutout, no scenery backdrop, no road, no people, no vehicles, no broad ground square. No checkerboard baked into image. No logos or watermarks.
Subject: one traditional Uzbek mahalla courtyard entrance. Warm sand-colored masonry boundary wall with two cream capped pillars, wide double teal metal gate with subtle ornamental diamond panels, a narrow terracotta tiled canopy above the gate, glimpse of a small planted inner courtyard behind it from above. A modest vine climbing just one pillar. Clear recognizable gate silhouette. The entrance is centered. No shop, no signs, no writing.

### non_shop

Use case: stylized-concept
Asset type: a single transparent roadside scenery sprite for Mahalla Cruise, a portrait 2D driving game set in an Uzbek mahalla.
Style: warm hand-painted game illustration matching a cream-white illustrated Damas microvan; crisp dark green-gray outlines, restrained two-tone shading, warm sand plaster, ivory details, muted teal and terracotta, gentle upper-left light. Readable when displayed only 80 pixels wide. Simplify small details, no photorealism.
Camera: high overhead view with a little front facade visible toward the BOTTOM of the image, parallel orthographic edges. Building aligned square to image, no diagonal isometric rotation. Roof occupies upper half; front entrance occupies lower half.
Composition: one centered complete small structure in a roughly 3:4 width-to-height silhouette, tightly framed with small clear margins. Actual alpha transparency, isolated cutout, no scenery backdrop, no road, no people, no vehicles, no broad ground square. No checkerboard baked into image. No logos or watermarks.
Subject: one tiny mahalla non bakery. Low sandy plaster building with warm terracotta corrugated roof, cream fascia, teal door and a small dark serving window facing bottom. A small wicker tray of round golden Uzbek non breads beside the serving window and a squat tan clay tandir visible at one side. Keep these integrated close to the building. Broad dark teal BLANK rectangular signboard above the door at the lower front; game adds lettering, do not draw text. Distinct bakery, no outdoor dining tables, no writing.

### choyxona

Use case: stylized-concept
Asset type: a single transparent roadside scenery sprite for Mahalla Cruise, a portrait 2D driving game set in an Uzbek mahalla.
Style: warm hand-painted game illustration matching a cream-white illustrated Damas microvan; crisp dark green-gray outlines, restrained two-tone shading, warm sand plaster, ivory details, muted teal and terracotta, gentle upper-left light. Readable when displayed only 80 pixels wide. Simplify small details, no photorealism.
Camera: high overhead view with a little front facade visible toward the BOTTOM of the image, parallel orthographic edges. Building aligned square to image, no diagonal isometric rotation. Roof occupies upper half; front entrance occupies lower half.
Composition: one centered complete small structure in a roughly 3:4 width-to-height silhouette, tightly framed with small clear margins. Actual alpha transparency, isolated cutout, no scenery backdrop, no road, no people, no vehicles, no broad ground square. No checkerboard baked into image. No logos or watermarks.
Subject: one small Uzbek neighborhood choyxona teahouse. Cream plaster building, muted teal ribbed roof, shaded front veranda with two simple carved wooden columns, a compact wooden tapchan with a muted red patterned cushion, one tiny blue teapot with two cups. Keep veranda and tea furniture inside the tight building footprint. Broad dark teal BLANK rectangular signboard above the entrance at lower front; game adds lettering, do not draw text. Cozy recognizable teahouse, no bakery oven, no writing.
