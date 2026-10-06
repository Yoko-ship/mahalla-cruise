# Damas Rear View Revision

`damas_white_rear.png` is the current player sprite, generated with the built-in
image tool on 2026-10-06 after the user reported that the first sprite did not
look like a Damas. It uses an elevated rear view to reveal the tall cabin,
upright hatch, stacked tail lamps, small wheels, and orange/navy side markings.
It is drawn at approximately 55 × 72 game pixels with a separately drawn shadow.
The original `damas_white.png` is retained as the superseded first draft.

## Reference Sources

- [Official Chevrolet Uzbekistan Damas page](https://chevrolet.uz/damas)
- [Front/side photograph](https://chevrolet.uz/assets/images/damas/big/exterior/01.jpg)
- [Rear/side photograph](https://chevrolet.uz/assets/images/damas/big/exterior/03.jpg)

The two manufacturer photos were supplied as vehicle-identity references to the
image tool. The generated illustration is the game asset; reference photographs
are not shipped in the game. References remain the property of their respective
rights holders. This is not an official manufacturer asset or endorsement.

The source PNG retains transparency. Godot imports at a maximum edge of 512
pixels with mipmaps. Review the player scene scale if this import size changes.

## Final Generation Prompt

Create a NEW illustrated game sprite of the CLASSIC UZBEK CHEVROLET DAMAS shown in the two reference photographs. The photographs are vehicle-identity references, not editing targets. Match their exact tall, stubby, box-shaped passenger van: high raised roof, nearly vertical rectangular rear hatch, big upright rectangular rear window, tiny wheels, stacked narrow vertical red/clear rear lamps, thick black bumper, white body and orange/navy horizontal stripe with angular slash on the side. This is a short tall microvan, not a long generic transit van.
View: orthographic ELEVATED REAR view, camera only 35 degrees down from horizontal, just 10 degrees off center to reveal a narrow RIGHT side with black-framed rectangular side windows and the stripe. The van is driving AWAY from us toward the TOP of the screen. Rear bumper bottom, roof top, no visible front face, NO HEADLIGHTS, no windshield visible. Rear door fills roughly the LOWER HALF of the visible body, with roof in upper third. Emphasize the cabin HEIGHT like the photos. Keep travel axis almost vertical with minimal diagonal skew. Compact projected sprite about 0.7 width per 1.0 height, NOT stretched.
Style: clean charming hand-drawn 2D mobile game illustration, muted cream-white, dark teal windows, simple warm shading and clean dark contours, clear at 50 pixels wide. Lightly stylized but identifiable as the specific reference Damas. No giant roof ribs; its roof is mostly smooth with a modest raised lip.
One vehicle only, centered and fully visible including wheels and mirrors, small clear margin. TRUE TRANSPARENT ALPHA BACKGROUND. No background pixels, NO glow or halo, NO ground shadow, no scenery, no logo, no watermark, no writing. Everything outside the van is fully transparent.
