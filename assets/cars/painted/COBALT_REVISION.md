# Cobalt Correction — 2026-10-22

The initial painted Cobalt was rejected for poor likeness. `cobalt.png` now uses
this corrected built-in image generation. Changes: uninterrupted broad trunk lid
with a small keyhole, a low bumper plate recess, horizontal bumper trim, and
red/clear segmented lamps. The other five painted car sources are unchanged.

## References

Photographs supplied for vehicle identity only; not shipped as game textures:

- [Official Chevrolet brochure, exterior page and lamp closeup](https://chevrolet.uz/storage/images/catalog_auto_ru/17/nu9uTAT1l9F5AwMzNNOOqI40VtIwWu7WHSz2jVhS.pdf)
- [Rear-view photo in an OLX Cobalt listing](https://www.olx.uz/d/obyavlenie/cobalt-2022-avtomat-arenda-nasiya-savdo-ID40W19.html)
- [Rear photo file](https://frankfurt.apollo.olxcdn.com/v1/files/tmpj9s6mjr8h-UZ/image%3Bs%3D1280x1280)

The tool edited the previous sprite using these references. The model reference
history and credits in README.md remain recorded. Reference downloads live only
under ignored `build/` and remain the property of their respective rights holders.

## Generation

Original: `/Users/airm4/.codex/generated_images/01a16200-f1c3-77b0-a42e-dc775145d42e/exec-74476f12-7c97-4ba9-a91f-5504a7a8a2e7.png`

```text
Use case: precise-object-edit.
Asset type: corrected Chevrolet Cobalt sprite for a 2D Uzbekistan driving game.
Image 1 is the EDIT TARGET: the existing white sprite has WRONG vehicle identity details. Image 2 is the authoritative REAL COBALT REAR PHOTO; faithfully transfer its body geometry and lamp design. Image 3 is the official Chevrolet brochure, with a large accurate tail-lamp closeup at bottom right.
Correct image 1 to unmistakably depict the white Uzbek Chevrolet Cobalt / Ravon R4, using photo 2:
- Huge broad flat uninterrupted trunk lid, subtle upper lip, curved lower edge. NO LICENSE PLATE RECESS IN THE TRUNK. Small black round keyhole centered low on trunk, omit gold badge and all lettering.
- License plate MUST be in the LOWER REAR BUMPER, below the trunk seam, inside a broad trapezoid recessed bumper panel. A thin dark gray horizontal strip follows the TOP of this bumper recess, above the plate. Blank ivory plate only.
- Exact tall outer-corner lamp housings from photo 2 and brochure 3: tapered outer vertical stacks, red upper cap, large CLEAR SILVER/chrome middle band with amber bulb, narrow separator, second clear band, red lower section. NO two stacked red circles. Distinct red/clear/red contrast. Keep lamps entirely on outer rear fenders, not split onto trunk.
- Cobalt's thick rounded rear bumper, bulky high trunk, gently curved roof, sloping sedan rear window, modest mirrors, stock tyres. One modest small exhaust under left bumper.
Retain softly painted realistic miniature quality, neutral ivory white body for paint shader, warm upper-left light, dark bluish tinted glass. Make the interior subtle, do not exaggerate seats.
CAMERA: preserve centered elevated rear-facing camera of image 1, aligned perfectly to 12 o'clock, zero yaw, left/right sides equally visible, bumper horizontal. Show roof, rear glass, broad trunk deck, trunk face, lower bumper. Whole car with mirrors and tyres, portrait composition and transparent margin.
TRUE transparent alpha outside car. No road, ground, trees, shadows, photo background, text, brand badge, watermarks or labels. Do not copy photo perspective: only its precise vehicle identity. Output one corrected car.
```
