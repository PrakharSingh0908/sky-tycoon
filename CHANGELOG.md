# SkyTycoon — Changelog

All notable changes to this project, with the reasoning behind them.
Format loosely follows [Keep a Changelog](https://keepachangelog.com); versions
track the build phases in [GAME_DESIGN.md](GAME_DESIGN.md) §8 and milestones in
[MVP_BACKLOG.md](MVP_BACKLOG.md). Every entry says **what** changed and **why**.

---

## [Unreleased]

### 2026-07-18 — Assign list shows where a plane is already flying

**Changed**
- Route detail's Assign Aircraft rows now surface each plane's current
  commitment: an "On DEL ⇄ BOM" badge plus a warning line ("Assigning
  here pulls it off DEL ⇄ BOM"), so reassignment is a deliberate steal
  rather than a silent one. In-shop planes show their remaining
  grounding, and the row's range figure is now payload-corrected
  (matching what assignment actually checks).


### 2026-07-18 — The roster: staff become individuals

**Added**
- Every pool carries a **roster** — a dropdown on each People card
  listing each person by name with skill, wage, and hire date, and a
  per-person Fire button (which stings pool morale a little; people
  notice). Hired applicants keep their name and negotiated wage;
  generated hires get seeded identities. Invariant enforced everywhere
  (hiring, firing, attrition, setHeadcount): members.count == headcount,
  and the pool's aggregate wage/skill are recomputed from the roster —
  the crew-hours sim still runs on aggregates, unchanged. Attrition now
  removes seeded-random named members. "Fire one" is gone; you fire
  someone. (Save shape changed — dev reset. Suite: 57.)


### 2026-07-18 — Buy an aircraft straight from route assignment

**Added**
- When a route has nothing that can fly it (empty fleet, or every plane
  out of range/runway class), the Assign Aircraft card explains why and
  offers **"Get an aircraft for this route"** — pushing a route-aware
  Showroom where every offer (new/used/lease) carries a fit badge:
  green "Fits DEL ⇄ GOI", or the reason it can't ("Beyond range",
  "Runway too short at GOI"). Fit uses the standard cabin's
  payload-corrected range and the same runway rules as canOperate, so
  the badge never promises what assignment would refuse.


### 2026-07-18 — Polish: arced routes, zoomed map, days on the clock, route P&L up front

**Changed**
- Route map camera zooms to India (globe zoom 2.6 → 4.8 after a second pass) so the network
  fills the card, and routes draw as **flight-map bows** (quadratic arcs
  lifted from the chord, always bowing north) instead of near-straight
  geodesics — at domestic zoom a true great circle reads as a train
  track, not a flight. The unused slerp helper was removed.
- The sim clock pill shows the day ("Y1 W31 · Thu"), derived from the
  tick accumulator's progress through the week — presentation only, the
  sim still advances in whole weeks.
- Dashboard's Last Week card lists **per-route P&L** (route margin +
  load factor, best first) under the headline numbers, so the network's
  winners and losers are visible without leaving the first screen.

### 2026-07-18 — M8: new-game flow, app icon, playtest sign-off — the MVP is feature-complete

**Added**
- **New-game screen** (verified live in the simulator): airline name
  entry, the aunt's hook line, and the five-country list — India
  playable, the other four showing their one-line fantasies behind
  "Coming soon" badges, per the GDD's v1.0 setup. The app now boots to
  it when no save exists; a save skips straight to the game.
- **App icon**: custom-drawn 1024² mark (ops-navy globe, dotted teal
  great-circle, white airliner silhouette) — drawn as vector paths, no
  SF Symbols (their license excludes icon use). Installed for light and
  dark appearances; launch screen remains Xcode-generated.

**Decided**
- Tick driver stays a 30 Hz `Timer`; GDD §9 amended with the reasoning —
  with 8-second weekly ticks, `CADisplayLink` precision buys nothing but
  battery drain, and determinism never depended on the driver.

**Playtest (the M8 archetype runs, 160 weeks each, sim-driven)**
- *Negligent* (no staff, no checks, gouging fares): bankrupt, 2.2★,
  1/10 milestones. *Cautious* (leased propliner, market fares, checks):
  survives solvent, +$1.19M, 7/10 milestones, arc failed — safe doesn't
  win the fund. *Aggressive* (used propliner on credit, yield
  management, marketing, expansion): most net worth (+$1.81M, two
  aircraft) while flirting with insolvency; the arc remains
  wire-crossing hard but provably winnable (M6 verification run).
  Outcomes rank correctly and no Balance constants needed changing.
- Bonus finding, kept as design: a lone small turboprop cannot cover HQ
  overhead — feeders only pay inside a network; the viable first plane
  is a propliner. The P&L explainers (M7) make this discoverable.

**Remaining for TestFlight (user actions)**: create the App Store
Connect record and upload; add the `SkyTycoonTests` target in Xcode
(55 tests authored, never yet executed).

### 2026-07-18 — M5 marketing + M7 money depth, unit economics, and honest formulas

**Added — M5 marketing**
- `brandAwareness` (0–100) fed by a weekly budget slider (Money tab, up
  to $60k/wk) with diminishing returns (gain = 8×s/(s+60k)), decaying
  3%/week unspent; its own P&L line. Awareness scales the brand
  multiplier ±(−3%…+9%) around a neutral 25 — bounded tight so the M6
  arc calibration holds. *Measured: 26 weeks at $40k lifts load factor
  0.60 → 0.64 and fades 70 → 53 after 9 silent weeks — the GDD's
  "launch push fills planes, stopping spend fades" criterion.*

**Added — M7 money depth**
- **The bank**: three offers (Starter $2M / Expansion $8M / Fleet $20M,
  distinct rates and terms) behind one lending limit (debt ≤ $2M + 1.2 ×
  net worth) — replacing the naive $1M/$5M buttons.
- **Balance sheet card**: cash, fleet book value, debt, net worth with
  its sparkline.
