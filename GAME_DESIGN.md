# SkyTycoon — Game Design Document
### A 2D airline management simulator for iOS
Version 0.3 — July 2026

---

## §0. The Feel — Vision Charter (2026-07-19)

What the game is FOR. Every system below serves this charter; when a
mechanic and the charter disagree, the charter wins.

### The fantasy
You are nobody with a plane. Your aunt staked you $200K, the industry
has sixty-eight carriers that have never heard of you, and the only
aircraft you can afford to operate is a leased eleven-seat turboprop.
Everything you will ever own, you will have earned: the first profitable
week, the first plane with your registration on it, the first jet, the
first time a rival you used to look up at appears BELOW you on the
ladder. SkyTycoon is the feeling of building a foundation stone by
stone, and knowing exactly which stone you laid this session.

### The emotional arc (one campaign, ~15 to 30 hours)
1. SURVIVAL (weeks 1 to 30). $200K, one lease, one route. Margins are
   thin by design; a bad fare or a wrong route loses money. The win
   condition of this era is simply a profitable week. It should feel
   like holding a small flame out of the wind.
2. FOUNDATION (months 6 to 18). Two or three feeders, the first used
   plane you OWN, the Regional License unlock card. The player learns
   the deep systems: crew economics, wear, catering, competition. Rank
   climbs through the forgettable charter carriers; each name passed
   is a small, private victory.
3. ASCENT (years 2 to 4). Jets unlock. Real rivals with real names.
   The trust-fund arc resolves; the aunt's letters change tone. Money
   works differently now: fleets, loans, hedging trends. The board
   fills with decisions that would have bankrupted era-1 you.
4. EMPIRE (year 4 on). Mainline, then widebodies, then the top ten.
   The game stops handing you goals and becomes a sandbox with teeth:
   crashes, courts, recalls, and the ladder's summit.

### Feel rules
- EARNED, NEVER GIVEN. No free planes, no windfalls that outclass the
  player's own work. Unlocks are thresholds crossed, announced with
  ceremony (the event drawer), never handed out on a timer.
- SLOW IS THE POINT. The sim ticks weekly; wealth accrues in
  thousands, not millions. If a player feels rich in month one, the
  tuning is wrong.
- THE WORLD TALKS BACK. Trends, events, lawsuits, recalls, rivals:
  every week should carry at least one thing worth reading, and every
  choice a consequence that lands somewhere visible (charts, ledger,
  reputation, the ladder).
- INSTRUMENTS, NOT MENUS. The UI is a machined console (Blueprint
  v3.1.2): split-flap boards, stamped tags, metal keys. Numbers move
  like instruments reading a live machine, because they are.
- ONE MORE WEEK. Every session should end with a reason to run one
  more settle: a delivery landing, a verdict pending, a threshold a
  few thousand dollars away.

### What SkyTycoon is not
Not an idle game (nothing meaningful happens without a decision), not
a city builder (no tile placement), not a punishing roguelike (failure
arcs are slow and legible, and the Grounded screen is dignified).

---

## 1. Vision Statement

SkyTycoon is a numbers-and-decisions airline tycoon game for iOS. The player inherits a modest fortune, picks one of five countries, and builds an airline from a single second-hand plane into a national (and eventually global) carrier. The game is played in short 5–10 minute sessions built around a weekly simulation tick. There is no twitch gameplay: every screen is a menu, a map, or a report, and every win comes from a good decision made earlier.

**Design pillars:**

1. **Money is the pressure, reputation is the reward.** The optimal strategy must never be joyless cost-cutting. Reputation multiplies demand, so treating staff and passengers well is the winning strategy, not just the nice one.
2. **Agency over RNG.** Random events exist, but they are almost always "choose a response" cards, never pure punishment.
3. **One economy, five flavors.** All countries run on the same simulation. Country choice changes coefficients, not rules. This keeps the codebase small and the balance tractable.
4. **Every number is explainable.** Any figure on a report screen can be tapped to see the formula behind it. Tycoon players love this, and it doubles as the tutorial.

---

## 2. Core Loop

```
  ┌─────────────────────────────────────────────────┐
  │                                                 │
  │   ACQUIRE PLANES → CONFIGURE SEATS → OPEN       │
  │   ROUTES → SET FARES & SCHEDULE → STAFF THEM    │
  │        │                                        │
  │        ▼                                        │
  │   [ WEEKLY TICK RUNS ]                          │
  │   flights fly → revenue & costs settle →        │
  │   events fire → meters drift                    │
  │        │                                        │
  │        ▼                                        │
  │   READ REPORTS → RESPOND TO EVENTS →            │
  │   REINVEST OR EXPAND ──────────────────────────►│
  │                                                 │
  └─────────────────────────────────────────────────┘
```

**Time model.** The simulation advances in discrete weekly ticks. The player controls speed: paused, 1x (one week per ~8 seconds), 2x, 4x. The sim always pauses automatically when an event card fires or a milestone is reached. Nothing ever happens while the player isn't looking that they couldn't have predicted.

**Session shape.** A session is typically: open app → sim resumes paused → review last week's report → respond to any pending event → make 1–3 decisions (adjust a fare, hire crew, order a check) → unpause and watch 2–5 weeks → close app. Autosave on every tick.

---

## 3. Starting Conditions

### 3.1 The Money

| Pool | Amount (base, India) | Strings attached |
|---|---|---|
| Aunt's trust fund | $2,000,000 | Must reach 4 consecutive profitable quarters within 3 in-game years, or remaining fund is withdrawn |
| Personal savings | $400,000 | None |

The trust fund condition is the tutorial campaign in disguise: it creates a deadline, a clear goal, and a soft-fail state that doesn't end the game (you keep playing on your own money, just harder).

Starting capital is deliberately too small to buy any aircraft new ($2.4M vs an $18M turboprop): the intended first move is a **used aircraft or a lease** (§4.1), optionally topped up with a loan. This makes the second-hand market and the maintenance game part of the first hour, and is why both ship in MVP.

Amounts scale by country cost-of-living so the effective difficulty stays comparable (see §5).

### 3.2 Loans and Credit

- Loans available from day one, from 3 banks with different rate/term/limit profiles.
- **Credit score (300–850)** driven by: debt-to-asset ratio (40%), payment history (40%), airline age and revenue trend (20%).
- Interest rate = base rate (country-specific) + credit spread. Miss a payment: score drops, rates climb. Miss three: banks freeze new lending. Sustained default: asset seizure (planes repossessed, chosen by the bank, worst-case).
- Asset seizure is the soft-fail before bankruptcy. **Bankruptcy** (cash < 0 for 8 consecutive weeks with no sellable assets) is the hard fail state.

---

## 4. Core Mechanics

### 4.1 Fleet Acquisition

Three acquisition paths, one showroom UI. All three ship in MVP (buying new is aspirational early — see §3.1).

**New aircraft (from manufacturers):**
- Delivery wait: 8–40 weeks depending on model and manufacturer backlog (MVP: fixed weeks per archetype).
- Financing plans offered (10–20% down, rest over 5–10 years at a rate tied to your credit score) (v1.0 — MVP uses ordinary loans).
- Warranty: first 2 years of maintenance events are free or discounted (v1.0).
- Best fuel burn, highest passenger comfort baseline.
- Relationship meter per manufacturer: bulk orders and on-time payments unlock discounts and priority delivery slots (post-MVP).

**Second-hand market:**
- Instant delivery, 30–60% of new price.
- **Condition rating (1–100)**. MVP: condition is shown openly on every listing. v1.0: condition becomes hidden — player can pay for a pre-purchase inspection (reveals exact rating) or gamble on the listed "seller's description" (vague, occasionally lying).
- Condition drives: maintenance cost multiplier, fault event probability, fuel burn penalty, resale value.
- Older airframes also carry a comfort penalty that seat config can only partially offset.
- MVP implementation: a small rotating set of seeded listings (3–5 at a time, refreshed every few weeks), price = f(archetype, age, condition).

**Leasing:**
- Any archetype available instantly for a weekly lease payment, no capital outlay (starting point: ~0.25% of new price per week, tunable).
- Leased aircraft can't be sold, and lease payments never end — the classic cash-flow-vs-equity tradeoff, and the safest first plane for a cautious player.
- Return a leased aircraft anytime with a small termination fee (MVP: 4 weeks of payments).

**Manufacturers (amended July 2026):** the catalog is sold by competing makers — Vayu Aeroworks (small turboprops), Northline Regional (propliners), Meridian Jets (mainline jets), and **Kestrel Aeronautics**, the cross-segment rival whose "II" airframes compete head-to-head in each size class (slightly newer tech: −4% burn, +6% price). Loyalty discounts (3%/order, cap 12%) are per maker, so committing to one lineup and splitting the fleet are both real strategies. Future majors slot in the same way.

**Aircraft archetypes (MVP ships with 4):**

| Archetype | Seats (max dense) | Range | Role | Real-world analogue |
|---|---|---|---|---|
| Regional turboprop | 78 | 1,500 km | Thin short routes | ATR 72 |
| Small narrowbody | 149 | 3,500 km | Domestic workhorse | A220 / 737-700 |
| Large narrowbody | 220 | 6,000 km | Trunk routes, short international | A321neo |
| Widebody | 350 | 13,000 km | Long haul (post-MVP unlock) | 787 |

Each archetype has: purchase price, weekly lease-equivalent cost, fuel burn per km, crew requirement (pilots + cabin crew per flight), maintenance base cost, turnaround time, and required runway class.

### 4.2 Seat Configuration

Per-aircraft cabin editor. The single most tactile screen in the game — treat it as a hero feature even in MVP.

- A horizontal cross-section of the fuselage; player drags a divider (MVP: single density slider from "sardine" to "spacious"; v1.0: three-zone editor for Economy / Premium / Business).
- Density slider trades **seat count** against **comfort score** (a direct input into customer satisfaction).
- Class economics (v1.0): Premium earns ~1.8x economy fare, Business ~3.5x, but each premium seat displaces 1.5 economy seats and each business seat displaces 2.5. Business demand only exists in meaningful volume on business-heavy city pairs (capital-to-financial-hub type routes).
- Reconfiguration costs money and grounds the plane for 1–2 weeks.
- **Cabin architecture (amended July 2026, supersedes the density slider):** the editor is a to-scale top-down floorplan. Player sets **seat pitch** (28–36″) and **seat width** (16–20″) — geometry derives rows and seats-abreast from the airframe; chooses **material** (fabric / leather / premium) and **ancillary units**: galley ovens (hot meals; each displaces a seat row) and cabin wifi. Every choice trades **install cost** (refit, grounds the plane), **weekly running cost** (per-seat upkeep by material, catering ops per oven, wifi service — its own P&L line), and **passenger comfort** (feeds §4.5 satisfaction).
- **Certified exit limit:** `maxSeats` is a hard cap — no layout may exceed it, ever.
- **Payload-range (amended July 2026):** a denser cabin is a heavier airplane. Effective range = brochure range × (1.15 − 0.30 × configuration fill), capped at +10%: a certified-limit sardine layout pays −15% range, an airy "ferry configuration" gains up to +10% — sometimes the only way to stretch a marginal route. Assignment legality uses effective range; refitting heavier than an assigned route allows pulls the aircraft off it (with a warning in the editor first).

