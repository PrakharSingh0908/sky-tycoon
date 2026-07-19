# SkyTycoon — UI Design System
### "Blueprint" (v3.1, design-system branch) — dark command center (Dovetail reference)

Companion to [GAME_DESIGN.md](GAME_DESIGN.md) §7. This is the living contract
for how SkyTycoon looks, moves, and feels. Every screen and component follows
this document; changes to the vibe happen HERE first, then in code.
Implemented in `SkyTycoon/UI/DesignSystem/`.

---

## 0. v3.1 "Blueprint" — the Dovetail translation (2026-07-18)

Adopted from the Dovetail reference ("blueprint control room at
midnight"), translated from web to the game. Supersedes the same-day
Warm Paper experiment (v3.0, rejected on sight).

- **Surfaces:** tone-stacked, never elevated — ink #0A0A0A canvas,
  coal #141414 insets/sheets, carbon #1E1E1E cards, steel #313131
  hairlines, graphite #454545 outlined controls. ZERO shadows and
  ZERO gradients anywhere; separation is tone + 1px hairline.
- **Type:** SF (Inter-equivalent) everywhere — 400 body, 500 labels,
  600 headings; nothing heavier (capped centrally in Font.game).
  Screen titles take tight negative tracking (engineered, not
  editorial). MONO is the instrument voice: section eyebrows, tags,
  and formula/data codes, with POSITIVE 0.85pt tracking.
- **One accent:** cornflower #6798FF for icons, active states, the
  hero's highlight stroke, and data strokes — NEVER a button fill.
  Buttons (v3.1.1): machined METAL keys — the one sanctioned
  exception to zero elevation, because a console's buttons are
  physical. Keys are stamped from four stocks (`MetalFinish`):
  CHROME (brushed white, ink text — the one bright CTA per screen),
  GUNMETAL (quiet dark, accepts an anodized color tint),
  BRONZE (warm machined bronze, the gold-star family — confirm/
  commit actions), and OBSIDIAN (polished near-black — cancels and
  destructive exits; paired with bronze on confirm/cancel rows).
  Every key has a gradient face, a light-catching top rim, an
  extruded base lip, and press-travel: it sinks 2.5pt into the
  panel when touched, with a subtle 0.97 scale give. v3.1.2
  extends the language to PANEL scale, styled after a split-flap
  DEPARTURE BOARD: `MetalPanel` (dark machined housing with a
  faint diagonal sheen — the ONE hero surface per screen),
  `InstrumentWell` (recessed BLACK board tile with inverted rim;
  values are mono caps glowing in their semantic color — profit,
  loss, white — with a 1px flap seam across the glyphs), and
  `PanelGroove` (engraved divider). The hero score renders as
  SPLIT-FLAP CELLS: one machined tile per character (gradient
  face, hairline rim, horizontal seam), glyphs in lit 3D metal —
  red alloy negative, silver positive. The panel face carries a
  second inner hairline frame, like a board's double housing. Buttons pop metallic (chrome/
  bronze); panels stay dark — the glyphs carry the color, the way
  a departure board is black steel with luminous type.
  Labels on metal are engraved: mono caps with a 1px dark
  under-edge. Surfaces everywhere else stay flat.
  Muted functional green/red/amber survive for P&L semantics only.
- **Shape:** 8px on everything (4px tags). Pills are gone.
- **Data:** chart strokes cornflower; slices/bars use a blue ramp
  into grays (one chromatic family). Tags/badges are mono hairline
  outlines, not filled chips.
- The satellite map keeps its own imagery palette and sits behind a
  steel hairline like a product-preview card.

## 1. Creative direction

**Fantasy:** you run a 24/7 airline operations center. Dark room, glowing
displays, live numbers, decisions with weight. Think flight-deck instruments
and departure boards — not a settings app.

**Three feelings every screen must produce:**

1. **Alive** — money ticks, meters breathe, charts move. The sim is running
   and you can *see* it running.