- **Tap any number** (pillar 4): every P&L statement line opens a
  formula sheet with the player's live numbers (per-route revenue/fuel,
  per-pool wages, per-plane maintenance with the wear/condition factors,
  amortization, lease, cabin, marketing). Route detail gets "Why these
  numbers?" — the full demand decomposition (gravity × growth × season ×
  brand × price × events → pax).

**Added — unit economics per route (route detail)**
- Revenue/fuel/margin per week, margin per flight, seats vs demand, and
  **breakeven load factor vs actual** — the gap that IS the business.
- Architecture guarantee: the tick's route loop was refactored onto ONE
  shared `computeEconomics` function that `routeEconomics()` (the UI
  path) also calls — the explanation can never drift from the sim.

**Changed — the fare↔satisfaction link, stronger and visible**
- Price fairness steepened (1.6 − 0.8 × fare/reference, clamped 0–1) and
  surfaced as a live meter under the fare stepper ("18% under market").
  *Measured: 0.8× fares → satisfaction 69 vs 1.3× → 64 — while the
  gouger nets $97k vs $54k margin. A real dilemma, not a free lunch.*
- Save format: marketing fields + per-route revenue/fuel (dev reset).
- 5 tests (suite: 55).

### 2026-07-18 — Milestone 6: the objectives layer

The narrative spine (GDD §3.1 + §6): letters, resolution, milestones,
fail states.

**Added**
- **Letters from Aunt Meera**: one per quarter close, tone keyed to
  performance (proud / encouraging / worried / stern, plus triumphant and
  heartbroken arc finales), written in-voice with the quarter's numbers
  substituted. Archive on the Money tab, serif stationery styling,
  capped at 16.
- **Trust-fund resolution, both ways**: 4 consecutive P&L-positive
  quarters → the fund converts (story event: +$500K gift, +0.25★) —
  "Aunt's Approval". Deadline passes → the remaining fund (up to the
  original $2M) is clawed back and hard mode begins. Both fire as
  pausing `.story` events (never drawn from the deck).
- **10 Layer-1 milestones** with cash rewards ($15–75K), checked every
  tick, paid once, never blocking; Dashboard tracker shows the last
  completed + next three.
- **Fail states**: bankruptcy (8 consecutive insolvent weeks with no
  sellable assets) freezes the sim behind a full-screen "Grounded"
  overlay with restart; reputation-collapse warning banner below 2.0★.
- `GameEngine.restart()` — fresh airline, same name.
- 5 tests: milestones pay once, quarterly letters + tones, success
  conversion, deadline withdrawal, bankruptcy spiral + restart.

**Changed — balance (the sims spoke, again)**
- 160-week arc simulations showed the trust-fund arc was UNREACHABLE:
  wear accrued so fast a plane needed a check every ~3 weeks, used-plane
  maintenance ran up to 2×, and thin margins couldn't survive seasonal
  troughs. Tuned: wear rate ÷5 (heavy-check territory in ~6 months),
  used-condition maintenance multiplier 2.0 → 1.6 max, demandK 450 → 520.
  *Verified: a disciplined single-plane airline using yield management
  (raising fares on a full plane, $76 → $116) now converts the fund at
  the final quarter — tense but winnable, and the winning skill is
  exactly the one the game wants to teach. Lazy play still fails; a
  reckless jet lease still ends in bankruptcy in ~12 weeks.*
- Save format: objectives fields added (dev saves reset).

### 2026-07-18 — Milestone 3: the event deck

Replaces the single placeholder fuel card with the real system (GDD §4.7).

**Added**
- **Effect system** (`EventEffect`, enum with associated values): cash,
  happiness (per-pool or all), satisfaction, reputation, wage raises,
  timed fuel/demand modifiers, seeded-random groundings and wear hits —
  replacing the old flat deltas.
- **Timed effects** (`GameState.activeEffects`): "fuel +30% for 6 weeks"
  style modifiers applied inside the tick (fuel cost and demand formulas)
  and aged out in bookkeeping. Shown on the Dashboard as an "Ops
  conditions" card with weeks-remaining.
- **The 12 MVP cards** as data in `Balance.eventDeck`, covering every GDD
  category: fuel spike / oil glut (market), cyclone (weather), cabin-crew
  raise + strike vote (labor), engine fault + surprise grounding
  (technical), VIP charter + festival rush (opportunity), safety audit
  (regulatory), viral crew + baggage meltdown (PR). Every option's cost
  is visible in its label; consequences are described, not quantified.
- **State-shifted weights** — events read as consequences, not dice:
  technical cards scale with fleet wear (up to ~3×) and understaffed
  maintenance; labor cards scale with strike-risk and low-morale pools
  (the M2 `strikeRiskPools` hook finally consumed). The surprise-grounding
  card only exists at all for airframes past 60 wear — **neglecting heavy
  checks finally has a consequence**, closing the tracked balance hole.
- **Guard rails**: no events in the first 6 weeks; in year 1, never a
  negative event the week after a negative event; sim auto-pauses on fire
  (already in place).
- Event card UI: category icon (wrench/cyclone/megaphone…) and green
  tint for opportunity cards.
- 6 tests: cross-engine deterministic draws with resolutions, firing
  rate, wear-driven weight shift, year-1 guard rail, timed-effect
  apply/expire, grounding effect.

**Measured (104-week runs, seeds 42/777/12345):** 13–18 events per two
years (one every ~6–8 weeks), all seven categories appearing, technical
cards elevated on an unmaintained fleet exactly as designed, zero
guard-rail violations, economy stays viable even always taking the
"accept consequences" option (cash positive, reputation 3.7★).

**Changed**
- Save format: `GameState` gained `activeEffects` and the guard-rail
  marker; `GameEvent`/`EventOption` restructured (dev saves reset).

### 2026-07-18 — Seat-tier renders in the Cabin Architect