### 4.3 Routes, Demand, and Pricing

**The demand model** is the heart of the sim. Every city pair (A, B) has a weekly base demand:

```
baseDemand = k × (popA × popB)^0.55 / distance^0.35
```

(a gravity model — big cities close together want lots of flights). Base demand splits into **leisure** (price-elastic, comfort-tolerant) and **business** (price-tolerant, punctuality-obsessed) using a per-city business index.

**Realized demand for YOUR flights on the route:**

```
yourDemand = baseDemand
           × seasonality(week)          // ±25% sinusoidal + holiday spikes
           × brandMultiplier            // 0.5 – 1.6, from reputation & marketing
           × priceResponse(yourFare / referenceFare)   // elasticity by segment
           × competitionShare           // your share vs AI carriers on the route
           × frequencyBonus             // more weekly flights = more share, diminishing
```

- `priceResponse` for leisure: steep curve, ~-1.4 elasticity. For business: shallow, ~-0.6.
- Load factor = min(1, yourDemand / seatsOffered). Empty seats earn nothing but still burn fuel — the classic tycoon tension.
- Fares are set per route per class. A "match market" auto-price button exists for players who don't want to micromanage, at a small yield penalty.

**Route constraints:** aircraft range ≥ route distance, runway class at both airports ≥ aircraft requirement, and (in China) a route license (see §5).

**Slots:** major airports have finite weekly slots. In MVP, slots are just a capacity number per airport. Post-MVP: slot auctions and secondary trading (a big UK-flavor mechanic).

### 4.4 Staff, Crews, and Happiness

Four staff pools: **Pilots, Cabin Crew, Ground/Maintenance, HQ (admin/ops)**.

- Each flight consumes crew-hours: pilots and cabin crew scale with aircraft size and route length; ground crew with departures; HQ with total airline size.
- **Understaffing** causes delays (punctuality hit) and overtime pay (1.5x). Chronic understaffing causes fatigue events.
- **Happiness (0–100)** per pool, driven by: pay vs market rate (±), workload vs roster capacity (±), recent events (strikes averted, bonuses, incidents), and training investment.
  - Below 40: attrition each week, sick-day rate doubles.
  - Below 25: strike risk event enters the weekly event pool. A strike grounds all flights for 1–2 weeks unless negotiated (event card with pay-rise / one-time-bonus / hardline options, each with consequences).
- **Skill (1–5 stars)** per pool, raised by training spend and tenure. Skill reduces delay probability, fault rates (maintenance), and raises service scores (cabin crew).
- MVP simplification: pools with aggregate headcount, one happiness meter per pool. v1.0: notable individuals (chief pilot, head of maintenance) as hireable characters with perks.
- **Hiring (amended July 2026):** headcount is built through recruitment, not a slider. Post a **job ad** per pool (small fee, runs ~4 weeks); **applicants** arrive weekly with individual skill and asking wage, and wait only a few weeks before taking other jobs. Hire at asking, or **negotiate**: lowball offers raise irritation — flexible candidates meet you in the middle, stubborn ones hold firm, and anyone pushed too far (or insulted) walks away. Hires blend into the pool's average wage and skill, so shrewd negotiation builds a cheaper, better team — and botched negotiation loses the candidate.

### 4.5 Customer Satisfaction and Brand

Two related but distinct stats:

- **Route satisfaction (0–100)** per route, a weighted rolling average of: punctuality (35%), comfort from seat config and aircraft age (25%), service from cabin crew skill/count (20%), price fairness — fare vs what was delivered (15%), incident history (5%, but incidents can crater it).
- **Airline reputation (1–5 stars)** = passenger-weighted average of route satisfaction, moving slowly (8-week smoothing). This feeds `brandMultiplier` in the demand formula. It's the compounding stat: high reputation → more demand → fuller planes → more money → better product → higher reputation.
- Reputation collapse (below 1.5 stars) is a soft-fail spiral that's recoverable but brutal — demand multiplier ~0.5 makes almost every route unprofitable until fixed.

### 4.6 Maintenance and the Ground Force

- Every aircraft accumulates **wear** per flight-hour (rate scaled by age and condition rating).
- Two check types in MVP:
  - **Line check** — cheap, 1 day out of service, resets a small amount of wear. Should be routine.
  - **Heavy check** — expensive, 1–2 weeks out of service, resets wear substantially and can restore condition points.
- **Deferred maintenance** raises per-flight probability of: minor fault (delay, satisfaction hit), grounding fault (plane out 3–10 days, unplanned), and — rarely, only at extreme neglect — a serious incident (massive reputation hit, investigation event, possible fleet grounding of that type). The game never depicts a crash; incidents are "emergency landing, all safe" framed, but the business consequences are severe.
- **Ground/maintenance staff** size and skill determine check duration, check cost, and surprise-fault rate. An understaffed maintenance force silently raises risk — surfaced via a "maintenance backlog" warning meter so it's never a gotcha.

### 4.7 Anomalies and Events

A weekly event roll from a weighted deck, most events being **choice cards** (2–3 response options, each with visible cost and described-but-not-quantified consequences).

Event categories and MVP examples:

| Category | Example | Options flavor |
|---|---|---|
| Market | Fuel price spike (+30% for 6 weeks) | Hedge now / eat it / cut frequencies |
| Weather | Cyclone closes coastal airport 1 week | Reroute / cancel & refund / partial ops |
| Labor | Cabin crew demand 8% raise | Grant / counter 4% + bonus / refuse |
| Technical | Engine fault found on one airframe | Fix now (ground 5 days) / defer (risk) |
| Opportunity | VIP charter offer, 3x revenue weekend | Accept (pull plane off route) / decline |
| Regulatory | Safety audit announced in 4 weeks | Invest in prep / wing it |
| PR | Viral video: crew helps stranded family | Amplify with marketing spend / modest reply |

Rules: never two negative events in consecutive weeks in the first year; event weights shift with player state (low maintenance → more technical events; low happiness → more labor events) so events feel like consequences, not dice.

### 4.8 Marketing, Branding, and Ancillaries

- **Marketing spend** per region builds **brand awareness (0–100)**, which raises the demand ceiling in that region (part of `brandMultiplier`). Awareness decays ~3%/week without spend. **MVP: one national weekly-spend slider** feeding awareness with decay — awareness contributes to `brandMultiplier` alongside reputation. Campaign types (v1.0): launch blitz (fast, expensive, fast decay), sustained (slow build, sticky), route-specific promos (short fare-elasticity boost).
- **Airline identity choice** emerges from ancillary settings rather than a menu pick:
  - **Ancillary toggles:** paid checked bags, paid meals, paid seat selection, wifi, lounges (airport-level investment).
  - Each toggle adds revenue-per-passenger but applies a satisfaction penalty **that shrinks as base product quality rises**. A 5-star airline can charge for wifi and nobody minds; a 2-star airline charging for water gets murdered in satisfaction.
  - This single interaction lets budget-carrier and premium-carrier strategies both be viable without a "pick your business model" screen.

### 4.9 Finance and Reports

- **Weekly P&L**: revenue (fares by class + ancillaries + charters) minus costs (fuel, crew wages, maintenance, airport fees, loan interest, marketing, HQ overhead, lease payments).
- **Quarterly report**: the beat that the trust-fund condition checks against. Presented as a letter from your aunt in year 1–3 (tone shifts with performance — great tutorial voice and flavor).
- **Balance sheet**: cash, fleet value (depreciating), debt. Net worth = the sandbox score.
- Every line item tappable → breakdown → formula. (Pillar 4.)

---

## 5. The Five Countries

One simulation, five coefficient sets. Starting capital is normalized by a cost index so difficulty is about *shape*, not size.

| | 🇮🇳 India | 🇺🇸 US | 🇬🇧 UK | 🇨🇳 China | 🇦🇺 Australia |
|---|---|---|---|---|---|
| **Fantasy** | Volume game | Efficiency game | Premium/hub game | Patience game | Optimization game |
| Demand growth /yr | +9% | +2% | +1.5% | +8% | +2% |
| Fare level | 0.6x | 1.3x | 1.2x | 0.8x | 1.4x |
| Price elasticity | Very high | Medium | Medium | High | Low |
| Labor cost | 0.4x | 1.5x | 1.3x | 0.5x | 1.4x |
| Fuel cost | 1.3x (taxes) | 1.0x | 1.1x | 0.9x | 1.05x |
| Slot scarcity | High (metros) | Medium | Very high | Priority to state carriers | Low |
| Competition AI | 2 aggressive LCCs | 3 strong majors | 2 majors + charter | 3 state carriers | 1 sleepy duopoly |
| Special rule | Metro slot lotteries | Union events 2x weight | Slot auctions; intl routes unlock at 1 yr instead of 2 | New routes need license: 4–12 week approval, small fee, approval odds rise with guanxi/reputation | Long thin routes: range matters, frequency bonus halved |
| Domestic cities (MVP) | 8 | 10 | 6 | 9 | 6 |
| Business index hubs | Mumbai, Delhi, Bangalore | NYC, Chicago, SF | London | Shanghai, Beijing, Shenzhen | Sydney, Melbourne |

Design intent: India rewards dense cheap capacity and punishes premium pretensions early; the US rewards operational excellence and punishes labor neglect; the UK pushes you international fast and makes slots the real currency; China gates expansion behind planning and rewards long-horizon players; Australia is the "learn aircraft economics" country where picking the right plane for the route is 70% of the game.

---

## 6. Objectives and Progression

**Layer 1 — Milestones (minutes):** contextual tasks with small cash rewards. "Open your third route." "Hit 80% load factor anywhere." "Complete your first heavy check." Doubles as the tutorial; never blocks anything.

