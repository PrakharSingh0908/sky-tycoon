# SkyTycoon — UI Design System
### "The Ops Center" — v1.0, July 2026

Companion to [GAME_DESIGN.md](GAME_DESIGN.md) §7. This is the living contract
for how SkyTycoon looks, moves, and feels. Every screen and component follows
this document; changes to the vibe happen HERE first, then in code.
Implemented in `SkyTycoon/UI/DesignSystem/`.

---

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

### 2.2 Typography

- **Rounded** design (`.rounded`) everywhere — friendly, game-like, still clean.
- **All numbers are monospaced-digit** so ticking values never jitter layout.
- Scale: hero numbers `.largeTitle bold`, card values `.title3 bold`,
  labels `.caption` secondary, section headers `.caption` UPPERCASE +
  tracking, tinted with tab accent.

### 2.3 Shape & space

- Cards: 18pt radius, 14pt padding, 1pt stroke. Screens: 16pt gutters,
  12pt between cards.
- Buttons and badges are capsules. Meters are capsules.

### 2.4 Motion & haptics

- Standard animation: `.snappy` (≈0.3s). Number changes use
  `.contentTransition(.numericText())` — the "departure board roll."
- Meters animate to new values; never jump.
- Buttons scale to 0.95 while pressed + light impact haptic.
- Sim speed changes: selection haptic. Weekly settle: numbers roll (free,
  via ticker components). Event card arrival: sheet + medium impact (future).
- Never animate more than the value that changed — no full-screen reflows.

---

## 3. Component library (`UI/DesignSystem/`)

| Component | Job | Rules |
|---|---|---|
| `GameCard` | universal surface | borderless, soft shadow; content builds inside |
| `TicketShape` / boarding-pass cards | routes as flight tickets | punched side notches + dashed perforation between "flight" and "stub"; big airport codes, plane on a dotted path (Flighty-inspired) |
| `SectionHeader` | labeled card groups | icon + UPPERCASE caption in tab accent |
| `TickerText` | any live number | monospaced, numericText transition, auto-animates |
| `StatTile` | big number + caption | for hero stats; optional trend arrow |
| `MeterBar` | any 0–1 quantity | gradient capsule; color = semantic health |
| `StarRating` | reputation/skill | half-star precision, amber |
| `StatusBadge` | short state pills | NEW/USED/LEASED, ON ORDER, warnings |
| `GameButtonStyle` | all actions | capsule, accent fill (prominent) or 15% tint (quiet), press-scale + haptic |
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
- **Routes (teal):** the tab opens on the **network globe** — our own
  orthographic world drawn from public-domain Natural Earth data:
  ops-dark continents, faint graticule, atmosphere rim, glowing
  great-circle arcs (thickness = frequency, color = profitability,
  neutral while unstaffed), city code chips (served = teal dot). Drag
  rotates, pinch zooms; fully offline. Below it, each route is a
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