**Changed**
- Cabin material tiers renamed to match the new owner-provided seat
  assets: Fabric/Leather/Premium → **Economy/Premium/Luxury** (enum
  cases too — dev saves reset). Same economics (comfort 0/0.12/0.20,
  $800/$1,600/$2,800 per seat install, $6/$9/$14 weekly upkeep).
- The Cabin Architect's material swatches are now the seat renders
  themselves (blue shell / brown leather / black recliner) with a
  selection ring and haptic; floorplan seat colors are sampled from the
  assets so the map matches the swatch you picked.

### 2026-07-18 — Route map v2: the open-source ops globe

Direction: replace Apple Maps with an open-source world. Chosen approach
(user-confirmed): **draw our own globe** from public-domain Natural Earth
data rather than adopt a map SDK.

**Changed**
- `RouteMapView` is now a fully custom orthographic globe rendered in
  Canvas from bundled Natural Earth 110m land polygons (138 KB, 5,143
  points — trivially re-projected per frame): ops-dark continents,
  faint graticule, atmosphere rim, glowing great-circle route arcs
  (slerp), city dots + code chips. Drag rotates, pinch zooms.
  *Why over MapLibre/OSM tiles: zero dependencies (no pbxproj change),
  zero tile-server terms for a shipped game, works fully offline,
  renders in previews (no async tiles), style matches the design system
  exactly, and one code path scales from India to the whole planet for
  the international era.*
- MapKit dependency dropped from the map (City keeps its plain-degree
  coordinates in the sim; no save change this time).

**Added**
- `Resources/WorldData/ne_110m_land.geojson` — Natural Earth, public
  domain (credited in CREDITS.md).

### 2026-07-18 — The route map: satellite globe with geodesic arcs

**Added**
- `RouteMapView` atop the Routes tab (GDD §7 tab 3, delivered ahead of
  M8): Apple MapKit satellite globe (`.imagery(elevation: .realistic)`)
  with the network drawn as **geodesic great-circle arcs** — thickness =
  frequency, color = profitability (green/red, neutral while unstaffed) —
  and city markers with code chips (served cities glow teal). *Why
  MapKit over Mapbox/Google: zero dependencies, no API keys, native
  SwiftUI, and the 3D globe ships out of the box — the "best
  plug-and-play world model" is the one already in the OS. It also
  scales to the five-country/international era for free.*
- `City` gained real airport coordinates (IGI, CSMIA, Kempegowda, …) as
  plain degrees in the sim layer — also the future source for computed
  distances when more countries arrive. (Save format changed → dev
  saves reset.)
- Dev/test launch argument `-openTab <tab>` to start on any tab
  (used for simulator-driven verification).

**Verified in the running app** (simulator, seeded mid-game save):
tiles load, DEL–BOM draws thick green, unstaffed routes draw neutral,
camera frames India with globe curvature.

### 2026-07-17 — Catalog expansion: regional jets + widebodies (24 aircraft)

Nine new owner-provided renders plugged in via the window-count formulas.

**Added**
- **Regional jets** (the 30–200-seat gap, closed): 18/24/32/42 Jet from
  Meridian, with Kestrel's 26/29 Jet wedged between the rungs — the
  same-segment competition dynamic per direction. The propliner-vs-jet
  decision now exists at every size: 24 Propeller (71 seats, $17.1M,
  480 km/h) vs 24 Jet (71 seats, $26.1M, 830 km/h).