**Layer 2 — The Trust Fund Arc (the first 3 years):** reach 4 consecutive profitable quarters before the deadline. Aunt's quarterly letters deliver praise, worry, and hints. Success: fund converts to a gift + reputation bonus + "Aunt's Approval" achievement. Failure: fund withdrawn, game continues in hard mode.

**Layer 3 — Sandbox goals (open-ended):**
- Net worth tiers: $10M / $50M / $250M / $1B.
- 5-star reputation sustained for a year.
- **Flag Carrier**: serve every major city in your home country.
- **Going Global** (post-MVP): routes touching all five countries.
- Fleet milestones: 10 / 25 / 50 aircraft.

**Fail states:** Bankruptcy (hard); Reputation collapse and Trust-fund loss (soft).

---

## 7. Screens (MVP UI Map)

Tab bar, five tabs:

1. **Dashboard** — cash, net worth, reputation stars, this week's headline numbers, pending event card, sim speed controls, milestone tracker.
2. **Fleet** — aircraft list (status: flying / maintenance / idle / on order), tap for detail: condition, wear, config, assign to route, order checks, sell. Buy button → showroom (New / Used tabs).
3. **Routes** — home-country map with city dots and route lines (thickness = frequency, color = profitability). Tap route: fares, frequency, assigned aircraft, load factor sparkline, satisfaction. "+" to open new route.
4. **People** — four staff pools with headcount, happiness, skill, wage sliders, hire/fire, training budget.
5. **Money** — weekly P&L, quarterly report archive, loans (active + bank offers), marketing budget, ancillary toggles.

