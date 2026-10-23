# Tashkent district scenery

Implemented 2026-10-22 with the built-in image-generation tool. The four new
textures are opaque 887 × 1774 PNGs, copied unchanged from the tool output.
Their import settings enable mipmaps. All use curbs at source x=253/634 and
an 864-game-pixel repeat; the full source height is used. The existing mahalla
and Magic City art keep their own source crops and repeat settings.

The generated districts adapt recognizable architecture to a straight, elevated
2D driving view. They are inspired environments, not surveyed street maps or
representations of actual driving access. Roads, lane markings, traffic and cars
remain separate runtime elements. No new dependencies or external API keys.

## References and exact prompts

Each call used `magic_city_street.png` as the layout/camera/lighting reference
and one photograph for architectural identity. Photographs are local research
inputs under ignored `build/`, not shipped game assets. Exact full prompts,
reference paths and original generated output paths are preserved in
[journey-prompts.json](journey-prompts.json). Originals remain in the tool's
generated-images directory. Existing Magic City provenance is in [MAGIC_CITY.md](MAGIC_CITY.md).

| District | Reference page | Reference image |
| --- | --- | --- |
| Chorsu Bazaar | [Meros](https://meros.uz/uzc/object/ch%D0%BErsu-b%D0%BEz%D0%BEri) | [Turquoise dome and market](https://meros.uz/upload/2017/02/cec648457f94bb2634887ed3b4cc93a1-large.jpg) |
| Amir Temur Square | [Trawellino](https://www.trawellino.com/blog/tashkent-top-10-things-to-do-in-tashkent-uzbekistan-792) | [Park and equestrian monument](https://www.trawellino.com/media/images/blog_images/1752543086_FCN5MpSm.jpg) |
| Tashkent City | [RBC Style](https://style.rbc.ru/impressions/6912ff049a79470be29f7e80) | [Glass towers and podium](https://s0.rbk.ru/v6_top_pics/media/img/0/37/347630458582370.jpeg) |
| Seoul Mun | [Afisha](https://www.afisha.uz/ru/gorod/2024/03/07/seoul-mun) | [Canal promenade and terraces](https://www.afisha.uz/uploads/media/2024/03/892f2d72b16bb4b52db7a5e4f8cc05ba_lf.jpg) |

## Runtime

`src/routes/tashkent_journey.tres` orders mahalla → Chorsu → Amir Temur Square →
Tashkent City → Seoul Mun → Magic City, then repeats. Each section is 550 metres
(50 seconds for the default Damas at full speed); actual travel, including brakes
and car speed upgrades, determines progression. The first 48 metres of a new
section move a feathered boundary from the top to the bottom of the visible view.
Only a 32-pixel join blends the two environments, keeping the rest sharp.

Tashkent starts at the mahalla and Magic City starts at the sixth entry. The
paid Samarkand, Bukhara and Khiva routes keep their existing static scenery and
bonuses. The location name appears for four driving seconds and is localized
in Uzbek Latin, Russian and English. Pause hides and freezes the banner and
transition; restart restores the selected starting district. Gameplay and saves
are unaffected by district changes.

## Validation

`./scripts/check.sh`: 49 behavior suites plus tooling, format, lint, import and
parse checks passed. The new location suite covers 124 checks. Reviewed all six
Mac Compatibility road views and district joins at 432 × 768 and 432 × 912.
[Six-area preview](../../docs/art-direction/locations-preview.png).
Android and Windows were not run. Phone performance and user review remain next.

The initial desktop capture stopped receiving frame-post-draw callbacks while
backgrounded. The capture-only harness now explicitly flushes rendering after
scene frames; final captures completed cleanly. Production rendering is unchanged.

## Output integrity

| Asset | SHA-256 |
| --- | --- |
| `chorsu_street.png` | `a40ea678addfe90bec909cb508abe996ac6c48a922ee202e36fb85ed7cee82a6` |
| `amir_temur_street.png` | `abbeded2dee4dbb0191d7288caf1e4296b72cda0d2b8b906738fe192a4c738fe` |
| `tashkent_city_street.png` | `30f7313039228f7a45758a1213dedffd83449b0e07910b85204450068c4747b4` |
| `seoul_mun_street.png` | `08a58697a7df26f02b9320b9e6723e0dca7ea4cf1f5560264ecb50bd02e987c5` |