2. **Tactile** — everything you can change responds instantly: buttons
   depress, haptics click, numbers roll. Nothing "just updates."
3. **Legible pressure** — green means healthy, amber means look at this,
   red means act now. A glance at any screen tells you where the fire is.

**Anti-goals:** stock iOS `List`/`Form` styling, default steppers, system
grouped backgrounds, anything that looks like a to-do app.

---

## 2. Foundations (tokens in `Theme.swift`)

### 2.1 Color — dark ops palette

| Token | Value | Use |
|---|---|---|
| `Theme.bg` | `#0B1220` deep navy | screen background, always |
| `Theme.bgElevated` | `#131D2F` | sheets, floating controls |
| `Theme.card` | `#182338` | all card surfaces |
| `Theme.hairline` | white @ 8% | dividers & ticket perforations ONLY |
| `Theme.textPrimary` | white | headline numbers, titles |
| `Theme.textSecondary` | white @ 60% | labels, captions |
| `Theme.profit` | `#4DD98C` mint | positive money, healthy meters |
| `Theme.loss` | `#FF6B6B` coral | negative money, critical meters |
| `Theme.warn` | `#FFB84D` amber | warnings, stars, "look here" |

**No borders.** Cards are borderless (Flighty-style): surface-vs-background
contrast plus a soft shadow does the separation. Hairlines exist only as
*internal* dividers and ticket perforations — never around a card.

**One accent per tab** (GDD §7) — the tab's whole screen tints with it:

| Tab | Accent | Hex |
|---|---|---|
| Dashboard | sky blue | `#59A6FF` |
| Fleet | orange | `#FF9E4D` |
| Routes | teal | `#40D6C9` |
| People | violet | `#B08CFF` |
| Money | mint | `#4DD98C` |

Rule: accents color *identity* (headers, buttons, selected states, chart
lines). Health states (profit/loss/warn) always override accent — red is red
on every tab.

### 2.2 Typography — two voices (v2.0)

Aerospace UIs separate **placard** (what a control is) from **readout**
(what it measures). We do the same, with exactly two fonts:

- **`Font.game`** — the engineering grotesk (plain SF, `.default` design).
  Titles, labels, prose, buttons. Neutral and technical; the rounded
  design is retired.
- **`Font.data`** — the instrument readout (SF Mono). **Every value the
  sim produces** — money, km, %, dates, counts — renders mono.
  `TickerText` enforces this (`.fontDesign(.monospaced)`), so all live
  numbers get the readout voice with zero call-site discipline.
- Scale unchanged: hero `.largeTitle bold`, card values `.title3 bold`,
  labels `.caption` secondary, headers `.caption` UPPERCASE + tracking.

### 2.3 Shape & space — machined, not soft (v2.0)

Instrument hardware is rectilinear. Two radii, both tokens:

- `Theme.corner` = **10pt** — cards, sheets, panels, the clock pill.
- `Theme.controlCorner` = **6pt** — buttons, badges, stepper keys, chips.
- **No capsules, no circles** on controls. Meters are rectangular gauge
  tracks (2pt radius). Screens keep 16pt gutters, 12pt card spacing,
  14pt card padding.

### 2.5 Instrument detailing (v2.0)

All drawn UI — hairlines and rectangles. **No images, no gimmick
graphics, no texture.**

- **Gauges:** `MeterBar` is a rectangular track with graduation cuts
  every 10% and a needle (1.5pt, overshooting the track) at the value.
- **Placards:** `SectionHeader` = icon, UPPERCASE label, then a hairline
  rule running to the card edge. (Panel index numbers were tried and
  removed 2026-07-18 — they read as serial-number noise.)
- **Turbine chart:** the expense-share ring is a turbofan face — 24
  swept blades (shaded root→tip) around a spinner hub inside a nacelle
  ring. Blade color comes from the category owning its angular slot, so
  blade count reads share; the legend carries exact percentages. Still
  pure drawn geometry.