- **Widebodies** (the international era's heavies): 55/65/75 Widebody,
  new `EngineKind.widebody` — 900 km/h, 1.6× range (11,120–14,640 km,
  787/777 territory), 9-abreast twin-aisle, $215–512M, delivery capped
  at the GDD's 40-week max.
- Cabin Architect draws twin-aisle cabins: abreast ≥ 7 splits into three
  blocks (2-3-2 / 2-4-2 / 3-3-3 all emerge from one formula), letters
  skip I correctly across blocks (A B C · D E F · G H J) — verified in
  a 75 Widebody render.

**Changed**
- Runway rule is now size-based, not engine-based: widebody or ≥ 45
  windows → class 3 (metros), ≥ 14 windows → class 2, else class 1.
  *Why: regional jets must serve class-2 cities or they'd have no niche
  against the propliners.* Existing planes' requirements are unchanged.
- No save reset this time — `GameState` didn't change shape.

### 2026-07-17 — Payload-range, exit limits, and rival manufacturers

**Added — payload-range tradeoff (GDD §4.2 amended)**
- Effective range = brochure range × (1.15 − 0.30 × cabin fill), capped
  at +10%: sardine layouts pay −15% range, airy "ferry" layouts gain up
  to +10%. `canOperate` (and therefore assignment everywhere) uses the
  payload-corrected figure. *Measured: a standard 8 Turboprop (1,780 km
  brochure) can't make DEL–MAA at 1,770 km — refit airy and it can. The
  60 Jet spans 6,375–7,176 km across layouts.* Fleet cards show effective
  range; the Cabin Architect readout shows effective vs brochure; the
  route menu hints "an airier cabin could reach" where applicable.
- Refitting heavier than an assigned route allows unassigns the aircraft
  (engine-enforced), with a warning shown in the architect beforehand.

**Added — certified exit limit (GDD §4.2 amended)**
- `CabinLayout.seats` is hard-capped at `spec.maxSeats`; the architect
  readout shows "seats · limit N". Guard test sweeps every archetype at
  the densest configuration.

**Changed — "II" variants are the rival maker (GDD §4.1 amended)**
- Kestrel Aeronautics now sells all II airframes, competing with
  Northline (props) and Meridian (jets) in the same size classes.
  Loyalty pools are per maker, so fleet commonality vs shopping around
  is a real decision. Sets up the future 3–4-major-manufacturer roster.
- Tests: exit-limit sweep, ferry-config flip, refit-unassign guard,
  per-maker loyalty separation (suite now 39).

### 2026-07-17 — Cabin Architect v2: the booking-style seat map

Reference-driven redesign (real airline seat-selection maps): the cabin is
now **vertical, nose at top, and scrollable** like the seat maps everyone
already knows how to read.

**Changed**
- Seat glyphs with backrest, headrest band, and cushion lip replace flat
  rectangles; material recolors them (fabric blue / leather tan / premium
  violet).
- Column letters across the top (A B C · D E F, skipping I like real
  airlines) and row numbers down BOTH sides; galley ovens draw as bulkhead
  shelves with fork/coffee/flame icons; wifi shows in the nose dome.
- The hull narrows to the airframe: a 2-abreast turboprop draws a slim
  fuselage, a 6-abreast jet a wide one (seat cell size is capped and the
  cabin centers itself).
- The geometry stays honest: pitch visibly adds legroom between rows, and
  widening seats to 18″ visibly drops a jet from 6-abreast to 5 — the
  seat-count consequence is right there in the drawing.

### 2026-07-17 — Fleet: range on every card + assign-to-route from the fleet

**Added**
- Range in every fleet card's spec line ("… · 2,000 km range · …") — the
  plane's defining constraint was invisible outside the showroom.
- **Route menu** on each fleet card: every route listed with its distance;
  flyable ones assign on tap, unflyable ones disabled with the reason
  ("beyond range" / "runway too short"), current route checkmarked, plus
  Unassign. Backed by new engine API — `canOperate(aircraftID:routeID:)`
  is now the single source of truth for assignment rules (assign() uses
  it too), and `unassign(aircraftID:)` pulls a plane off its route.
- Status badge now names the route ("Flying DEL ⇄ BOM"), not just "Flying".

**Changed**
- Fleet card actions consolidated: Line/Heavy check moved into a Service
  menu (with price and downtime visible), and the action row scrolls
  horizontally instead of truncating labels.

### 2026-07-17 — Cabin Architect, seller loyalty, and the clock holds for decisions

**Added — Cabin Architect (GDD §4.2 as amended, replaces the density slider)**
- `CabinLayout` in the sim: seat pitch (28–36″), seat width (16–20″),
  material (fabric/leather/premium), galley ovens (0–3, each displaces a
  seat row), wifi. Geometry is honest: cabin length comes from the
  airframe's densest configuration, seats-abreast from the airframe width
  — so seats, comfort, refit cost, and weekly upkeep all DERIVE from the
  layout. Comfort feeds route satisfaction through the existing §4.5
  weights; upkeep is a new "Cabin & catering" P&L line.
- `refitCabin` engine action: costs the install price, grounds the plane
  1 week. New/used/leased planes arrive with a sensible standard interior.
- `CabinArchitectView` — layout-first per direction: a to-scale top-down
  fuselage drawing (seats around the aisle, galley blocks, material
  colors, wifi marker) that redraws live; slim rulers and swatches below,
  one readout strip (seats · comfort · refit · upkeep/wk). Opened from a
  Cabin button on fleet cards. *Measured tradeoff on a 30 Propeller:
  standard = 84 seats/comfort 0.45/$1.1k-wk; plush = 51 seats/comfort
  0.83/$3.1k-wk and satisfaction 68 → 77 over 20 weeks.*
- Old `comfortConfig` removed; `Aircraft.cabin` replaces it (save resets).

**Added — manufacturer loyalty (retried request)**
- Three sellers by engine class (Vayu Aeroworks / Northline Regional /
  Meridian Jets). Every factory-new order earns 3% off the next from that
  seller, capped at 12% (`GameState.sellerOrders`). Showroom shows the
  seller, the loyalty badge, and the struck-through list price; used and
  leased aircraft are third-party deals and earn nothing. *Why new-only:
  it's a manufacturer relationship (GDD §4.1) and it nudges fleet
  commonality, a real airline strategy.*

**Added — clock holds during decisions (completes the previous request)**
- `beginInteraction`/`endInteraction` holds on the engine (counted, so
  nested sheets stack); the tick loop skips while held and the player's
  chosen speed resumes automatically. Wired to: negotiation sheet (an
  applicant's patience no longer drains mid-haggle), acquisition
  receipts, route-cancel dialog, and the Cabin Architect. The sim clock
  pill shows a pause glyph while held.
- Tests: loyalty discount growth/cap/charged price, cabin seat/comfort/
  upkeep tradeoffs and galley displacement, refit cost + grounding.

### 2026-07-16 — Recruitment: job ads, applicants, and negotiation

Replaces the headcount stepper with the GDD §4.4 amendment (recorded there).

**Added**
- `JobApplicant` (individual skill, asking wage, hidden flexibility,
  irritation, patience weeks) + `GameState.jobPostings/applicants`;
  applicant generation runs in the weekly tick from the seeded RNG.
- Engine actions: `postJobAd` ($2k, ~4 weeks, one per role at a time),
  `hireApplicant` (at asking), `negotiate(offer:)` → accepted / countered
  / walkedAway. Two 40% lowballs guarantee a walk (irritation ≥ 100);
  offers below 75% may insult stubborn candidates into leaving instantly.
  *Why hires blend into the pool average (wage & skill): keeps M2's
  aggregate crew-hours sim untouched while making every negotiation
  matter — bargain hires drag the pool wage down, squeezed hires dent
  morale slightly.*
- People tab: "Post job ad" / ad countdown, applicant rows (skill stars,
  asking wage, patience), Hire and Negotiate buttons, negotiation sheet
  with offer slider, live patience meter, and in-character responses.
  Headcount stepper replaced by a Fire-one button (hiring is earned now).
- 5 tests: deterministic applicant generation, pool blending, instant
  accept at asking, guaranteed walk on repeated lowballs, applicant/ad
  expiry.

### 2026-07-16 — UI: trust fund moved to Money; route tickets get actions

**Changed**
- Aunt's Trust Fund card moved Dashboard → Money (per direction — it's a
  financial goal; the Dashboard keeps pure vitals).
- Boarding-pass route cards: the whole card is no longer one tap target.
  The stub now carries two buttons — **Set up route** (opens the detail
  editor) and **Cancel route** (destructive, with a confirmation dialog).
  New `GameEngine.closeRoute`: assigned aircraft go idle (grounded ones
  finish their checks), the route is removed.

### 2026-07-16 — Removed the Brand Studio

**Removed**
- `BrandStudioView` and the Dashboard "Your livery" card, per direction.
  Fleet photos now render in natural paint everywhere. The `Livery`
  struct and `setLivery` stay in the sim — saves keep the field, and
  M5's marketing/branding work is the natural place to revisit airline
  identity if wanted.

### 2026-07-16 — Showroom acquisition receipts

**Added**
- Confirmation sheet after every successful showroom acquisition
  (`AcquisitionReceiptView`): kind-specific title and icon ("Order
  placed" / "Welcome to the fleet" / "Lease signed"), aircraft photo
  (factory paint for orders — your livery goes on at delivery), assigned
  registration, itemized amount, arrival ("in 18 weeks" / "in your hangar
  now"), lease return fee where relevant, and live cash remaining.
  Success haptic on presentation. *Why: the buy buttons mutated state
  silently — spending $23M deserves a moment, and the receipt teaches
  the cost/arrival consequences of each acquisition path.*

### 2026-07-16 — The full fleet: 15 aircraft in 3 engine classes (v1.6)

New owner-provided assets (named `<windows> <engine>`) replace the interim
five photos; the catalog is generated from exactly those two facts.

**Added**
- 15 aircraft types: Turboprops 5/8/10/12 windows (11–30 seats,
  $1.9–6.2M — the day-one planes), Propellers 24/24 II/28/28 II/30/
  30 II/32/35 (71–119 seats, $17–38M — the ATR-class workhorses; "II"
  variants burn 4% less and cost 6% more), Jets 50/60/60 II (200–264
  seats, $137–235M — late-game flagships).
- `EngineKind` (turboprop/propeller/jet) in the sim: drives cruise speed,
  burn base, price factor (props 0.85× — efficient but slower at
  480 km/h; jets 1.30× at 830 km/h), and maintenance factor.
- **Jets require runway class 3** — only the five metro airports. *Why:
  gives the late game a real constraint (trunk routes only) and makes
  the propliner fleet permanently relevant on class-2 cities.*

**Changed**
- Economy guards re-verified by year-long sims: workhorse 30 Propeller on
  DEL–BOM = 72% LF, +$71k/wk route profit; leased 24 Propeller covers its
  $30.8k/wk lease 2.4×. Tests remapped to the new catalog.
- Save format: `AircraftType` cases changed again (dev saves reset).

### 2026-07-16 — Fleet photography + window-count archetypes (v1.5)

Direction: replace all generated aircraft art with the owner's five
aircraft photographs, and derive each plane's stats from its visible
window count.

**Added**
- Five archetypes replacing the previous three, one per photo, every spec
  derived from window count in `Balance.makeSpec` (formulas documented at
  the definition — pillar 4): P-4 Sparrow (4w/9 seats), P-7 Courier
  (7w/16), J-12 Envoy (12w/30, first jet), P-18 Monarch (18w/49),
  J-28 Horizon (28w/87). Seats = windows × (2 + 0.04·windows); range,
  price, burn, crew, maintenance, runway class, delivery wait all follow.
  *Why formula-over-table: one tunable curve instead of five hand-kept
  spec sheets, and the window count is visible in the art — players can
  literally count their capacity.*
- `AircraftPhotoView`: bundled photos with fuselage-color tint
  (`colorMultiply` — the white airframes take tint like a repaint);
  natural factory paint for showroom/on-order planes. Used on fleet,
  showroom, dashboard, and Brand Studio.

**Removed**
- The entire 3D pipeline (`AircraftShowcase.swift`, bundled .usdz models,
  their CC-BY credits) and the Canvas illustrations
  (`AircraftProfile.swift`). *Why: the photographs beat both on looks
  with zero moving parts. The 3D drop-in contract remains documented in
  git history if commissioned models ever revive it.*
- Brand Studio's tail/stripe pickers (photos can't repaint regions) —
  presets + full-airframe paint tint remain.

**Changed**
- Balance recalibrated for the new seat counts (biggest plane 87 seats
  vs 220 before): price curve $150k·seats·(1+seats/80) keeps day-one
  affordability (used P-4 ≈ $0.5–0.9M) and the flagship at $27M.
  Economy guard tests updated: flagship J-28 trunk-route year and the
  P-18 lease-viability case both hold; range-gate test now uses the
  P-4 (1,340 km) vs DEL–MAA (1,770 km).
- Save format: `AircraftType` cases changed (dev saves reset).

### 2026-07-16 — Real 3D aircraft with runtime liveries (v1.4)

Direction: no more 2D aircraft art — real 3D models, recolorable per
airline livery.

**Added**
- Three bundled 3D aircraft (`Resources/AircraftModels/*.usdz`), sourced
  by web search with license verification (all **CC-BY 3.0**, attribution
  in CREDITS.md + Brand Studio footer):
  turboprop = "Small Airplane" (Vojtěch Balák), small narrowbody =
  "Small plane" (Eik Røgeberg), large jet = "Boeing 747" (Miha Lunar),
  via poly.pizza. *Selection criteria: direct downloads, flat named
  materials (recolorable — texture-atlas models were rejected because
  liveries can't repaint baked textures), and silhouette fit per
  archetype. Sketchfab's more realistic models are login-gated CC-BY;
  the pipeline accepts them later without code changes.*
- GLB→USDZ conversion pipeline on stock macOS (`usdcat`/`usdzip`) with
  livery material renames done in the .usda text — documented in
  DESIGN_SYSTEM.md §4.1 so any future model drops in the same way.

**Changed**
- `AircraftShowcaseView` now renders the liveried model OFFSCREEN via
  `SCNRenderer` into an `NSCache`d transparent image — one render per
  (archetype, livery). *Why not live `SceneView`: it has no intrinsic
  size, doesn't composite in preview snapshots, and a Metal view per
  list row wastes battery. Pre-rendered images are how Flighty ships
  aircraft art.* Studio light rig (directional key + ambient floor),
  orthographic nose-right camera, per-model orientation corrections
  (each source model's authored axes differ — verified by test renders).
- Fleet cards, showroom, dashboard livery card, and Brand Studio all
  show the 3D planes now; the Canvas illustration remains only as the
  automatic fallback for archetypes without a bundled model.

**Known limits (recorded honestly)**
- The 747's paint maps fuselage only (its source model has no separate
  tail material). The models are stylized low-poly — the best
  license-clean art obtainable without commissioning; upgrading realism
  is a pure asset swap per the drop-in contract.

### 2026-07-16 — Realistic aircraft pass (design system v1.3)

Feedback: the flat v1.2 planes read as "low quality" against Flighty's
photoreal renders. Flighty's images are pre-rendered 3D models, so this
lands both the honest path to that bar and a big illustrated upgrade now.

**Changed**
- `AircraftProfileView` rebuilt from flat shapes to premium illustration:
  vertically gradient-shaded fuselage with a blurred specular crown,
  correct fineness ratios per archetype, cockpit windscreen, door
  outlines, belly fairing, far wing + winglet behind the fuselage,
  flap-track fairings, sharklets, landing gear with twin main wheels,
  soft ground shadow, livery sweep on the tail cone. Turboprop is now a
  proper ATR silhouette: high wing, T-tail, roof-mounted nacelle, prop
  with translucent spinning disc (lower blade hidden behind the body).
  Livery colors are auto-shaded (computed light/dark variants) so ANY
  brand color renders with depth. Verified across all archetypes + both
  liveries in renders.

**Added**
- `AircraftShowcaseView` (SceneKit): loads `aircraft_<archetype>.usdz`
  from the bundle, repaints materials named `livery_fuselage`/`livery_
  tail`/`livery_stripe` at runtime, orthographic side-on studio camera —
  and falls back to the illustration when no model is bundled. The Brand
  Studio preview uses it, so photoreal lights up the moment a model
  lands, with zero code changes. Drop-in contract + licensing rules
  (CC0 preferred, CC-BY with credit, never CC-BY-SA/GPL) documented in
  DESIGN_SYSTEM.md §4.1.

### 2026-07-16 — Aircraft art & livery (design system v1.2)

**Added**
- `AircraftProfileView` — parametric side-profile aircraft drawn in SwiftUI
  `Canvas`, one silhouette per archetype (high-wing turboprop with prop
  disc, small/large narrowbody twin-jets). Livery regions (fuselage, tail
  fin + engines, cheatline stripe) are separately painted layers.
  *Why vector-in-code instead of open-source sprites: zero third-party
  licenses to manage, resolution independence, and live per-region
  recoloring that static art can't do. CC0 fallback (Kenney.nl) documented
  in DESIGN_SYSTEM.md §4.1 if richer art is ever wanted; CC-BY-SA sources
  (Wikimedia aircraft SVGs) explicitly ruled out for a shipped app.*
- `Livery` / `LiveryColor` in the sim state (plain RGB — sim stays
  UI-framework-free), `GameEngine.setLivery`, `.factory` and `.launch`
  presets. Cosmetic-only until M5 ties branding to marketing.
- **Brand Studio** (sheet from the Dashboard "Your livery" card): live
  aircraft preview with archetype switcher, six one-tap preset schemes,
  and per-region ColorPickers. Applies + autosaves instantly.
- Fleet cards show each plane in airline colors with the airline-initial
  tail emblem; on-order and showroom planes wear factory gray until they
  join the fleet (a small "delivery day" moment for free).

**Fixed**
- Preview segfaults after the `GameState` layout change — stale preview
  thunks in DerivedData, not a code bug (verified: sim + livery round-trip
  clean via direct execution). Cleared intermediates; documented here
  because it WILL happen again next time `GameState` gains fields.

### 2026-07-16 — Design system v1.1: the Flighty pass

Direction from playtesting the v1.0 UI: drop the chrome, lean into flight
iconography. All changes designed in DESIGN_SYSTEM.md first (iteration log
v1.1), then implemented.

**Changed**
- **Persistent HUD removed.** Screens open with content; cash moved into
  the Dashboard hero. *Why: the header ate 60pt of every screen and read
  as an app bar, not a game.*
- **Sim clock floats**: new `SimClockPill` (date + speed segments) pinned
  bottom-trailing above the tab bar on every tab. Date dims when paused.
  *Why: pause/play belongs near the thumb, and pairing it with the date
  makes it read as "the game clock," not a media control.*
- **All card borders removed** (Flighty-style): separation is surface
  contrast + soft shadow. `Theme.cardStroke` renamed `Theme.hairline`,
  legal only for internal dividers and perforations — the rule is in the
  design doc so borders can't creep back.
- **Route cards are boarding passes**: new `TicketShape` (even-odd fill
  punches real side notches) + `PerforationLine`; big airport codes with
  city names, a plane on a dotted path with km/frequency, and a stub
  carrying load factor, profit, and on-time/sat. *Why: the route list is
  the most-visited screen; making it feel like a wallet of tickets is the
  cheapest big win for "fun" — verified in renders.*

### 2026-07-16 — "The Ops Center": design system + full UI rebuild

The previous UI was stock `List`/`Form` — functional, but it read as a
settings app, not a game. This lands a proper design language and rebuilds
all screens on it. The sim layer is untouched.

**Added**
- **[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)** — the living design contract:
  dark ops-center palette, one accent per tab (GDD §7), rounded type with
  monospaced digits, motion/haptics rules, component inventory, per-screen
  application. *Why a document: "fun and tactile" decays into inconsistency
  unless the rules live somewhere reviewable. Vibe changes go there first.*
- `UI/DesignSystem/` component library: `GameCard`, `SectionHeader`,
  `TickerText` (departure-board number roll via `contentTransition
  (.numericText())`), `StatTile`, `MeterBar`/`MeterRow`, `StarRating`,
  `StatusBadge`, `GameButtonStyle` (press-scale + haptic), `PillStepper`,
  `GameScreen` scaffold, and **`GameHUD`** — airline, date, reputation
  stars, live cash ticker, and the speed control, persistent on every tab.
  *Why the HUD: cash and the clock visible everywhere is the single
  biggest "management sim" signal — the game is always running and one
  thumb-reach from pause.*
- All seven screens rebuilt as card stacks with meters, badges, and
  rolling numbers. Wear/condition/happiness/workload/load-factor are now
  glanceable gauges with semantic green→amber→red health colors.
- Preview support: `GameEngine.previewGame()` — a seeded 30-week mid-game
  state (worn clunker, lease, understaffed cabin) so every design preview
  renders with live-looking data and visible warnings.

**Fixed**
- **Crash: resolving any event card aborted the app.** `resolveEvent`'s
  happiness update read `state.staff` inside an optional-chained write to
  the same dictionary — a Swift exclusivity violation through
  `@Observable`'s `_modify` accessor (SIGABRT, "simultaneous accesses").
  Found because the new preview exercised the path; fixed with a
  read-modify-write local copy. *Lesson recorded: never read `state` in
  the RHS of an optional-chained write to `state`.*

### 2026-07-16 — Milestone 2: crews, understaffing, and real satisfaction

Before this, headcount only affected wages. Now people matter (GDD §4.4/§4.5).

**Added**
- Crew-hours model: each route's schedule demands pilot/cabin block hours
  (2 legs × cruise + turnaround), ground hours per departure, and HQ hours
  (base + per-aircraft + per-route). Compared against `headcount × 40h`
  → per-pool utilization, stored on `StaffPool.lastUtilization` for the UI.
- Understaffing consequences: airline-wide **punctuality** (0.97 base,
  −0.45 × weighted over-roster strain, −skill deficit; floor 0.20), and
  **overtime at 1.5×** for hours beyond capacity. An empty pool means
  contractors at 1.5× market rate — flights still fly, but expensively and
  late. *Why contractors instead of cancellations: MVP keeps "flights fly"
  simple, and it emerged nicely that hiring properly is CHEAPER than not
  hiring ($8.8k vs $12k/wk measured) — design pillar 1 made mechanical.*
- Happiness workload term: overworked pools drift down even at market wage
  (−50 × strain on the happiness target). Below 40: weekly attrition
  (probabilistically rounded via the seeded RNG — still deterministic).
  Below 25: the pool joins `strikeRiskPools`, ready for M3's event weights.
- Route satisfaction rebuilt on the GDD §4.5 weights: punctuality 35%,
  comfort 25%, service 20% (cabin skill × staffing adequacy), price
  fairness 15%, incidents 5% (placeholder until M3).
- **Airport slots enforced** (tracked starter issue): `openRoute` and
  `setFrequency` clamp to free weekly slots at both endpoints.
- People tab: workload/roster bar per pool (green/yellow/red), overwork
  warnings in plain language ("working 54% over roster — expect delays and
  overtime pay"), attrition and strike-risk alerts. Route detail shows
  punctuality and satisfaction.
- Tests: staffed-vs-unstaffed divergence, overwork → attrition, slot
  clamping and slot freeing.

**Measured (year-long sims)**: staffed = 92% punctuality, satisfaction 70,
reputation 3.76★; unstaffed = 24% punctuality, satisfaction 41, reputation
2.68★ and −$16k/wk. The exit criterion — "flying with nobody visibly hurts,
and the UI told you why" — holds.

**Changed**
- Save format: `StaffPool` and `Route` gained a field each (dev saves reset).
- `openRoute` now validates that both city IDs exist (previously a bad ID
  would crash the tick on a force-unwrap).

### 2026-07-16 — Economy audit: the game was unwinnable

A full re-audit of the sim before starting M2. Verified empirically by
simulating full years in-engine (RunCodeSnippet), not by feel.

**Fixed — balance (game-critical)**
- `demandK` 90 → **450**. *Why: at 90, DEL–BOM (the best route in the game)
  generated ~294 pax/week against ~1,960 turboprop seats — 10% load factor.
  Every possible opening move lost ~$80k/week; the trust-fund arc was
  mathematically unwinnable. Calibration derivation is documented next to
  the constant. Measured after the fix: 88–90% LF at reference fare.*
- `leaseRatePerWeek` 0.25% → **0.18%** of new price. *Why: at 0.25% a
  turboprop lease ($45k/wk) exceeded the route's best-case margin — leasing
  could NEVER break even, contradicting GDD §4.1 ("the safest first plane").
  Measured after: leased opening ≈ +$2k/wk P&L — viable but clearly worse
  than owning, which is the intended tradeoff.*
- Measured outcomes of all three openings after rebalance: used+loan ≈
  breakeven (worst-condition listing!), lease ≈ breakeven, new+big-loan
  ≈ −$58k/wk (correctly a trap — the GDD says buying new is aspirational).
  Growth, fare tuning, and better listings are the paths to profit.

**Fixed — bugs**
- `orderCheck` accepted `.onOrder` planes: a check flipped them to
  `.inMaintenance` and the countdown released them to service before
  delivery — a delivery-skip exploit. Now guarded + regression test.
- `assign` set a grounded plane's status to `.assigned` while it was still
  in the shop. Status now stays `.inMaintenance` until the countdown ends.
- Fuel burned per *configured* seat, so the comfort slider silently cut
  fuel 30%. *Why wrong: the airframe burns fuel regardless of cabin layout
  — this would have gutted the M4 seat-editor tradeoff. Fuel now scales
  with `spec.maxSeats`, plus a condition-based burn penalty (up to +15%)
  that GDD §4.1 specifies but was never implemented.*
- Routes tab default fare was `distance × 0.09` ≈ 36% above India's
  reference fare → priceResponse 0.57 → a new player's first route opened
  half-empty with no explanation. Default is now the reference fare.

**Added**
- Economy-viability regression tests: the intended openings (owned trunk
  route profitable on average over a full year incl. the seasonality
  trough; lease covers its payment but doesn't dominate owning) plus the
  delivery-skip exploit test. *Why: balance regressions are silent — no
  compiler error tells you the game stopped being winnable.*

### 2026-07-16 — Trend charts for sim dynamics

**Added**
- History buffers in the sim core: `GameState.cashHistory` and
  `reputationHistory` (260 weeks, alongside the existing `netWorthHistory`)
  and `Route.loadFactorHistory` (26 weeks).
  *Why: the sim's dynamism — demand seasonality, reputation compounding,
  lease drag — is invisible in single-number readouts. Time series make
  cause-and-effect legible, which serves design pillar 4 ("every number is
  explainable"). Buffers live in the sim (plain `[Double]`), charts in the
  UI, preserving the no-SwiftUI rule in `Simulation/`.*
- `UI/Components/TrendChart.swift` (Swift Charts): reusable `TrendChart`
  line+area view, `ProfitChart` (52-week profit bars + revenue line), and
  `LoadFactorSparkline` (0–100% domain).
- Dashboard: "Trends" section with a Net worth / Cash / Reputation metric
  picker. Money tab: 52-week P&L chart above the line items. Route detail:
  load-factor sparkline (the GDD §7 tab-3 sparkline, delivered early).
- This changelog. *Why: the balance constants and sim formulas will be
  tuned repeatedly; without recorded reasoning, tuning turns into thrash.*

**Changed**
- Save format: `GameState` gained two arrays, `Route` gained one.
  *Consequence: pre-existing dev saves fail to decode and the app starts a
  fresh game. Acceptable pre-TestFlight; save migration is deliberately
  deferred until the format stabilizes (M8).*

### 2026-07-16 — Milestone 1: fleet acquisition (used / lease / new orders)

**Added**
- `AcquisitionType` (`.ownedNew` / `.ownedUsed` / `.leased`) on `Aircraft`,
  plus `weeklyLeaseCost` and `deliveryWeeksRemaining`.
  *Why: GDD §3.1 — starting capital ($2.4M in India) is deliberately too
  small for an $18M new turboprop, so the used market and leasing ARE the
  first-hour experience and must ship in MVP.*
- Used market: 3–5 listings in `GameState.usedMarket`, age 3–15y, visible
  condition 40–90, price clamped to 30–60% of new (`Balance.usedPrice`).
  Rotates every 3–4 weeks **inside the tick, from the seeded RNG**.
  *Why seeded: determinism is an architectural guarantee — same seed must
  produce the same market, forever, or replay tests break.*
- Leasing: instant, 0.25%/week of new price, termination fee = 4 weeks
  (`Balance.leaseRatePerWeek/leaseTerminationWeeks`). Lease payments are
  their own `WeeklyReport.leaseCost` P&L line.
  *Why a separate line: the cash-flow-vs-equity tradeoff is the lesson;
  hiding lease drag inside another cost would bury it.*
- New planes are orders: `orderNewAircraft` pays cash up front, plane sits
  `.onOrder` for 8/16/24 weeks by archetype (tick step 0 counts down).
  On-order planes can't be assigned and don't age.
- `sellAircraft` at depreciated value; `Balance.resaleValue` is the same
  formula `netWorth` uses. *Why shared: if resale and book value diverge,
  buy-sell cycles become a money printer.*
- Showroom UI (New / Used / Lease segmented tabs); fleet rows show
  acquisition badges, delivery countdowns, Sell/Return actions.
- Tests: delivery countdown, seeded market refresh determinism, listing
  removal on purchase, lease fee math, resale value, day-one affordability.

**Changed**
- `netWorth` excludes leased aircraft. *Why: the lessor owns them —
  counting them would let players inflate the sandbox score for free.*
- Determinism test's scripted opening now leases (instant and identical
  across seeds) instead of buying.

### 2026-07-16 — Milestone 0: foundation

**Added**
- Split `SkyTycoonStarter.swift` into `Simulation/` (SeededRNG, Models,
  Balance, GameEngine — pure Swift + Observation, never SwiftUI) and `UI/`
  (five tab views, event card, root shell).
  *Why: the architecture's core promise — a deterministic, unit-testable
  sim with the UI as a dumb renderer — only holds if the import boundary
  is physical, not aspirational.*
- Test suite (`SkyTycoonTests/SimulationTests.swift`): the forever-green
  determinism test (2 engines × seed 42 × 100 weeks → identical state
  fingerprint), save round-trip stability, aging, assignment gates.
  *Note: the unit-test target must be added in Xcode (File → New → Target →
  Unit Testing Bundle, named `SkyTycoonTests`) — pending.*

**Fixed** (starter-code issues tracked in MVP_BACKLOG.md)
- Autosave: `advanceWeek()` never called `save()` despite the GDD promising
  autosave every tick. Now saves at the end of tick bookkeeping.
- Aircraft aging: `ageYears` was never incremented, so depreciation and
  `netWorth` were dead. Now +1/52 per tick for delivered airframes.
- Runway gate: `assign()` checked range but ignored `requiredRunwayClass`;
  now both endpoint cities must meet the aircraft's runway class.

**Removed**
- Boilerplate `ContentView.swift` (superseded by `RootView`).
  `SkyTycoonStarter.swift` kept at repo root as reference — it's outside
  the synced folder, so it doesn't compile into the target.
