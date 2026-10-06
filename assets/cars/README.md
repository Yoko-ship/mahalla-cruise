# Damas Player Artwork

The current Damas and sedan use `vehicles_aligned.png`. See
[ANGLED_ART.md](../ANGLED_ART.md) for the full prompts and rendering details.
The previous `damas_white_rear.png` pointed diagonally and has been superseded.
[DAMAS_REVISION.md](DAMAS_REVISION.md) preserves that version's source record.

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