- **Charts** keep their grid + axis labels; ticks live on the gauges.

### 2.4 Motion & haptics

- Standard animation: `.snappy` (≈0.3s). Number changes use
  `.contentTransition(.numericText())` — the "departure board roll."
- Meters animate to new values; never jump.
- Buttons scale to 0.95 while pressed + light impact haptic.
- Sim speed changes: selection haptic. Weekly settle: numbers roll (free,
  via ticker components). Event card arrival: sheet + medium impact (future).
- Never animate more than the value that changed — no full-screen reflows.

---

### 2.6 Borders, gradients & game feel (v2.1)

**Borders are hierarchy, not decoration.** Cards stay borderless by
default. A 1pt gradient hairline (accent → transparent, top-leading →
bottom-trailing) plus a faint tinted glow marks the FEW surfaces that
deserve attention right now: the Dashboard hero, an event card being
dealt, a just-completed milestone, the celebration banner. Never more
than ~2 bordered surfaces on screen.

**Gradient masks** do quiet work: fading chart tops, softening the cut
edge of collapsed/scrolling content, and letting long lists breathe.
No texture, no images — gradients only ever shade existing geometry.

**The loop's wins must feel like wins (pure UI, no sim changes):**
milestone completion → sliding celebration banner with the reward;
quarter close → a "report card" sheet (grade from profit, streak,
reputation) that holds the clock; aircraft delivery → the fleet card
arrives with a transition. Motion budget: alive but calm — one-shot
animations on state changes, nothing perpetual, nothing animates while
the player is just reading.

## 3. Component library (`UI/DesignSystem/`)

| Component | Job | Rules |
|---|---|---|
| `GameCard` | universal surface | borderless, soft shadow; content builds inside |
| `TicketShape` / boarding-pass cards | routes as flight tickets | punched side notches + dashed perforation between "flight" and "stub"; big airport codes, plane on a dotted path (Flighty-inspired) |
| `SectionHeader` | placard labels | icon + UPPERCASE label + hairline rule to card edge |
| `TickerText` | any live number | SF Mono readout (enforced), numericText transition, auto-animates |
| `StatTile` | big number + caption | for hero stats; optional trend arrow |
| `MeterBar` | any 0–1 quantity | rectangular gauge: graduation cuts every 10%, needle at value; color = semantic health |
| `StarRating` | reputation/skill | half-star precision, amber |
| `StatusBadge` | short state pills | NEW/USED/LEASED, ON ORDER, warnings |
| `GameButtonStyle` | all actions | 6pt machined rect, accent fill (prominent) or 15% tint (quiet), press-scale + haptic |
| `PillStepper` | player-set numbers | −/+ round buttons around a ticker value |
| `SimClockPill` | floating sim clock | date + ⏸/1x/2x/4x segments in one floating capsule, bottom-trailing above the tab bar on every tab |
| `AircraftProfileView` | side-view aircraft art | parametric vector per archetype (Canvas); livery regions (fuselage / tail+engines / cheatline) painted from the airline's `Livery`; optional tail emblem (airline initial). Showroom planes wear `.factory` gray until owned |
| `SpeedControl` | sim speed | ⏸/1x/2x/4x capsule segments, selection haptic |
| `TrendChart` / `ProfitChart` / `LoadFactorSparkline` | sim dynamics | accent-tinted line + soft gradient fill |

**The sim clock floats.** No persistent header — screens open with their
content, Flighty-style. The clock + speed control live in one floating pill
at the bottom-trailing corner, one thumb-reach away on every tab. Cash lives
in the Dashboard hero (and the Money tab), not in chrome.

---

## 4. Per-screen application

- **Dashboard (sky):** hero cash/net-worth card with rolling numbers and
  reputation stars; trust-fund card with 4 quarter-dots (the tutorial arc as
  a progress instrument); trends card with metric chips; last-week card.