Design language: clean data-forward cards, one accent color per tab, satisfying number-tick animations on the weekly settle. No isometric art needed for MVP — the map plus strong typography carries it (plays to a designer-founder's strengths).

---

## 8. Build Phases

**v0.1 — MVP (target: 3–4 months of evenings):**
India only, 8 cities, 3 aircraft archetypes (no widebody), second-hand market with visible condition, leasing, new-plane delivery waits, economy-only density slider, route creation + manual fares, aggregate staff pools with one happiness meter each, crew-hours with understaffing effects, wear-based maintenance with two check types, 12 event cards, loans from one bank, national marketing slider, weekly P&L, trust-fund arc, milestones, autosave. **Definition of done: a stranger can play 2 hours and want to keep going.**

**v1.0:**
All 5 countries and special rules, international routes, 3-class cabin editor, hidden condition + pre-purchase inspections on the used market, manufacturer financing plans and warranties, competitor AI on routes, marketing campaign types, ancillary toggles, credit score + 3 banks, notable staff characters, 40+ event cards.

**Post-launch:** alliances/codeshares, cargo, slot auctions, manufacturer relationships, scenario mode (2008 recession start, pandemic mode), Game Center leaderboards on sandbox goals, prestige/new-game-plus.

---

## 9. Technical Design Decisions (summary — see starter code)

- **Pure-Swift simulation core**, zero UI imports, fully deterministic given (state, seed). Testable in isolation; the sim must produce identical results on replay.
- **SwiftUI** for all UI; `@Observable` engine as the single source of truth; views are dumb renderers of engine state.
- **Value-type models** (structs) with identity via stable UUIDs; the engine (class) owns all mutation.
- **Seeded RNG** (`SeededRandomNumberGenerator`) — never `Int.random()` in the sim, so replays and tests are reproducible.
- **Fixed-timestep tick loop** driven by a timer that accumulates real time and fires whole weekly ticks; UI speed settings only change accumulation rate. *(Amended July 2026: a 30 Hz `Timer` ships instead of `CADisplayLink` — with 8-second weekly ticks, frame-perfect timing buys nothing but battery drain, and the sim's determinism never depended on the driver.)*
- **Codable snapshot saves**: the entire `GameState` serializes to one JSON blob; autosave every tick; versioned for future migration.
- **Balance data as data**: aircraft stats, country coefficients, and event cards live in plain Swift constant tables now, designed to move to bundled JSON later so balancing never requires touching sim code.

---

## 10. Amendment — The Immediacy Rule (2026-07-18)

Player changes take visible effect **immediately**; the sim's money
still settles on the deterministic weekly tick. Concretely:

- **Live projections:** every lever (fare, frequency, aircraft
  assignment) re-projects its route's load factor, demand, and margin
  the moment it moves — the boarding pass, route detail, and aircraft
  rows all read from the same `computeEconomics` the tick uses, so
  the projection and the eventual settle can never disagree. Settled
  history stays clearly labeled ("Last week").
- **Hiring:** posting a job ad produces its first applicant wave
  same-day (seeded RNG, determinism intact); the weekly trickle
  continues while the ad runs.
- **Deliberately slow (practical reasoning required to stay slow):**
  aircraft deliveries (factory lead time), maintenance checks and
  cabin refits (physical work grounds the plane), and reputation /
  brand-awareness drift — instant reputation would delete the
  death-spiral-and-recovery arc that gives service quality its
  long-term weight.

---

## 11. Amendment — Balance pass & difficulty (2026-07-18)

**Audit method:** two bot archetypes (single-plane "starter" with
maintenance/staffing/yield discipline; fleet-planning "expander") run
headless for 160 weeks across seeds. Findings pre-tune: the cost floor
of the standard opening (fuel + lease + maintenance + overhead) EQUALED
peak revenue — 30/30 runs went bankrupt; the best week of the best
strategy made +7K.

**Tune (all in Balance.swift):** referenceFarePerKm 0.11 → 0.125;
leaseRatePerWeek 0.0018 → 0.0014 (~7.3%/yr of hull); maintenance seat
slope 250 → 180; demandK 520 → 550. Post-tune: starter survives 15/15
and wins the fund 14/15 (~6.5M net at week 160); a fleet-planning
expander nets ~15.5M (fund 15/15); over-capacity expansion (big props
on thin markets) still fails — plane-to-market fit is the skill.

**Difficulty (player-chosen at founding):** three multiplicative
levers; standard = 1.0 everywhere, so the calibrated game IS standard.
- Relaxed: cash ×1.25, demand ×1.10, costs ×0.90 — fund 10/10 both bots.
- Standard: identity — fund 9-10/10 with competent play.
- Tycoon: cash ×0.75, demand ×0.93, costs ×1.10 — passive play survives
  but cannot win the fund (0/10); smart expansion wins it 5/10.
Stored optionally in the save; old saves read as standard.

---

## 12. Amendment — The industry ladder (2026-07-18)

Nine fictional incumbent carriers (Palm Air Charters $8M → Himalaya
Air $9B) form a static ladder the player climbs. Player market cap =
max(0, net worth) + 6 × trailing-year profit; rank is cap-ordered
among the ten. Market share = live-projected weekly pax vs the
industry total (~156K pax/wk at game scale). A new airline opens at
#10 with ~1% share; the trust-fund winner reaches ~#8; the top ranks
are long-game aspirations. Competitor AI (v1.0) will make the ladder
move back.

---

## 13. Amendment — US market + save slots (2026-07-18)

- **US is the default founding country** (India remains playable; UK/
  China/Australia stay "coming soon"). 14 US airports (JFK...AUS),
  metro populations, majors class-3. Distances come from the haversine
  fallback. CountryProfile gained `demandLevel` (propensity-to-fly
  multiplier; US = 1.5) because demandK was calibrated on India's 30M
  metros — first-pass US balance: a right-sized opener (30-prop on
  JFK-ORD) nets ~+150K/wk at LF 70% against the $7.2M richer start.
  A full US bot audit is future work.
- **Three save slots.** Autosave writes the active slot; a Saved
  Games sheet (Dashboard) loads, starts new games into, or deletes
  slots. Legacy single-file saves migrate to slot 1. GameSession (app
  layer) is the only object that swaps running engines.

## 14. Amendment — Industry trends (2026-07-19)

The market breathes on two horizons, shown in the Dashboard's Industry
card (renamed from "Industry standing"):

- **Long regime** (52–104 wk, exactly one always in force): Economic
  expansion / slowdown (demand ±), Oil supercycle (fuel +), Cheap
  credit era (aircraft prices −), Labor squeeze (wages +).
- **Short shocks** (3–12 wk, at most two, ~10%/wk spawn): Fuel spike,
  Travel rush, Business travel surge, Safety scare, Pilot shortage,
  Used-metal glut, Order-book boom.

Each trend multiplies ONE lever while it runs — route demand, fuel
price, the wage bill (market premium), or aircraft prices (new-order
quotes, lease signings lock the rate at signing, used listings bake it
in at generation). Trends stack multiplicatively with event effects on
the same levers, use the seeded RNG (deterministic per save), and the
state field is optional for save-compat: pre-feature saves seed their
first regime on the next settle.

*Why:* the economy was static between events — the same fares and costs
forever. Regimes give eras a personality ("the cheap-credit years were
when we built the fleet"), shocks create short tactical windows (buy
into a metal glut, shrink into a safety scare), and both explain
themselves on the dashboard instead of moving numbers silently.

## 15. Amendment — Contractor overflow (2026-07-19)

Staff overtime has a practical ceiling: a pool absorbs at most +20% of
its roster capacity at 1.5× pay (`overtimeCapFactor`). Demand beyond
that is flown by CONTRACTORS at market hourly × 1.8
(`contractorPremium`) — flights still operate, but the money bleeds.
`lastUtilization` now reports the EMPLOYEES' load (capped at 120%);
`lastContractorShare` reports how much of the schedule contractors
flew, and the People card says so explicitly. Happiness pressure
tracks the staff's own load; punctuality strain still tracks total
under-roster (contractors are unreliable). Understaffing is now an
economic problem instead of an impossible 979%-overtime week.

*Why:* one pilot "working 979% over roster" broke believability and
muddied the signal — the player needs "hire more people or pay the
premium," not a cartoon number.

## 16. Amendment — Event pacing: the pity timer (2026-07-19)

Decisions are the game. Cards no longer fire on a flat 16%/week coin
flip (expected drought: 6+ weeks): the weekly chance starts at 22% and
ramps +13% for every event-free week, capped at 85%
(`eventChancePerWeek` / `eventPityRampPerWeek` / `eventChanceCap`).
Expected cadence ≈ 2–3 weeks; the odds of going five weeks without a
decision are under 3%. Grace shortened to 3 weeks. The anchor
(`lastEventTotalWeek`) is save-compat optional. Year-1's
no-consecutive-negatives guard stands.

*Why:* flat probability makes droughts and floods equally likely — a
tycoon game needs a decision RHYTHM, so the player is always within a
week or two of the next meaningful choice.

## 17. Amendment — Airworthiness and hull loss (2026-07-19)

Wear past 90% (`wearDangerThreshold`) puts a FLYING airframe at risk of
hull loss: quadratic per-week probability from the threshold, 8% at
100% wear (`crashRiskAt100Wear`), seeded roll, at most one loss per
week. The warning is deliberately quiet — a red airworthiness line on
the Fleet card, no popup — the player either services the plane or
answers for it.

A crash: the airframe is destroyed; passengers AND named roster crew
(the flight's pilot/cabin complement) are lost; reputation drops 1.5
stars; every route's satisfaction falls 20; the courts award
$200K/life (`settlementPerLife`) immediately; and a "Safety scare"
demand trend (−20%, 8 wk) lands on the industry board. A full-screen
reckoning card narrates it — one option, no outs; the decision was
made in the weeks the warning was ignored.

Also: every event option now carries an effect (the film-shoot
"decline" was the one no-op — declining now protects satisfaction).

*Why:* wear had a cost curve but no stakes, so 100%-wear fleets were a
viable strategy; consequences make maintenance a decision instead of a
tax, and the quiet warning honors the player's agency — the game
warned, once, where an operator would look.

## 18. Amendment — Catering (2026-07-19)

Per-route in-flight service (`CateringLevel`), set from the route
detail's economics card, charged weekly per passenger on the cabin &
catering P&L line. Three trays (art in Resources/Food):
- SANDWICH BOX — $2/pax, the budget tray: +4 with ovens, −8 without.
- FRUIT PLATTER — $5/pax, delicate and pricier, the ONLY oven-agnostic
  tray: +6 always.
Hot trays (sandwich, bento) need a GALLEY OVEN ($40K one-time fit,
instant, Fleet → Service) on EVERY aircraft flying the route.
- ASIAN BENTO — $9/pax, the premium tray: +10 with ovens aboard,
  −12 without — a cold premium main breaks the biggest promise.
Satisfaction feeds reputation through the existing smoothing, so a
cold-sandwich route drags the brand. Save-compat optionals; the route
detail warns when hardware is missing; the short-lived snacks/hotMeals
tiers decode into platter/bento.

*Why:* service depth with a hardware dependency — a promise you can
make before you can keep it, which is exactly the tycoon trap.

## 19. Amendment — Lawsuit incidents (2026-07-19)

Two PR incident cards put a NAMED roster member at the center of a
liability claim: a cabin crew member spills scalding tea on a passenger
($180K claim), or a pilot's hard landing injures an elderly passenger's
spine ($300K). The card shows the accused's record — skill stars and
weeks of tenure — because the verdict weighs exactly that.

Two ways out:
- SETTLE QUIETLY: pay the full claim; it never makes the news
  (no reputation effect).
- FIGHT IN COURT (public): win chance = 20% + 12%/star +
  15%/tenure-year (capped 2y), max 90%. CLEARED → 15% of the claim in
  legal costs, +0.15 reputation (the papers run your side), verdict
  card narrates it. LIABLE → 1.5× the claim awarded, −0.8 reputation
  (public humiliation), verdict card narrates the bruise. Both
  outcomes land in the event log and on the finance charts.

*Why:* it makes hiring quality and retention legible in a new system —
a 5★ veteran is a defense you can take to trial, a green 2★ hire is a
settlement waiting to happen — and the settle-vs-fight call is a clean
risk decision with hidden information priced in.

## 20. Amendment — Manufacturer recall (2026-07-19)

A technical event card recalls a MODEL you actually operate — chosen at
present() as the delivered type you have most of (a recall should
sting). The maker covers parts; the decision is downtime versus risk:

- SEND THEM IN NOW: every delivered airframe of the type is grounded
  2 weeks for the retrofit ($10K logistics each). The shop visit also
  freshens wear (−15) — compliance has a silver lining.
- NEGOTIATE A DEFERRAL: fly on. $25K in fines per airframe, +12 wear
  each (the defect is real), and a −0.1 regulatory reputation scratch.
  With compounding fatigue and the hull-loss rules, deferring on a
  worn fleet is playing with fire — deliberately.

Both paths log to the event history/charts. The subject type rides on
the GameEvent (save-compat optional), mirroring the lawsuit cards'
subject member.

*Why:* recalls are aviation's most recognizable fleet crisis, and the
choice connects three systems — cash, route capacity (grounded planes),
and the wear/airworthiness danger curve.

## 21. Amendment — Route markets & competition (2026-07-19)

Every city pair has a MARKET, shown on the route detail (demand,
passenger affluence, rival count, your share) and hinted in the route
desk ("2 rivals"):

- COMPETITORS (0–4, deterministic per pair): big, business-heavy pairs
  attract more rivals; thin regional pairs are often monopolies.
- AFFLUENCE (endpoint business share): affluent pairs weigh comfort
  over price; budget pairs the reverse.
- CAPTURE SHARE: your appeal (comfort × affluence weighting +
  price-for-market + route satisfaction) against rivals at 0.5 appeal:
  share = appeal / (appeal + rivals × 0.4). A monopoly always captures
  100% — an uncomfortable plane still fills if you're the only option.
- Competition also GROWS the pie (+45%/rival), so a strong product on a
  contested pair nets near-monopoly pax while a weak one collapses to
  its sliver — passengers flock to the competition.

Also: condition now decays with age (~3/yr, floor 20) — old airframes
burn more, cost more, wear faster, and resale falls, so fleets need
renewal, not just checks. The Fleet list sorts worst-wear first.

*Why:* load factor previously ignored WHO ELSE flies the pair; comfort
was a satisfaction nicety instead of a competitive weapon. Markets make
cabin quality, pricing, and route selection one connected decision.

## 22. Amendment — The Foundation Era (2026-07-19)

The progression overhaul that makes the charter's arc real.

### Starting conditions
- The aunt's seed is a flat **$200K** (`auntSeedFund`), scaled only by
  difficulty (relaxed 1.5×, tycoon 0.7×). Country trust-fund figures
  are retired. The deadline-failure withdrawal claws back up to the
  seed, not a fortune.
- $200K buys NO airplane. The opening move is a leased Orion feeder
  (~$2.6K/wk) and one carefully chosen route. Owning your first
  airframe is an era-2 achievement.
- HQ overhead now scales with the operation: $2.5K/wk base +
  $1.4K/wk per aircraft (was a flat $15K that would have ended a $200K
  start by itself in 13 weeks).
- Reference fare squeezed 0.125 → 0.120 $/km. Together with rival
  capture share (§21), contractor premiums (§15), and compounding wear
  (§17), margins stay thin until the player earns scale.

### Fleet tiers (earn the flight line)
Models group into five tiers; a new airline starts at tier 0 and
unlocks upward at MARKET CAP thresholds (cap blends net worth and
trailing profit, so it measures the whole foundation, §12):

| Tier | Name                | Unlocks at | Contents |
|------|---------------------|-----------:|----------|
| 0    | Feeder Operations   | day one    | Orion 205/208/210/212 |
| 1    | Regional License    | $1.5M      | Northline NR-70…NR-120, Kestrel KD-72/88/98 |
| 2    | Jet Certificate     | $8M        | Meridian M50/M70/M105, Kestrel KJ-80/90 |
| 3    | Mainline Authority  | $40M       | Meridian M155/M200/M260, Kestrel KJ-265 |
| 4    | Flag Carrier Rights | $200M      | Meridian M230/M300/M375 |

- Crossing a threshold fires an **unlock event card** at the next
  settle: the tier's name as the title, the freed models listed, one
  key ("To the showroom"). The drawer opening on new metal is a
  celebration beat, logged to the event history and charts.
- The showroom shows locked metal behind a lock plate naming the
  requirement ("Unlocks at $8.00M market cap"): aspiration, visible.
  Engine guards (order/lease/used) enforce the lock; the UI only
  communicates it.
- Pre-§22 saves are grandfathered at tier 4.

### The deep ladder (start near the bottom)
- Each market's rival table now runs from its flag carrier down to
  $120K charter outfits: 9 authored anchors + log-spaced generated
  carriers with market-flavored names (Konkan Skyways, Bluebird
  Express…). US fields 68 rivals; India 54. A fresh $200K airline
  enters around **#60–69** and every rank gained is bought with real
  growth.
- Weekly pax of generated carriers tracks cap sublinearly, so market
  share stays honest with a long tail.
- The Industry sheet shows the top of the table, an ellipsis for the
  crowd, and YOUR seven-carrier neighborhood: the fight you are in,
  not sixty-nine unreadable bars. The share pie buckets the tail into
  "Everyone else".

### Why
The old start (millions in the bank, rank #10 of 10, every plane
purchasable on day one) skipped the entire first act. The foundation
era gives the numbers somewhere to go, makes each unlock a story
beat the player remembers, and turns rank into a long, legible climb
instead of a leaderboard you enter at the top of.

---

## 23. Amendment — The Daily Loop (2026-07-20)

The feedback loop moves from **weekly** to **daily**. A lever pulled today
shows its consequence tomorrow, not a week later. The economy is unchanged
in totals — seven daily settles equal one old weekly settle — so the whole
§22 calibration (fares, wages, wear, the trust-fund arc) holds. Only the
*cadence of feedback* changes.

### The split: continuous daily, discrete weekly
Two kinds of systems, two cadences:

- **Continuous — settled every day (1/7 of the weekly rate):** route
  revenue and fuel, wages, contractors, maintenance, lease, cabin, marketing,
  overhead, loan interest → cash moves daily. Wear accrual, condition decay,
  route satisfaction drift, and reputation drift also step daily. The net
  worth board, the cash number, and every meter refresh each day. The trend
  charts record a point PER DAY too: the history buffers append daily and
  the charts bucket them into weeks/months/quarters for display, so the
  window stays a stable span while the newest bucket (the tip) advances
  every day. The P&L chart shows daily profit bars over the last ~13 weeks;
  the load-factor sparkline is daily; only the formal weekly P&L *statement*
  (the tap-for-formula rows and quarter letters) stays a weekly close.
- **Discrete — resolved on the 7-day boundary (unchanged balance & RNG):**
  the event deck draw, industry-trend aging, staff attrition and recruitment,
  delivery and maintenance countdowns (still counted in weeks), aircraft
  aging, fleet-tier unlocks, the used-market refresh, and the quarter close
  (every 13 weeks). These stay weekly because their pacing is a design
  choice and their randomness must stay deterministic — the seeded RNG is
  drawn once per week, exactly as before, so replays are identical.

This keeps the calibrated economy intact while giving the player same-day
control over the levers that matter moment to moment.

### Time model
- `GameDate` gains `day: 1...7` alongside `week: 1...52` and `year`. Old
  saves decode with `day = 1` (save-compat). `advance()` rolls day → week →
  year; `totalDays` is the absolute clock.
- The clock ticks one **day** per `secondsPerWeek / 7` (~2.3s at 1x). The
  sim-pill's seven-segment strip now fills one segment per settled day, and
  a full week still takes the same real time as before.
- `stepOneWeek()` becomes `stepOneDay()` — the deliberate-play unit is a day.

### The report
- The formal P&L **statement stays weekly**: daily figures accumulate into
  the running week's `WeeklyReport`, which is finalized and appended on the
  7-day boundary (the "Last week" card, the 52-week P&L chart, the expense
  pie, and quarter math are unchanged). The *numbers* the player watches
  move daily; the *statement* is still a clean weekly close.

### Determinism & save-compat
- RNG draws remain on the weekly boundary only, in the same fixed order, so
  a seed replays identically.
- `day` is optional-with-default in the save; pre-daily saves load and simply
  begin their next week from day 1.

### Why
A week-long delay between a decision and its consequence made the game feel
like steering a ship by mail. Daily feedback makes it controllable — you
see a fare change, a hire, or a route tweak land the next day — without
speeding the economy up or cheapening the slow-build fantasy: the money per
day is small, the climb is just as long, but now it is legible day by day.

---

## 24. Postmortem — The frozen clock (2026-07-20)

### Symptom
Mid-session, the sim clock stopped advancing and the speed control went
dead — tapping any speed did nothing. Force-quitting and reopening cleared
it (the hold state is transient, rebuilt at launch).

### Root cause
The clock is suppressed while decision UI is open, via an interaction
**hold**. That hold was a plain integer counter: `+1` in
`ClockHoldModifier.onAppear`, `−1` in `onDisappear`. SwiftUI does **not**
guarantee those fire in balanced pairs — a sheet re-presenting, a parent
re-render, a tab switch, or the DEBUG hot-reload can fire `onAppear` again
without a matching `onDisappear`. One leaked `+1` left the counter ≥ 1
forever, so the tick's `interactionHolds == 0` guard never passed again:
the clock froze and every speed tap was ignored.

### Fix (three layers, defense in depth)
1. **Token set, not a counter.** Holds are now a `Set<UUID>`; each holder
   owns a stable token. A repeated `begin` is idempotent, so the dominant
   leak (double `onAppear`) cannot accumulate, and a single `end` fully
   releases regardless of how many times begin fired.
2. **`.task` lifetime, not `onDisappear`.** The hold is taken inside a
   `.task` whose cancellation on view removal is reliable where
   `onDisappear` is not; `onDisappear` remains as an idempotent backup.
3. **Self-healing safety net.** Choosing a running speed calls
   `releaseStuckHolds()` — the player asking for time to move is proof any
   lingering hold is stale. Legitimate open sheets re-register instantly
   through their `.task`.

### Guard against recurrence
- No `beginInteraction`/`endInteraction` may be called without a stable
  token; there is no no-arg overload to leak through.
- Verified in-engine: double-begin + single-end releases the hold (a
  counter would stay stuck), and a leaked hold clears on the next speed tap
  with the clock resuming.
- General rule: never gate the core loop on a counter mutated from
  `onAppear`/`onDisappear`. Model "held while X is on screen" as membership
  (a token that exists iff the holder exists), not arithmetic.

---

## §25 — Ambient events & scaled incidents (2026-07-20)

The event system spoke in one register: every card slammed the game to a
halt and took the whole screen. Frequent, low-stakes cards (a fuel wobble,
a viral crew clip) broke the flow as loudly as a hull loss, and the deck
started to feel repetitive because each draw carried the same interruption
weight. Two fixes, plus a balance correction.

### Severity: major vs ambient
Every card now declares a `severity`:

- **Major** — a real decision that deserves the pause. It stops the clock
  (`blockingEvent`) and presents full-screen, exactly as before. The heavy
  cards: lawsuits (tea spill, hard landing), the manufacturer recall, the
  strike vote, and every system reckoning (hull loss, court verdict, tier
  unlock, the aunt's quarterly letter).
- **Ambient** — everything else. It rides quietly on the Dashboard as a
  "Decision" card while **time keeps running**, so the feel of the game is
  never broken by the small stuff.

`GameEvent.severity` defaults to `.major` for save-compat (a card persisted
by an older build still interrupts). `EventCard.severity` defaults to
`.ambient` — only the heavy cards opt in to interrupting.

### Default unfolding (no silent stockpile)
An ambient card left unattended for `ambientEventGraceDays` (7) unfolds on
its own, taking its **passive** option — by construction the last-listed
one (ride it out / defer / decline / refuse / wing it). `advanceDay` checks
the deadline (`autoResolveDay`, in `totalDays`) at the top of the tick and
resolves it through the same `resolveEvent` path a tap would. The Dashboard
card shows the countdown ("Left undecided, we 'Ride it out' in 4 days.").

### Scaled incident claims
A fixed fine that ended a founder was a rounding error to a flag carrier.
Lawsuit claims are now `scaledIncidentFee(base:fraction:marketCap:)` — the
greater of a base floor and a slice of market cap (tea spill 2%, hard
landing 3.5%), capped at 12× base so no single suit is instantly ruinous,
rounded to a clean $10K. The scaled fee is computed at fire time, baked
into the card's options and body, and **persisted** on the `GameEvent`
(`incidentFee`) so a reloaded pending card rebuilds identical copy. Early
game is unchanged (the floor dominates); late game, a suit finally stings.

### §25 addendum — the deck expansion (2026-07-20)

The deck grew from 12 MVP cards to 42 drawable (45 counting system cards),
spanning every category. Six new `EventEffect` cases carry the mechanics
that the old deck couldn't express:

- `recurringCashFlow(weekly:weeks:label:)` — a signed weekly amount for a
  spell, accrued 1/7 per day (income books as revenue, cost as overhead)
  and aged with the other timed effects. Powers cargo/charter income and
  landing-fee / carbon-levy / rate-hike costs.
- `skillBoost(role:delta:)` — a training course lifts a pool's skill.
- `poachStaff(role:)` — a rival hires away the card's named subject (or a
  seeded-random member); headcount drops by one.
- `groundFleetShare(fraction:weeks:)` — an ash cloud / regional shutdown
  grounds a share of the airborne fleet.
- `adjustFleetWear(_:)` — fleet-wide wear delta (negative = an avionics
  refresh; positive = strain).
- `aircraftMarketShock(multiplier:weeks:)` — a rival's collapse injects a
  metal-glut trend that discounts aircraft prices while it runs.

Tuning: the ambient decision window is `ambientEventGraceDays = 8` (was 7).
The sim clock lost its x4 setting — it outran readability of the daily
loop; speeds are pause / x1 / x2.

### §25 addendum 2 — cash figures scale with the airline (2026-07-20)

A fixed −$50K hedge is a real decision for a founder and a rounding error
at $13M net worth. So every event's cash figure is now AUTHORED at founder
scale and scaled up at fire time: `eventCashScale(netWorth:) = clamp(
netWorth / 1_500_000, 1, 40)`. In `present()`, non-lawsuit options run
through `scaledOptions(_:)`, which multiplies each `.cash` and
`.recurringCashFlow` amount by the scale (rounded to $10K / $1K) and
re-renders the "Action · −$X" label suffix to match. Percentage/timed
effects (demand, fuel) are scale-free and untouched. Lawsuits keep their
own market-cap scaling (litigation targets the public valuation, not the
balance sheet), so they are excluded from this path to avoid double-scaling.

---

## §26 — Engagement: the edge must decay (2026-07-20)

The problem: a profitable route was free money forever. Competition was a
frozen hash per city-pair, demand only ever grew, and service quality was a
stable attractor — so "open a good route and walk away" strictly dominated
active play. This section is the roadmap to fix it. The thesis:

> Every edge must decay unless maintained; growth must cost reinvestment
> and force rebalancing; and there must always be a visible, expensive
> next goal.

### The five pillars (priority order)
1. **Living competition** — dynamic rivals that enter fat, dominant routes
   and erode share/yield until you defend (re-price, add seats, lift
   service). *The core fix.* **SHIPPED (P1).**
2. **Route maturity & capacity discipline** — an S-curve ramp on new routes
   and an over-supply yield penalty, so right-sizing is ongoing. **SHIPPED (P2).**
3. **Slot scarcity with periodic review** — reclaim under-used slots at busy
   airports; expansion means choosing. Promotes the `slotAudit` event to a
   real reclaim. **SHIPPED (P3).**
4. **Fleet as rolling reinvestment** — sharper aging (lease renewals TBD)
   make the fleet a treadmill, not a one-time buy. **SHIPPED (P4).**
5. **Ambition ladder** — named goals beyond the aunt's arc (climb the rival
   ladder, tiers, city count, market cap) that pull reinvestment. **SHIPPED (P5).**

### P1 shipped — Living competition
- `Route.rivalPressure: Double?` — the DYNAMIC rival count, seeded from the
  structural `competitorCount` floor (nil on old saves).
- `computeEconomics` reads `rivalPressure` (continuous) into the existing
  `captureShare` / `marketPie` math instead of the static count.
- `closeWeek` drifts each flown route's pressure toward a target from
  `Balance.rivalTargetPressure(floor:loadFactor:yieldRatio:)`: busy +
  high-yield routes pull the full field (cap `rivalMaxPerRoute = 5`), cheap
  or marginal ones fall back to the floor. Drift `rivalDriftRate = 0.25`/wk;
  rivals only ENTER past `rivalEntryGraceWeeks = 20` (they leave any time).
  No RNG — determinism holds.
- Player defends by cutting fare (sheds rivals, lowers yield), adding
  capacity/frequency, or lifting comfort/catering/marketing (raises
  `appeal`, holding share without a price cut).
- **Attention signal:** `GameEngine.routesNeedingAttention` flags flown
  routes that are losing money, slipping off their recent load peak, newly
  contested (pressure > floor + 1), or half-empty; the Dashboard surfaces
  them as tappable rows that open the route.
- Verified in-engine: a fare at 1.25× reference pulls rivals to ~4.6;
  undercutting to 0.90× sheds them back toward the floor.

### P2 shipped — Route maturity & over-supply
- `Route.openedOn: GameDate?` — stamped at `openRoute`; nil on old saves →
  treated as fully mature so nothing already flying is disturbed.
- `Balance.routeMaturity(weeksOpen:)` — smoothstep from
  `routeStartMaturity = 0.35` to 1.0 over `routeRampWeeks = 10`; multiplies
  `demand` in `computeEconomics`. A fresh route builds its market over ~2½
  months. Verified: 0.35 → 0.68 (wk5) → 1.0 (wk10).
- `Balance.oversupplyYieldMultiplier(seatsOffered:demand:)` — 1.0 until
  seats exceed the capturable pax by `oversupplySlackThreshold = 1.25`,
  then fading linearly to `oversupplyYieldFloor = 0.80` at
  `oversupplyRatioAtFloor = 2.5`. Multiplies `revenue` (distinct from the
  empty-seat fuel cost). Denominator is `marketPie × captureShare` — your
  actually-fillable pax, so it reflects competition too.
- UI: the route's Market section shows a "market still building, NN%" note
  while young and an "over-supplied, fares dilute NN%" warning when
  overweight; `routesNeedingAttention` skips routes still inside the ramp so
  a building route isn't falsely flagged.

### P3 shipped — Slot scarcity (use it or lose it)
- Every `slotReviewIntervalWeeks = 26`, `closeWeek` calls
  `underusedRouteForReview()`: the worst route (lowest load) that is flown,
  past its ramp, under `slotReviewLoadThreshold = 0.55` load, holding
  `≥ slotReviewFrequencyCut` weekly slots, at an airport with
  `≤ slotReviewCongestionFree = 6` free slots. If found (and no card is
  pending), `presentSlotReview(route:)` fires a targeted AMBIENT card naming
  that route.
- Options: "Defend the slots" (a net-worth-scaled cash cost from
  `slotReviewDefendCost = 25_000`) or "Give them up"
  (`reclaimRouteSlots(frequencyCut:)` cuts the subject route's weekly
  frequency, freeing the slots). Default (ignored → auto-unfold) is "give
  them up." Threaded via a new `GameEvent.subjectRouteID` +
  `eventSubjectRouteID`, mirroring the staff/aircraft subject plumbing.
- The card is built directly (not from the deck), so `refreshPendingEventCopy`
  leaves it intact on reload (cardID "slotReview" isn't in the deck). The
  old generic `slotAudit` deck card was removed.
- Only fires when you're actually hoarding — airports with free slots are
  never touched. Verified: a 30%-full route saturating an airport is picked;
  "give them up" cuts frequency by 4.

### P4 shipped — Fleet as rolling reinvestment
- `Balance.aircraftPrimeYears = 18`: past prime, `ageMaintenanceMultiplier`
  adds +6%/yr (×1.72 at 30 yr) to maintenance, and
  `ageConditionDecayMultiplier` adds +4%/yr to condition decay, which may
  now fall to `agedConditionFloor = 12` (below the usual 20). Applied in
  `advanceDay`. Old planes bleed money → must be replaced.
- `GameEngine.agingAircraft` (age ≥ `aircraftRetireFlagYears = 22`) surfaces
  on the Dashboard Ops Conditions card as "plan replacement" rows that tap
  to the Fleet. Grandfathered implicitly (the curve just applies forward).
- Lease-term renewals are noted as a future refinement; not in P4.

### P5 shipped — Ambition ladder
- `Balance.ambitions` — 14 ordered rungs (`AmbitionDef` with a `.kind`:
  fleetSize / cities / marketCap / reputation / beatRank). Evaluated by the
  engine (`ambitionComplete`, `ambitionProgress`, `currentAmbition`) since
  several read market cap / industry rank.
- `checkAmbitions()` in `closeWeek` pays newly-reached rungs once
  (`state.completedAmbitions`); on first encounter (nil) it grandfathers
  already-met rungs UNPAID so loading the build into a grown airline gives
  no windfall. Verified: preview airline grandfathers rank50/rank25 unpaid;
  with an empty done-set they pay their $700K.
- Dashboard `ambitionCard` shows the current rung + a progress rail +
  reward; RootView shows a `CelebrationBanner` when a rung completes,
  mirroring milestones.

### Validation standard for future pillars
Add a passive bot (opens good routes, never touches them) vs an active bot
(defends share, re-prices, right-sizes). After ~3 in-game years the active
bot's net worth must clearly beat the passive bot's, and passive routes must
visibly erode. If passive still wins, the pressure is too weak — tune and
re-run.

---

## §27 — Rival collapse: acquire the wreckage (2026-07-20)

The "A Rival Has Collapsed" card (previously just a used-metal price shock)
is now a full acquisition scenario — a major, paused decision. The body
names a real rival ranked BELOW the player at fire time (`rivalCollapseBody`),
so it reads as a smaller carrier folding.

Options:
- **Buy jets & crews · −$X** (net-worth-scaled): `acquireUsedFleet(count: 3)`
  drops three used, lower-tier (≤ tier 2, unlocked) airframes straight into
  the fleet at fire-sale condition (55–80) and age (6–14 yr), auto-named via
  `nextTailCode()`; `acquireStaff(pilots: 4, cabinCrew: 4, ground: 3)` adds
  ready-made crews (skill 2.5–4.0) at ~0.9× market wage — talent that now
  carries an ongoing wage bill.
- **Hire their crews only**: `acquireStaff(3/3/2)`, no jets, no upfront cash
  — cheap talent, but you shoulder the wages.
- **Let the market have it**: `aircraftMarketShock(0.85, 8)` — the old
  behaviour (a used-metal glut discounts purchases for a while).

Two new effects (`acquireUsedFleet`, `acquireStaff`) build valid Aircraft /
StaffMember instances through the same helpers as buying and hiring. The
fixed asset counts against a net-worth-scaled price make this a transformative
early-game swoop and a merely-fine late-game one — self-limiting.

---

## §28 — Cost inflation, 5%/year (2026-07-21)

Every cost the airline books now climbs 5% a year: a mandatory wage
escalator generalized into an economy-wide inflation index. Revenue is
NOT inflated — the reference fare holds — so a set-and-forget fare quietly
loses ground, and keeping fares (and efficiency) moving becomes part of the
long game. Reinforces the anti-idle thesis of §26.

- `Balance.inflationFactor(yearsElapsed:) = pow(1.05, years)`, driven by
  `GameEngine.inflationFactor` from the sim date (1.0 at start; ×1.28 by
  year 6, ×1.63 by year 11).
- Multiplied into every cost line in `advanceDay`: base + overtime wages,
  contractors, maintenance, lease, cabin upkeep/catering, HQ overhead, and
  fuel (in `computeEconomics`, so the UI projections match).
- NOT inflated: marketing spend (it's the player's chosen dollar figure)
  and loan payments (fixed contractual interest). Revenue/fares are left to
  the player to raise.
- Verified: a fixed fleet's weekly costs rise ×1.28 from year 1 to year 6,
  tracking the index exactly.

---

## §29 — Payoff pack: overtakes, records, named planes (2026-07-21)

Fun-not-complex additions that reuse existing data for emotional payoff —
no new economy to manage.

### Rival overtakes
The charter's core feeling ("a rival you used to look up at, now below you")
is now celebrated. `checkRivalOvertakes()` in `closeWeek` tracks
`state.passedRivals` (grandfathered unannounced on first run); when market
cap passes a named carrier, it logs a headline and sets
`state.lastOvertakenRival`, which RootView shows as a CelebrationBanner
("You overtook Satpura Express").

### Records board
`state.records` (a `Records` struct) max-es in the airline's personal bests
each week — best week profit, best single-route week, largest fleet,
highest rating, peak market cap, most weekly pax — shown as a Records card
in the Profile sheet.

### Name your aircraft
`Aircraft.customName` + `displayName` (name ?? tail). Renamed from the Fleet
card (a pencil opens a text alert; blank reverts to the tail code, which
stays visible as a subtitle). The hull-loss card now uses `displayName`, so
losing "Spirit of Delhi" hits harder than losing "AA-A".

---

## §30 — Rival trash talk + the shareable airline card (2026-07-21)

### Rival trash talk
The ladder gets a voice, in the Gazette. `GameEngine.currentRivalPress`
returns a `RivalQuote`: for six weeks after you overtake a named carrier it
shows that carrier's salty reaction (set in `checkRivalOvertakes`), then
fades to a standing jab from `nextRival` (the carrier directly above you).
Quotes/bylines are picked by a STABLE hash (no RNG-stream impact) from
`Balance.overtakenQuotes` / `rivalJabs` with a deterministic CEO byline
(`spokesperson(for:)`). Rendered as a "RIVAL WATCH" page in the swipeable
Gazette (`GazetteItem.rival`), sharing the newsprint/Didot/foil look.

### The airline card (share)
`AirlineCardView` (in ShareCard.swift) — the one artifact meant to leave the
app, built entirely from the Blueprint system: Gazette foil + Didot
masthead and name, a polished-silver monogram crest ringed in the player's
livery tail color, a three-band livery cheatline echoing their paint,
instrument-well stat tiles (fleet / routes / rating / net worth / market
cap), a Caveat handwritten signature, and tail-color registration ticks.
Driven by a precomputed `AirlineCardData` value so the live preview and the
exported image are identical. Shared from the Profile via `ShareCardSheet`
→ `ImageRenderer` (scale 3) → the system share sheet (`ActivityView`) with
a caption. No new assets; pure design-system composition.

---

## §31 — Postmortem: the dead Service button (2026-07-21)

### Symptom
The Fleet card's **Service** action did nothing on device. Route and Cabin
(the other two chips in the same row) worked fine.

### Root cause
The action row is a horizontal `ScrollView` with a cosmetic
`.fadeEdge(.trailing)`. `fadeEdge` was implemented with SwiftUI's
`.mask { LinearGradient(... .clear) }`. **A `.mask` clips HIT-TESTING as
well as rendering** — any view sitting under the transparent part of the
mask silently stops receiving touches. **Service is the trailing-most chip**,
so it lived exactly in the faded strip and its tap target was masked out.
Route (leading) and Cabin (middle) were never under the fade, so they
worked — which is why the bug looked Service-specific. The engine's
`orderCheck` was correct the whole time (verified in isolation: cash −$30K,
wear 67→42, grounds, recovers). Same defect silently hit the new-route
origin airport picker (its trailing airports).

### Fix
`fadeEdge` no longer masks. It now draws the fade as a NON-INTERACTIVE
`.overlay` gradient toward the surface color with `.allowsHitTesting(false)`
— identical look, but it can never gate a touch. Fixes every current and
future use at once.

### Lesson
**Never use `.mask` (or `.clipShape` beyond intended bounds) on a view that
contains interactive controls** — masks clip hit-testing. A purely visual
effect must be applied as a non-hit-testing overlay, not a mask. When a
control "does nothing," suspect the view tree (an ancestor eating the tap)
before the handler; here the handler was provably fine.

---

## §32 — Rival collapse as a whole-operation acquisition (2026-07-21)

The "A Rival Has Collapsed" card (GDD §27) grew from loose assets into
inheriting an entire airline. When it fires, `rivalCollapseContext()`
generates a concrete `RivalCollapseOffer` (seeded, deterministic) for a
carrier ranked below you:
- **Fleet** — 2–3 tier-≤2 airframes you can actually operate, worn but
  flyable (condition 45–78, capped by the age ceiling).
- **Routes** — up to 2 city pairs you don't already fly, within the fleet's
  range/runway, priced near the market reference.
- **Crew** — pilots/cabin/ground sized to run it, at a single skill level.
- **Reputation** — derived: `1 + 4·(0.55·skill/5 + 0.45·avgCondition/100)`.
  It IS the quality of their crew and metal, shown as stars on the card.
- **Price** — a fire sale: 0.6 × the fleet's resale value.

The card (EventCardView) shows this as a dossier: reputation stars, fleet
rows (photo + model + condition), route rows, and the crew line.

Acquiring (`applyCollapseOffer`) inherits the whole operation, not just
assets: the routes reopen under your flag **already mature** (openedOn nil)
with satisfaction seeded to their reputation, the planes arrive with your
tail codes, the crew joins, and **the planes are assigned onto the inherited
routes** — you buy a flying airline, not a pile of parts. "Hire their crews
only" takes just the people. The offer is persisted on the `GameEvent` and
rebuilt by `refreshPendingEventCopy` on reload.

---

## §33 — The Head Quarter: news portal + ops board, unified (2026-07-21)

The Dashboard's "Ops conditions" card is now **Head Quarter** — the airline's
newsroom and ops board in one. It holds the Gazette (moved out of the
Industry card) on top, then the timed modifiers in force and the aircraft
that need a look. So the news AND the effects of the news live together,
which is what the player expected.

- **Gazette relocated** from `industryCard` to `headquartersCard`. Industry
  now shows only the standing/ladder.
- **Gazette pages** (`gazetteItems`): breaking news → rival watch → market
  trends. Effects of the news are visible here: trend stories carry their
  `±%·weeks`, and event-driven timed modifiers (fuel/demand spikes) list
  below as active-effect chips.
- **Acquisition news** (`postCollapseNews`): resolving a rival collapse
  files a headline to the news portal, whoever wins the carrier — you
  ("AUNT AIR ACQUIRES SATPURA EXPRESS"), crews-only, or a bigger rival when
  you pass ("RANN CONNECT ABSORBS SATPURA EXPRESS", acquirer = next rung up
  by market cap via `collapseAcquirer`). Stored on `state.pressHeadline`,
  shown as a BREAKING page for six weeks (`currentPressHeadline`).

---

## §35 — Postmortem: the dead "Post job ad" button (2026-07-21)

### Symptom
"Post job ad" did nothing on tap — reported twice, persisting across
rebuilds (so not the install).

### Root cause
The button is `.disabled(engine.state.cash < Balance.jobAdFee)` ($2K). When
visible, no ad is running, so the ONLY thing that can disable it is low
cash — and after the fuel/lease/inflation cost hikes, the airline's cash
had dipped under $2K. The real defect: **`GameButtonStyle` never read
`@Environment(\.isEnabled)`**, so a disabled key rendered identically to a
live one — full brightness, no hint — and silently swallowed taps. The
engine's `postJobAd` was correct the whole time (verified in isolation).
Same CLASS as §31 (the Service button): a control whose look did not match
its interactive state.

### Fix
`GameButtonStyle` now honors `isEnabled` via a nested view (a ButtonStyle's
`makeBody` can't read the environment directly): disabled keys dim to 0.4,
desaturate, take no press travel, and fire no haptic. Every disabled key in
the app now reads as disabled — so a broke player sees WHY they can't post,
and no dead key can masquerade as live again.

### Lesson
A control's APPEARANCE must track its INTERACTIVE state. When something
"does nothing," suspect the view layer — a `.disabled()` with no visual
feedback, a `.mask` eating hits (§31), a gesture/overlay — before the
handler. Custom `ButtonStyle`/control styles MUST reflect
`@Environment(\.isEnabled)`. Verify the handler in isolation first
(RunCodeSnippet), then hunt the UI.


## §36 — Fleet wear: the neglect problem, solved without a nag (2026-07-22)

### The problem
Fleet wear was meant as gentle upkeep pressure, but it turned into a
silent killer: a player deep in routes, hiring, and finances would
forget a plane, and it would crash from wear they never got a warning
about at the right moment. The two obvious fixes both fail the feel bar:
a blocking pop-up guarantees everyone just clicks "service" (no
decision, pure friction), while leaving it fully hidden keeps the
unfair deaths. We wanted it *visible but not nagging, forgiving but not
free.*

### The fix — three moves
1. **Gentler curve.** `wearPerBlockHour` 0.05 → 0.035 (~30% slower).
   Airframes now take meaningfully longer to reach the danger zone, so
   routine attention is enough; you're punished for real neglect, not a
   busy week.
2. **Auto-service autopilot (opt-in).** A single HQ toggle
   (`state.autoServiceWorn`, surfaced in Profile → Operations). When on,
   `closeWeek` runs a pass BEFORE the crash sweep: every delivered,
   flying, un-grounded plane at or past `autoServiceWearThreshold` (78%)
   is sent for a line check ($30K, −25 wear, grounded one week), cash
   permitting. Because it runs first, a serviced plane is lifted out of
   the crash zone that same week — the autopilot can't be beaten to the
   punch by the RNG. If cash is short it skips, and the plane falls back
   to the normal on-screen warnings. Off by default.
3. **Stays visible.** Worn/aging aircraft remain in the HQ attention
   list either way, so even with the autopilot on you still see what's
   happening — it's an assistant, not a black box.

### Lesson
When a mechanic creates unfair-feeling failure, don't reach for a modal.
Soften the curve, keep the signal on-screen, and offer an opt-in
autopilot for players who'd rather not micro-manage — three light
touches beat one heavy interruption.


## §37 — The living map: planes fly the arcs (2026-07-22)

The globe was beautiful but inert: gorgeous terrain, static arcs, nothing
in motion. The first slice of the "give the world a pulse" pillar (Pillar
A of the fun roadmap) makes the network *operate* in front of the player.
Feature A3.1 — core motion.

### What it does
While the sim runs, aircraft glide along each STAFFED route's bow, nose
oriented to travel. Plane **count** encodes frequency (a trunk route
buzzes with three, a feeder trickles with one); every plane moves at the
same calm pace, so the map never looks frantic. Busy routes fly in both
directions; a lone plane goes one way. Planned (unstaffed) routes stay
dashed and empty, so flying-vs-planned is instantly legible. On pause,
planes freeze — consistent with the charter ("nothing happens while you
aren't looking").

### How it works (pure UI, zero sim coupling)
- One file: `RouteMapView.swift`. No `GameState`, no Simulation, no RNG,
  no persisted field touched — it only READS state.
- A `TimelineView(.animation)` wraps the Canvas; its schedule is `paused`
  whenever `engine.speed == .paused` or Reduce Motion is on (back to the
  old zero-cost static globe). Each frame it advances a monotonic
  `flightPhase` by `Δtime × engine.speed.rawValue` — so pause truly
  freezes, x2 doubles the tempo, and positions are a pure function of the
  phase (a pan/zoom mid-flight can't teleport a plane off the terrain, the
  same guarantee the city dots have).
- Planes ride the exact drawn arc: `arcPoints(for:)` returns the quad-
  bezier the route stroke uses, and `bezier`/`bezierTangent` give position
  and heading. A stable per-route hash offsets and desyncs planes.
- Perf: ~1 plane per daily departure, capped at 3/route and 40 on screen
  (busiest routes first); horizon-culled by the existing projection.

### Where it appears
Full-network map AND the single-route focus map (Route Detail), where one
or two planes make inspecting a route a quiet little moment.

### A3.2 — embellishments + the round-trip fix (2026-07-22)
- **Round-trip shuttle.** A3.1's planes wrapped 1→0 and snapped from
  destination back to origin. A lap is now a full out-and-back (out 0→0.5,
  back 0.5→1): a plane shuttles smoothly and never teleports, and a SINGLE
  plane naturally shows both directions (staggered offsets keep a
  multi-plane route busy in both). Lap time ~8s at x1.
- **Comet trails.** A short white streak trails each nose, sampled along
  the same bezier and faded with a linear gradient — reads motion and
  direction at a glance.
- **Load-factor breathing.** A staffed arc's glow underlay pulses wider and
  brighter with `lastLoadFactor` (per-route phase so the network doesn't
  throb in unison); planned routes stay steady. Zero-amplitude on empty
  routes, so it only shows where planes actually fill seats.
- **Arrival ripples.** A quick expanding ring at whichever endpoint the
  plane just reached — destination at the half-lap, origin at the wrap.
All still pure UI, frozen on pause / Reduce Motion, within the same 40-
plane budget.


## §38 — Phase-1 win moments & a second voice (2026-07-22)

Three cheap, high-payoff pieces of the fun roadmap: a ceremony for the
career-defining wins, a record-week brag, and an ops-chief voice that
tells you the one thing worth doing.

### Grand-honor ceremony
Two honors now trigger a full-screen ceremony (a gold medallion that
springs in — the "punch" the polish audit found missing): reaching **#1**
on the industry ladder, and becoming the **flag carrier** (serving every
city in the home country). `checkHonors()` runs at `closeWeek` after the
records pass; `state.honorsAwarded` awards each once, and — like the
ambition ladder — the FIRST encounter grandfathers whatever's already true
UNANNOUNCED, so loading a grown airline doesn't fire a stale ceremony. The
transient `state.lastHonor` drives a `.sheet` in RootView; the ceremony
copy is built in the UI (country/airline names), so the engine stays
formatting-free.

### Record-week brag
`updateRecords` now flags a new **best week** that beats the prior best by
≥20% (real money ≥ $50K), at most once every 13 weeks — a quarterly
cooldown that keeps it a genuine "career best" moment, not a growth-spurt
spammer. It sets `state.lastRecordProfit` (raw Double; the UI formats via
`.money`), shown as a `CelebrationBanner`.

### Ops-chief briefing — REMOVED (2026-07-22)
Cut shortly after shipping: the desk already surfaces the actionable
conditions directly, and the extra voice was redundant. Your Desk was
reordered so conditions and effects lead, with the Gazette news beneath.
The original design is kept below for the record.

A second character beside the aunt. `opsChiefName` is a stable,
country-appropriate name (same pools as rival spokespeople). `opsChiefBriefing`
returns the single highest-value action in the chief's voice, by priority:
a plane flying dangerously worn → a route losing money → a pool at
strike-risk morale → a slipping route → idle metal → an aging airframe →
an all-clear (nudging the next rival, or a nod from the top of the table).
It reuses existing signals (`routesNeedingAttention`, `strikeRiskPools`,
`agingAircraft`, wear) — no new sim state — and rides a card at the top of
HQ once the airline is flying.

All three respect the no-formatting-in-Simulation rule and save-compat
(new fields optional, nil-grandfathered).

### §37/§38 addendum — real plane art + swipe-away toasts (2026-07-22)
- **Top-view aircraft marker.** The living-map dart is replaced by a
  top-down airliner photo (`plane_top`, Resources/Art). The source is a
  white plane on a white field — colour keying can't separate them — so at
  load we FLOOD-FILL the near-white background inward from the borders
  (threshold 244), which stops at the plane's shaded outline, leaving the
  airframe intact. Cached once (`RouteMapView.planeImage`), drawn rotated
  by `heading + π/2` (art nose points up) with a soft drop shadow to read
  on bright terrain. Dart remains as a fallback if the image is missing.
- **Swipe-up dismissal.** `CelebrationBanner` gained an optional
  `onDismiss`; when set, a short upward flick clears the toast early
  (milestones, ambitions, overtakes, record week) instead of waiting out
  the 3.5s timer. The four RootView banners were extracted into a `topBanner`
  helper to keep `body` inside the type-checker's budget.


## §39 — Living Rivals + Capital (2026-07-23)

Pillar B of the fun roadmap plus its flip side: the ladder becomes a cast
of players who can fight you OR buy into you. Built in phases; each is
shippable and bot-verified on its own. All of it is pure sim, deterministic
(weekly RNG only), save-compat via optional fields.

### The plan (four phases)
1. **Rivals move** — dynamic, drifting market caps so the ladder lives.
2. **Rivals act** — named route incursions, undercut, crew poaching, and a
   persistent "nemesis" feud with the carrier just above you.
3. **Capital: financial core** — equity-for-cash, weekly profit share,
   buyback at current valuation, a cap-table card, and rescue financing.
4. **Capital: the drama** — strategic rival stakes with a board voice,
   takeover attempts you defend against, and an "exit" acquisition ending
   (a second summit beside reaching #1).

### Capital model (design, phases 3–4)
An investor offers cash for a stake, valuing you at `marketCap`
(`cash = marketCap × stake × dealDiscount`). Each settle they take
`stake × max(0, dailyProfit)` off the top (upside only, never losses), and
their slice reduces the net-worth score. Buy the stake back anytime at the
CURRENT valuation — so early money is cheap insurance if you struggle,
expensive if you soar. Max outside ownership caps below 50% (you keep
control unless you accept a takeover); a valuation floor stops a near-broke
founder being bought whole for pocket change.

### Phase 1 shipped — rivals move
- `GameState.rivalCaps: [String: Double]?` — each rival's LIVE cap. nil
  seeds from the static ladder on the first close (old saves start from
  today's caps, unannounced).
- `driftRivals()` in `closeWeek`: every rival's cap drifts on a stable
  per-rival annual growth rate (`Balance.rivalWeeklyGrowth(seed:)`, roughly
  −2%…+10%/yr by name hash) plus small seeded noise
  (`rivalWeeklyNoise = 0.5%/wk`), floored at `rivalFloorCap`. Iterates the
  static ladder in its FIXED order (not the dictionary) so the RNG stream
  stays deterministic; placed AFTER the crash/attrition/event draws so
  existing systems' outcomes are unchanged for a given seed.
- `GameEngine.currentRivals` applies the live caps and re-sorts; `industryRank`,
  `nextRival`, `checkRivalOvertakes`, `collapseAcquirer`, and the
  rival-collapse pool all read it now instead of the static ladder. So rank,
  ambitions (rank rungs), overtake celebrations, and honors all reflect the
  moving ladder.
- Verified in-engine: over 3 years the caps spread (Himalaya +5%, Ganga
  +10%, Peacock flat) and a re-run reproduces identical caps (deterministic).
  Player economics are untouched, so no §26 balance regression.
- Tuning (`rivalWeeklyGrowth` spread, noise, floor) lives in Balance; widen
  later if the movement should bite harder in play.

### Phase 2 shipped — rivals act (2026-07-23)
- **Named route incursions.** `Route.contender: String?`. In `closeWeek`, a
  flying route whose `rivalPressure` climbs to `floor + 0.75` gets a named
  challenger (cleared when it recedes to `floor + 0.4`). The name is a
  size-appropriate peer (`incursionRival` — a giant won't bother a minnow;
  a founder draws from the smallest carriers), seeded on the CITY PAIR (not
  the route UUID) so it's fully deterministic across runs. The threshold was
  lowered from `floor + 1` because elasticity caps how fat a route gets, so
  `+1` was effectively unreachable (and had left the old "New competition"
  attention signal near-dead too).
- **News + attention.** The first new incursion each week posts a Gazette
  headline (`incursionStories`/`incursionHeadlines`), and
  `routesNeedingAttention` now flags "{rival} moved in" whenever a route has
  a contender.
- **Crew poaching.** `rivalPoachSweep` — once you field ≥6 crew and a
  contender is active, a small weekly seeded chance (`rivalPoachChancePerWeek
  = 3.5%`) that the raider hires away your HIGHEST-PAID member of a random
  pool. Posts a Gazette headline; deterministic (seeded), placed after the
  existing RNG draws so their outcomes are unchanged for a seed.
- **Nemesis.** `state.nemesis` tracks the carrier just above you; the
  standing Gazette jab now names your BUSIEST route (`nemesisJabs`) so it
  reads personal.
- Verified in-engine: a fat, high-yield, low-floor route pulls a named,
  size-appropriate contender, posts the headline, and flags attention — and
  the whole thing (caps, contenders, news) replays identically.
- Player economics untouched (incursions only NAME the existing pressure);
  the poach is the one new material consequence, kept rare.

### Phase 3 shipped — capital, financial core (2026-07-23)
- **Model.** `Investor {id, name, isRival, stake, boughtAtValuation,
  sinceWeek}`; `GameState.investors: [Investor]?` (nil = you own it all).
  `CapitalOffer {funderName, stake, cash, isRescue}`.
- **The deal.** `cash = dealValuation × stake × discount`, where
  `dealValuation = max(marketCap, investorValuationFloor $2M)` and discount
  is 0.85 (growth) / 0.70 (rescue) — the backer buys in below fair value,
  that gap is their return. Growth rounds buy `investorGrowthStake 15%`;
  rescue takes `investorRescueStake 35%`. Total outside equity never exceeds
  `investorMaxOutsideStake 49%` (you keep control).
- **Profit share.** At the daily settle, investors take
  `outsideStake × max(0, dayProfit)` — upside only, never your losses. Booked
  as a distribution (reduces cash), not an operating cost line. No RNG.
- **Buyback.** `buyBackCost = dealValuation × stake` at the CURRENT
  valuation — growing makes buying back dearer (and raising cash lifts the
  valuation, so it compounds), which is exactly the tension: cheap insurance
  early, expensive once you soar.
- **Rescue.** When `cash < 0 || weeksInsolvent > 0`, `capitalOffer()` returns
  a harsher rescue (35% at a 0.70 discount) — a dignified alternative to the
  Grounded screen.
- **UI.** A "Capital" card on the Money tab (below The Bank): the standing
  offer with an `Accept · $X` key, and a cap table listing each backer with
  a `Buy back · $X` key (disabled when unaffordable, so no dead key).
- Verified in-engine: offer at 85% of value; stacking caps at 44% (won't
  cross 49%); buyback scales with the risen valuation; investors skim only
  profitable days. Deterministic (arithmetic + hash-named funds).
- Phase 4 (rival stakes, board demands, takeover, exit ending) will set
  `isRival = true` and layer on top of this core.

### Phase 4 shipped — the drama (2026-07-23)
- **Rival stakes.** `rivalStakeOffer()` — your nemesis angles for a
  `investorRivalStake 20%` bite at a keener `0.80` discount, once you're
  worth their attention and no rival is aboard. `acceptRivalStake` adds an
  `Investor(isRival: true)`. Surfaced on the Money → Capital card as a
  distinct "Strategic approach".
- **Board demands.** While a rival holds equity, `maybeBoardDemand`
  (`boardDemandChancePerWeek 10%`, seeded) posts a `BoardDemand` naming your
  busiest route. `complyWithBoard` pushes that route's fare +10% and the
  backer injects `boardComplyReward 2%` of valuation as cash; `refuseBoard`
  grows their stake by `boardRefusalStakeBump 6%`, creeping toward control.
  Shown as a Boardroom banner on the Capital card.
- **Takeover.** When `rivalStake ≥ takeoverStakeThreshold 35%`,
  `checkTakeover` sets `state.takeoverPending` and pauses the clock (the
  `gameOver` guard on the tick). A full-screen RootView overlay: **Defend**
  (buy the raider out entirely at the current valuation, cash permitting) or
  **Accept buyout**.
- **Exit ending.** `acceptBuyout` pays `buyoutProceeds = dealValuation ×
  (1 − outsideStake) × exitPremium 1.15`, sets `state.soldOut`, and shows a
  celebratory "Bought out" overlay with the run's numbers and a restart — a
  second win condition beside reaching #1. `restart()` clears everything
  (fresh state).
- Verified in-engine: rival offer/accept (20%), a rival at 36% trips the
  takeover on the next close and holds the clock, Defend clears them and
  keeps control, Accept books proceeds and ends the run. Deterministic; new
  state fields optional/nil-grandfathered.
- Guardrails intact: outside ownership still caps <49% via the shared path;
  investors share only profits; every money key is affordability-gated.
