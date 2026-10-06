# Angled Gameplay Art Direction

## Status

Visual reference generated on 2026-10-06. The user subsequently requested its
implementation. The playable scene now uses aligned cars, a connected painted
neighborhood, and compact HUD based on this direction; see
[`assets/ANGLED_ART.md`](../../assets/ANGLED_ART.md).
This image itself remains a concept, not a screenshot.

The user selected an angled 2D view showing the Damas body and sides, with
matching road, buildings, and traffic. The previous integrated artwork was
rejected because its perspectives, scale, and styles did not fit together.

## Review Image

[Complete gameplay concept](angled-gameplay-v1.png)

Evaluate the whole scene: Damas recognition, vehicle/building scale, camera
consistency, connected neighborhood blocks, lighting, and road readability.

The concept has more surface detail and stronger road perspective than the
requested simple orthographic rendering. Its HUD, tapering road, and detail
level remain proposals. Implementation must resolve these explicitly; copying
this full image into the moving scene would not deliver the intended game.

## Implementation Criteria

- Produce reusable car sprites and street sections using the reviewed camera,
  palette, scale, and light direction.
- Keep vehicles, scenery, road, and HUD independently rendered in their existing
  feature modules.
- Inspect the complete moving scene at phone size, including collision and
  restart; compare it against the reviewed direction.
- Preserve existing gameplay unless a change is agreed separately.

## Source Record

Generated using the built-in image generation tool. Original retained at:

`/Users/airm4/.codex/generated_images/01a11073-43b0-7df1-b0e8-4d3e80efee87/exec-fde223cd-d27b-4d9a-a03b-8a5d57d20fa6.png`

Vehicle references: official [Chevrolet Damas](https://chevrolet.uz/damas)
[front/side photo](https://chevrolet.uz/assets/images/damas/big/exterior/01.jpg)
and [rear/side photo](https://chevrolet.uz/assets/images/damas/big/exterior/03.jpg).
Photographs were supplied as vehicle identity references, not runtime assets.

This directory contains a `.gdignore` file to exclude concept material from
Godot imports and game exports.

## Exact Generation Prompt

```text
Use case: ui-mockup / stylized-concept
Asset type: a complete art-direction reference for an actual portrait 2D Android driving game called Mahalla Cruise, not a promotional poster.
Create ONE polished cohesive gameplay screen, portrait 9:16. This is the visual redesign to replace mismatched pasted-looking assets. The whole image must look authored by one game artist in a single coherent world.
Vehicle identity references: the attached two photographs show the classic Uzbekistan Chevrolet Damas. Use them ONLY to understand the actual compact tall cabin, upright square rear hatch with large rear glass, narrow stacked tail lights, tiny wheels, black bumper, orange/navy side stripe. Do not reproduce the photographs or their background.
CAMERA AND WORLD: one unified elevated rear-oblique 2D game view, about 50 degrees looking down, following traffic driving UP the screen. Soft illustrated 2.5D orthographic geometry, no horizon, no diagonal isometric road. A straight vertical two-lane neighborhood street with parallel road edges, viewed from above and behind; all vehicles seen from the rear at EXACTLY the same elevation and direction. Building heights, courtyard walls, tree trunks, vehicle sides and ground planes share that same projection. No mixture of perfectly top-down vehicles and front-elevation buildings. The road occupies about 42% of screen width, sidewalks and coherent neighborhood blocks fill both sides. Logical believable scale: small Damas around 9% of frame width, houses roughly 3 times car width and partly cropped at outer edges. Road around four car widths wide.
PLAYABLE COMPOSITION: white Damas in the lower center around y=76%, heading straight toward 12 o'clock. One muted powder-blue compact sedan farther ahead in the left lane, one beige sedan still farther ahead in the right lane. Enough clear road between cars to read a relaxed driving game. Player van recognizable from its roof, upright rear glass, tailgate, small wheels and orange side stripe, no pasted photograph. No car collision or overlays.
UZBEK MAHALLA: form connected street blocks, not isolated tiny shops floating on empty beige space. Warm plaster courtyard walls connected to a teal double gate, a low NON bakery with terracotta roof, a CHOYXONA with a shaded wooden veranda. Storefronts and gate openings FACE THE ROAD from their respective sides. Partial gardens and roofs cropped at screen edges suggest neighborhood continuity. Trees with softly faceted illustrated foliage and visible trunks, grapevine near a gate, modest paving, curb stones, small drainage channels, one tapchan inside the tea veranda. Flat dusty road with tasteful sparse surface marks and pale lane dashes. Sidewalks, entrance steps and building contact shadows connect every object to the ground.
ART STYLE: professional cohesive mobile game illustration, clean simplified shapes, slightly rounded geometry, restrained hand-painted surfaces, consistent medium-small details, soft warm afternoon upper-left light, ALL shadows fall lower-right with identical softness. Muted sand/cream walls, terracotta and desaturated teal roofs, dusty blue-gray asphalt, sage foliage, vivid but restrained orange Damas stripe. No photorealism, no stock-photo texture, no thick black comic outlines, no plastic toy look. Readable at 432x768. This must feel like a designed game, not an image collage.
UI: compact refined HUD overlay, small ivory 'Mahalla Cruise' at top left, a compact '128 m' distance badge top right. No large opaque header/footer slabs. Small unobtrusive 'Drag to steer' hint near bottom. Native-looking legible game typography. Only shop signs 'NON' and 'CHOYXONA'. Do not put labels on the vehicle or roads. No coins, currencies, monetization buttons, minimap, logos, mock phone frame, watermark, or extra UI.
Deliver a single edge-to-edge gameplay art-direction screen with convincing integration, consistent perspective, scale, and shadows.
```