- **Fleet (orange):** one card per aircraft — name + type, acquisition badge,
  wear/condition meters (wear fills toward red, condition drains toward red),
  check/sell/return actions. On-order planes show a delivery progress meter.
  Showroom is a pushed screen with New/Used/Lease chips and offer cards.
- **Routes (teal):** the tab opens on the **satellite globe** — NASA
  Blue Marble imagery (public domain, bundled, fully offline) textured
  onto a GPU-rendered SceneKit sphere (custom explicit-UV geometry,
  orthographic camera), dimmed via the material's multiply so arcs
  stay bright. Route bows, haloed city dots, and code chips draw in a
  Canvas overlay whose orthographic math mirrors the SceneKit camera
  exactly. Drag rotates, pinch zooms; zero per-frame CPU imagery cost.
  (2026-07-18: a flat CPU-drawn satellite map was tried and reverted
  same day — janky redraws and no 3D character.) Below it, each route is a
  **boarding pass** — big origin/dest
  codes with city names, a plane traveling a dotted path between them,
  punched notches + dashed perforation, and a stub carrying the load-factor
  meter, on-time/satisfaction chips, and the profit ticker. Detail:
  sparkline card, fare/frequency pill-steppers, assignment card.
  (Map view: post-M8.)
- **People (violet):** one card per pool — happiness and workload meters,
  plain-language overwork/strike warnings on the card itself, headcount/wage
  pill-steppers, skill stars.
- **Money (mint):** P&L chart card; last-week P&L as a proper statement
  (indented cost lines, bold profit row); loans card with remaining-balance
  meters.
- **Event cards:** modal sheet with icon medallion, title, flavor text, and
  full-width option buttons — a card being dealt, not an alert.

## 4.1 Aircraft art & livery (v1.3)

**Photography-first (v1.6).** Every aircraft is a real photograph
(`AircraftPhotoView`, `Resources/AircraftPhotos/aircraft_<type>.png`).
The catalog is **15 airframes in 3 engine classes**, named exactly like
the assets — **window count + engine kind** — and those two facts derive
every spec (`Balance.makeSpec`): seats, range, price, burn, crew,
maintenance, runway class, delivery wait. Count the windows, read the
engine, and you know the plane — design pillar 4 made literal.

| Class | Models (windows) | Seats | Fantasy |
|---|---|---|---|
| Turboprop | 5, 8, 10, 12 | 11–30 | day-one feeders, cheap ($1.9–6.2M), any runway |
| Propeller | 24×2, 28×2, 30×2, 32, 35 | 71–119 | the regional workhorses ($17–38M); "II" = Kestrel's rival airframes |
| Jet (regional) | 18, 24, 26ᴷ, 29ᴷ, 32, 42 | 49–155 | speed at class-2 cities ($15–89M); ᴷ = Kestrel wedge sizes |
| Jet (mainline) | 50, 60×2 | 200–264 | trunk-route flagships ($137–235M), metros only |
| Widebody | 55, 65, 75 | 231–375 | the international era ($215–512M), 11,000–14,600 km, twin-aisle |

**Livery on photos:** the airline's fuselage color tints the whole
airframe via `colorMultiply` — near-white keeps the natural paint, bold
colors read as a full repaint (the photos' white fuselages take tint
cleanly). Per-region repainting returns if/when custom 3D models are
commissioned; the Brand Studio keeps the full `Livery` model for that.
On-order and showroom aircraft always show natural factory paint.

**Model licensing rules (non-negotiable):**
- **CC0** (Sketchfab CC0 filter, Kenney.nl): use freely. Preferred.
- **CC-BY**: allowed with an in-app credits entry.
- **CC-BY-SA / GPL** (Wikimedia SVGs, FlightGear models): **never** —
  share-alike/viral terms are incompatible with a shipped App Store game.

