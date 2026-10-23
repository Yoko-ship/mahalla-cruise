# Magic City inspired street

Added 2026-10-22 using the built-in image-generation tool and one refinement.
This is a drivable interpretation of Magic City's architecture, not a surveyed map
or a claim that the park's pedestrian spaces are public driving roads.

## References

- [Magic City official park description](https://magiccity.uz/about): themed streets,
  castle, fountain, and park facilities.
- [Official park locations](https://magiccity.uz/location).
- [Entrance photograph](https://ak-d.tripcdn.com/images/1mi5l224x92voqsib7AA1.jpg?proc=source%2Ftrip)
  from [Trip.com](https://www.trip.com/moments/theme/poi-magic-city-park-141637694-attraction-993137/):
  cream arches, gray-green masonry, diamond trim, blue turret roofs.
- Existing `mahalla_street.png` supplied only the parallel road layout reference.

Reference photos remain in ignored build files and are not runtime textures.

## Runtime asset and integration

- `assets/scenery/magic_city_street.png`: generated opaque 887 × 1774 texture;
  mipmaps enabled. Source curbs are at x=253 and x=634. Use the first 1732 rows,
  ending in the repeated hedge before the lower duplicate wall, for an 864-pixel loop.
- `src/scenery/magic_city_art.tres` owns those values. The scenery renderer maps
  all three strips to road bounds, including on taller viewports.
- `src/routes/magic_city.tres` adds a free route with standard scoring and Tashkent
  plate region 01. The existing route picker shows Select and remembers the choice.
- The old mahalla remains the default artwork for the four existing city routes.
  Its NON sign is disabled for the new scenery. Cars, road markings, and HUD are
  separate layers; road width and gameplay settings are unchanged.
- Preview: `docs/art-direction/magic-city-preview.png`.

Generator sources were retained under
`/Users/airm4/.codex/generated_images/01a16200-f1c3-77b0-a42e-dc775145d42e/`.
Initial output: `exec-67b2d6e1-d092-4275-b1b2-7234737cd1ed.png`.
Final output: `exec-1417416e-1dea-4da3-b09a-2648b46b322d.png`.
The final output is copied into the repository; runtime never depends on that folder.

## Initial prompt

```text
Create a production background texture for a portrait 2D driving game, 1024 x 2048 pixels, opaque. Use case: photorealistic-natural game environment.
Reference 1 is ONLY the road layout and scrolling composition constraint, not the painted style. Reference 2 is ONLY architectural identity: the real Magic City Tashkent entrance with cream stone triple arches, gray-green masonry, diamond lattice trim and blue conical turret roofs. This is an inspired game adaptation, not a map.
Render a realistic boulevard alongside Magic City, seen from an elevated camera looking down 38 degrees, orthographic projection. No horizon, no vanishing point. The road runs exactly vertically from bottom to top with perfectly PARALLEL edges at x=29% and x=71% of the image throughout. Keep the entire central 42% clear fine-grained medium gray asphalt. NO painted lines or crosswalks, no cars, no pedestrians, no UI, no titles.
Outside the left curb, a recognizable cropped Magic City castle gate complex occupies the upper-middle part of the strip: cream carved arches and blue-roof stone turrets, landscaped forecourt, black iron fence. Keep every building and tower silhouette outside the road, even its overhanging roof. Building outer portions may be cropped by the image edge. Further down on both sidewalks, realistic European-inspired cream/ochre brick shop facades with blue-gray slate roofs, restrained awnings, detailed doorways, elegant black lamps, park planting and modest mature trees. A small fountain plaza inset on the right sidewalk. Use believable stone, fine asphalt aggregate, glass reflections, paving joints and ambient occlusion. The whole scene must look like a high-quality realistic architectural 3D render, NOT hand-painted, NOT toy plastic, NOT cartoon. Natural warm afternoon sunlight from upper left, soft shadows lower right matching the reference layout; restrained saturation.
At topmost and bottommost 8% show matching simple light stone sidewalk, identical low park wall and low green hedges on each outer side with unbroken asphalt between: these edges must tile SEAMLESSLY vertically. No tower, building, tree trunk or strong shadow may touch the top/bottom boundary. Keep same paving scale, illumination, asphalt color and curb position at both ends. No gradients in exposure down the road. No border. No text or watermarks anywhere. Deliver only the complete usable street texture.
```

## Refinement prompt

```text
Refine this production scrolling game background into a photorealistic architectural render. Preserve every building placement, Magic City gate identity, straight vertical road edges, road width, and empty center. Remove the illustrated/cartoon finish: use subtle plaster roughness, small realistic stone joints, physically believable reflected light and material detail, restrained greenery, natural rather than painted foliage. The road must be realistic smooth fine-grained asphalt, not large coarse speckles or gravel; dark neutral gray with subtle tire wear, no lane markings. Reduce saturation and over-bright yellow highlights, retain warm afternoon sunlight. Keep opaque portrait texture and the same orthographic camera. Important tiling correction: make the first 80 and last 80 image rows depict the same stretch of plain low cream park wall, short trimmed hedge and sidewalk aligned exactly so top and bottom join seamlessly. No cars, people, text, crosswalks, shadows cutting into the road center, UI or watermarks. Do not add anything or change the parallel curbs.
```
