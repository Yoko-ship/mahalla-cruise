# Banknote artwork

Downloaded 2026-10-06 from the issuing institutions' public reference pages.
Original JPEGs are retained unmodified, including NAMUNA/SPECIMEN markings.
Godot imports a maximum 256-pixel edge with mipmaps; the game draws each front
at 44 canvas pixels wide, preserving its aspect ratio. The denomination badge,
ground shadow, and collection feedback are drawn separately.

## Sources

- Uzbek notes: [Central Bank of Uzbekistan banknote catalogue](https://cbu.uz/en/banknotes-coins/banknotes/).
  The 1,000 soʻm image is the 2001 design; other selected soʻm notes are 2021 designs.
- Dollar: [U.S. Currency Education Program, $1](https://www.uscurrency.gov/denominations/1).

| File | Original image |
| --- | --- |
| `som_1000.jpg` | [Official JPEG](https://cbu.uz/upload/iblock/5bf/1000som_2001_1.jpg) |
| `som_5000.jpg` | [Official JPEG](https://cbu.uz/upload/iblock/951/3.jpg) |
| `som_10000.jpg` | [Official JPEG](https://cbu.uz/upload/iblock/941/5.jpg) |
| `som_50000.jpg` | [Official JPEG](https://cbu.uz/upload/iblock/beb/50-old.jpg) |
| `som_100000.jpg` | [Official JPEG](https://cbu.uz/upload/iblock/4f8/100-old.jpg) |
| `usd_1.jpg` | [Official JPEG](https://www.uscurrency.gov/sites/default/files/styles/bill_version/public/denominations/1_1963-present-front-1_0.jpg.jpg?itok=4Y3M6xCA) |

## Usage record

Source availability is not an open-source artwork license. CBU images are
attributed above; the catalogue does not state a separate image license.
The U.S. source publishes [currency image-use conditions](https://www.uscurrency.gov/media/currency-image-use),
covering reproduction size, one-sided illustrations, and deletion after final use.
These assets remain in active use by this prototype. Keep the source markings
and review those terms if repurposing the artwork for print or promotional use.

## Gameplay mapping

`src/pickups/default_pickups.tres` connects each image to a typed denomination.
Soʻm scores equal face value / 1,000; $1 earns 10 game points independently.
Within soʻm spawns, weights are 50/28/16/5/1 for ascending denominations.
Dollar chance remains 12% of all spawns. Scores are fictional game values.