**Brand Studio** (sheet from the Dashboard livery card): live aircraft
preview per archetype, one-tap preset schemes, and per-region ColorPickers.
Changes apply and autosave instantly; fleet cards repaint with a snappy
animation. Undelivered (on-order) and showroom aircraft stay in factory
gray — your paint goes on when the plane joins the fleet.

## 4.2 The Cabin Architect (v1.9)

The hero editor is a **booking-style seat map** (the airline seat-selection
pattern everyone can read): vertical cabin with the nose at top, scrollable
lengthwise. Column letters across the top (skip I), row numbers down both
sides, galley ovens as bulkhead shelves, wifi in the nose dome. Seat glyphs
have backrest + headrest + cushion, recolored by material. The hull width
follows the airframe (slim turboprop, wide jet), and geometry is honest:
pitch adds visible legroom, seat width visibly changes seats-abreast.
Chrome stays minimal: slim rulers, three swatches, one stepper, one toggle,
one readout strip (seats · comfort · refit · upkeep/wk).

**Clock rule:** any decision UI (sheets, dialogs, the architect) applies
`.holdsSimClock()` — the sim never advances while the player is deciding,
and their chosen speed resumes on dismissal. The clock pill shows a pause
glyph during holds.

## 5. Iteration log

- **v3.1 (2026-07-18, design-system branch): "Blueprint."** Dovetail
  re-theme, same day as (and replacing) v3.0 Warm Paper — the light
  editorial direction was rejected on sight. See §0 for the contract.
  Mechanics: tokens swapped to the ink/coal/carbon/steel stack; all
  shadows deleted; pills → 8px rects with white-filled primaries;
  SectionHeader became a mono eyebrow with cornflower icons;
  StatusBadge became a mono hairline tag; serif retired; charts and
  slices moved to the cornflower ramp. Verified by renders:
  Dashboard, Routes, Money, People, New Game.

- **v3.0 (2026-07-18, design-system branch): "Warm Paper."** Full
  re-theme to the Steep reference (§0). Shipped: light token layer
  (paper/mist/fog/hairline, ink/slate/ash, peach+sienna accent, muted
  functional trio); serif regular for every title-level voice
  (Font.display) with the sans capped at medium inside Font.game;
  pills (filled ink / ghost) replace machined rects; cards flat at
  24pt; meters quieted to rounded tracks; TickerText keeps monospaced
  digits only; boarding passes, the map, and the clock pill became
  floating artifacts (hairline ring + 10% shadow); hero card and Aunt
  Meera letters wear the peach/sienna kraft pairing; charts stroke
  sienna with the editorial warm-ramp palette. The satellite map keeps
  its own dark palette (it is imagery, not surface). Tab accents
  collapsed to ink.

- **v2.1 (2026-07-18): "Game Feel."** Shipped same day; audit below. Audit found People and Money carrying most of the
  clutter (People: ~7 competing elements per pool card — meters,
  warning banner, wage stepper, ad row, roster with per-person Fire,
  applicant rows; Money: six full cards, wrapping balance-sheet tiles,
  a long serif letter block). Dashboard's hero reads like any other
  card despite being the score. Repeated red destructive buttons and
  always-on warning banners add noise everywhere.

  **Phase 1 — primitives (DesignSystem):** `Theme.accentGradient(_:)`;
  `GameCard(highlight:)` gradient border + tinted glow (nil = today's
  borderless card); `.fadeEdges()` gradient-mask modifier;
  `CelebrationBanner` and `ReportCardSheet` components.
  **Phase 2 — de-clutter:** People applicants move to a per-role
  Hiring sheet (count badge on the card), roster collapsed by default,
  Fire demoted off the top level; Money letters collapse to the latest
  line + archive count, balance-sheet tiles get a non-wrapping compact
  money format, bank offers behind a disclosure; Fleet Sell/Return
  fold into the Service menu.
  **Phase 3 — hierarchy & wins:** hero card gets the standing gradient
  border; milestone completion banner (UI diffs completedMilestones);
  quarter report card on quarter close; delivery transition on fleet
  insert; one-shot accent flash on the weekly profit ticker.
  **Phase 4 — verify:** renders per screen; changelog + this log updated.
  **Shipped:** all four phases. Notes: applicants now open a per-role
  HiringSheet (clock held); TickerText readouts scale down instead of
  wrapping; Fleet's action row fades at its trailing edge; the fleet
  list animates deliveries in and sales out; the hero's border blinks
  profit-green for ~1s on weekly settle. Deferred: nothing.

