# Proposal: Car Roster and Growth Features

Status: **section 1 implemented on 2026-10-07** with the roster Damas, Matiz,
Cobalt, and black Gentra (Gentra replaced Nexia), a saved wallet, and fixed
stats. Section 2 idea 1 (near-miss bonus and combo) was implemented the same day;
the other section 2 ideas are still proposals.
Written 2026-10-07. Each item needs user
approval before work starts (see `AGENTS.md`). Android phone testing is paused
until a device is available, so this plan uses desktop checks only.

"Best on the Uzbek market" is a goal, not something we can measure locally. These
ideas are hypotheses; playtests with Uzbek and Russian speakers should confirm them.

## 1. Car roster with distinct characteristics (recommended first)

### Why
Right now every run is the same Damas. Several cars with their own feel give
players a reason to return ("one more run to afford the Cobalt"). Cars people see
every day in Uzbekistan also make the game more recognizable. Competing local
games already lead with cars and tuning, so players expect a garage.

### Design rules
- **Trade-offs, not strict upgrades.** Each car should be better at something and
  worse at something else, so the starter car stays viable and a skilled player
  can still choose a cheaper car.
- **Few, readable stats.** Show three bars in the garage: Speed, Control, Size.
- **No pay-to-win.** Cars unlock with in-game money earned by driving.

### What each stat changes (mapped to existing code)

| Stat | Effect in game | Where it lives today |
| --- | --- | --- |
| Speed | Road scroll speed multiplier. Faster cars cover more distance, meet more money **and** more traffic per second, which gives a natural risk/reward. | `RoadSettings.scroll_speed` (220, shared) |
| Control | How quickly the car follows your finger. | `CarSettings.steering_speed`, `drag_sensitivity` |
| Size | Collision box. Smaller cars slip through tighter gaps. | `CarSettings.collision_half_size` |

### First roster (starting values to tune in playtests)

| Car | Role | Speed ×  | Steering | Collision half-size | Price (points) |
| --- | --- | --- | --- | --- | --- |
| Damas (starter) | Steady, roomy | 1.00 | 640 | 20 × 36 | free |
| Matiz | Small and nimble, a bit slow | 0.95 | 760 | 17 × 30 | 300 |
| Nexia | Balanced all-rounder | 1.10 | 680 | 19 × 38 | 1,000 |
| Cobalt | Fast and precise, longest body | 1.20 | 720 | 20 × 40 | 2,500 |

Later candidates: Spark, Gentra/Lacetti, Malibu (fastest, heavier steering), and
a popular Chinese electric car for a "modern Tashkent" option.

### Decisions needed from the user
1. **Wallet.** Unlocking needs saved money. Today run points reset and no wallet
   exists (an earlier agreed decision). Should each run's points add to a saved
   wallet?
2. **Upgrades.** Fixed stats per car (recommended to start), or also per-car
   upgrade levels later?
3. **Car names and likeness.** Damas, Matiz, Nexia, Cobalt and others are
   manufacturer trademarks. Before a public release, decide whether to get
   advice, use local nicknames, or use stylized look-alikes.

### Implementation sketch (fits current architecture)
- Add a typed `CarDefinition` resource: id, translated name key, atlas region,
  a `CarSettings` resource, speed multiplier, price. A catalogue resource lists
  the roster. Defaults stay immutable; runtime choice lives on nodes.
- Main passes the selected car's settings to `PlayerCar` and its speed multiplier
  to the travel step. Traffic, pickups and road keep receiving values from main,
  so no sibling access is added.
- Save format: optional v1 fields `wallet`, `owned_cars`, `selected_car`. Older
  saves load with Damas selected and a zero wallet; no migration is needed.
- UI: a Garage screen from the start menu with car preview, three stat bars,
  price, and Buy/Select. All text goes into the uz/ru/en catalogues.
- Art: one rear-view sprite per car in the existing aligned atlas style.
- Tests: stat application, purchase/selection persistence, old-save compatibility,
  speed effects on pickup prediction, and garage layout in all three languages.
- A new `src/garage/` feature folder is an architecture change and needs approval.

## 2. Other ideas, ranked by expected value for effort

| # | Idea | Why it may matter in Uzbekistan | Effort |
| --- | --- | --- | --- |
| 1 | **Near-miss bonus and combo** for passing close to cars | Makes each run more exciting; cheap to build | Small |
| 2 | **Daily tasks** ("collect 10 × 5,000 soʻm", "drive 500 m in a Matiz") | Gives a reason to open the game every day | Medium |
| 3 | **Local road life**: speed bumps, potholes, a sheep crossing, a donkey cart, a wedding convoy (toʻy korteji) slowly passing | Instantly recognizable, gives shareable moments | Medium per event |
| 4 | **More places**: Tashkent avenue, Samarkand with Registan in the background, Bukhara old town, a Fergana valley road | Regional pride; each place can be an unlock | Large (art) |
| 5 | **Cosmetics**: colors, stickers, a roof rack loaded with melons or tomatoes on the Damas | Fun personalization; a possible future income source without pay-to-win | Medium |
| 6 | **Share result to Telegram** | Telegram is the main messenger in Uzbekistan, so free word-of-mouth | Medium (needs an Android share intent) |
| 7 | **Horn button and local-style music loop** | Character and humor at low cost | Small |
| 8 | **Low-end phone mode and smaller APK** (now about 32 MiB) | Many players use budget phones and limited mobile data | Medium |
| 9 | Online leaderboards / cloud saves | Competition among friends | Large; needs a server and accounts |

Not recommended yet: online multiplayer, complex car physics, and real-money
purchases. Each adds a lot of risk before the core loop is proven.

## Suggested order
1. Wallet plus four-car roster (after the decisions above).
2. Near-miss combo and horn.
3. Daily tasks.
4. One local road event, then a second location.
5. When a phone is available: performance, APK size, and Telegram sharing.