- **v2.0 (2026-07-18): "Flight Deck."** Aerospace/mechanical direction,
  pure UI system — no gimmicks, no graphics. Typography split into
  placard (plain SF) + readout (SF Mono, enforced by `TickerText`);
  geometry machined (10pt cards / 6pt controls, capsules retired);
  gauges gained graduations + needles; headers became numbered placards
  with rules; the expense ring gained graduation cuts.

  **Implementation plan:**
  1. ✅ Tokens: `Font.game` → `.default`, new `Font.data` (mono),
     `Theme.corner` 18→10, new `Theme.controlCorner` 6.
  2. ✅ Components: TickerText mono enforcement; SectionHeader placard
     (index/icon/rule); MeterBar gauge; StatusBadge / GameButtonStyle /
     PillStepper / FormulaSheet close / city menu chips → machined rects;
     SimClockPill → 10pt panel.
  3. ✅ Screens: panel indices wired on Dashboard (01–03), Route detail
     (01–04), Money (01–06).
  4. ◻ Remaining: indices on Fleet/Showroom/People cards (repeated cards
     need loop indices); axis-tick pass on TrendChart/sparkline if the
     grid alone feels bare; boarding-pass stub typography recheck at
     Dynamic Type XXL; app-icon alignment with the machined language.

- **v1.7 (2026-07-16):** removed the Brand Studio (and the Dashboard
  livery card). Fleet photos render in natural paint; the `Livery` model
  stays in the sim for a future branding feature (M5 marketing is the
  natural home).
- **v1.6 (2026-07-16):** the full fleet. 15 owner-provided photos replace
  the interim five; catalog generated from window count + engine class
  (§4.1); jets gated to class-3 metro runways.
- **v1.5 (2026-07-16):** fleet photography. Owner-provided photos replace
  all generated aircraft art; five archetypes whose entire spec sheet
  derives from visible window count (§4.1). Removed the 3D pipeline and
  the Canvas illustrations.
- **v1.4 (2026-07-16):** real 3D aircraft. Sourced three CC-BY models
  (web search → Poly Pizza → GLB→USDZ with livery material renames),
  switched `AircraftShowcaseView` to offscreen-rendered cached images,
  and put 3D planes on Brand Studio, fleet, showroom, and dashboard.
- **v1.3 (2026-07-16):** realistic aircraft pass. Rebuilt the illustration
  from flat shapes to shaded premium art (gradients, gear, fairings,
  winglets, prop disc); added the SceneKit `AircraftShowcaseView` +
  `.usdz` drop-in contract for true photorealism (§4.1).
- **v1.2 (2026-07-16):** aircraft art + livery. Parametric side-profile
  planes (`AircraftProfileView`) on fleet/showroom cards; `Livery` in game
  state; Brand Studio screen (§4.1).
- **v1.1 (2026-07-16):** Flighty pass. Removed the persistent HUD header —
  screens open with content; the clock + speed control moved into a
  floating `SimClockPill` (bottom-trailing, above the tab bar). Removed
  ALL card borders — separation is surface contrast + soft shadow;
  hairlines only for internal dividers/perforations. Route cards became
  boarding passes (`TicketShape` with punched notches).
- **v1.0 (2026-07-16):** initial system. Future candidates: route map view,
  seat-config editor visual language (M4 hero screen), quarterly-letter
  stationery style (M6), number-roll sound design, app icon.
