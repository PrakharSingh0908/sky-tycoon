# SkyTycoon — MVP Backlog (v0.1)

Companion to [GAME_DESIGN.md](GAME_DESIGN.md) §8 and [SkyTycoonStarter.swift](SkyTycoonStarter.swift).
Scope decisions locked July 2026: **used market + leasing in MVP**, **one national marketing slider in MVP**, everything else per GDD phasing (India only, no competitor AI, no ancillaries, no widebody).

**Definition of done for the whole MVP:** a stranger can play 2 hours and want to keep going.

---

## Milestone 0 — Foundation (the boring week that pays for everything)

Get the starter file running as a real project with the guarantees the architecture promises.

- [ ] Split `SkyTycoonStarter.swift` into the folder structure from its §6 footer (`Simulation/` pure Swift, `UI/`, app entry). Simulation files must never import SwiftUI.
- [ ] Add a unit test target. First test: **determinism** — two engines, same seed, same scripted actions, identical `cash` and full `state` after 100 `advanceWeek()` calls. This test stays green forever.
- [ ] **Fix: autosave.** `advanceWeek()` never calls `save()` — the GDD promises autosave every tick. Call it at the end of the tick (bookkeeping step 8).
- [ ] **Fix: aircraft aging.** `ageYears` is never incremented, but depreciation and `netWorth` depend on it. Add `+= 1/52` per tick.
- [ ] **Fix: runway gate.** `assign()` checks range but not `requiredRunwayClass` vs both cities.
- [ ] Save-file versioning smoke test: encode → decode → re-encode is stable.

*Exit criteria: app runs on device, determinism test green, closing and reopening the app resumes exactly where the sim was.*

## Milestone 1 — Fleet acquisition (used market, leasing, delivery waits)

The first-hour experience. GDD §4.1 as amended.

- [ ] `AcquisitionType` on `Aircraft`: `.ownedNew`, `.ownedUsed`, `.leased`.
- [ ] **Used market:** seeded generator produces 3–5 listings (archetype, age, **visible** condition 40–90, price = new price × condition/age curve, 30–60% of new). Listings refresh every 3–4 weeks from the seeded RNG (determinism preserved).
- [ ] **Leasing:** any archetype instantly, ~0.25%/week of new price (tunable in `Balance`), termination fee = 4 weeks of payments. Lease payments join the weekly P&L as their own line.
- [ ] **New planes:** `buyAircraft` becomes an order — status `.onOrder`, fixed delivery wait per archetype (e.g. turboprop 8 wk, small NB 16 wk, large NB 24 wk), cash on order.
- [ ] Sell owned aircraft at depreciated value (uses the now-working `ageYears`).
- [ ] Showroom UI: three tabs (New / Used / Lease) inside the Fleet tab.
- [ ] Balance pass: a used turboprop + one loan must be reachable on day one in India with ~$2.4M.

*Exit criteria: a new game can field its first plane three different ways, and the choice feels like a real tradeoff.*

## Milestone 2 — Crews, understaffing, and real satisfaction

Starter footer step 3 + GDD §4.4 / §4.5. Right now headcount only affects wages — this milestone makes people matter.

- [ ] Crew-hours model: each flight consumes pilot/cabin hours (scaled by aircraft + route length), ground hours per departure, HQ hours per airline size. Compare demand vs `headcount × weekly capacity`.
- [ ] Understaffing → **delay probability** → punctuality score per route; overtime pay at 1.5× for hours over capacity.
- [ ] Happiness gains a workload term (currently pay-only): overworked pools drift down even at market wage.
- [ ] Happiness thresholds per GDD: <40 attrition (headcount leaks weekly), <25 strike-risk flag (feeds Milestone 3's event weights).
- [ ] Rebuild route satisfaction on the GDD §4.5 weights: punctuality 35%, comfort 25%, service (cabin skill/count) 20%, price fairness 15%, incidents 5%.
- [ ] People tab: show workload/capacity bar and a plain-language warning ("Your pilots are flying 20% over roster").

*Exit criteria: hiring nobody and flying anyway visibly hurts punctuality, satisfaction, and eventually reputation — and the UI told you why.*

## Milestone 3 — The event deck

Replace `maybeFireEvent()` with the real system. GDD §4.7.

- [ ] `EventCard` as data in `Balance`: id, category, weight, trigger conditions, 2–3 options. Effects become an enum with associated values (cash, happiness by pool, satisfaction by route, fuel-price modifier weeks, grounding, reputation) instead of the current flat deltas.
- [ ] Weighted draw with state-shifted weights: high wear/backlog → more technical cards; low happiness → more labor cards; low maintenance staff → more fault cards.
- [ ] Guard rails: no two negative events in consecutive weeks in year 1; sim auto-pauses on fire (already works).
- [ ] Ship the 12 MVP cards — at least one per GDD category: market (fuel spike), weather (airport closure), labor (raise demand, strike), technical (fault found, grounding), opportunity (VIP charter), regulatory (audit), PR (viral moment).
- [ ] Timed effects system (e.g. "fuel +30% for 6 weeks") stored in `GameState` and applied during the tick.

*Exit criteria: events feel like consequences of your state, not dice; every option's cost is visible before choosing.*

## Milestone 4 — Seat configuration editor (hero screen)

GDD §4.2. The most tactile screen in the game — worth real polish time.

- [ ] Cabin editor sheet from aircraft detail: horizontal fuselage cross-section, seats redraw live as the density slider moves ("sardine" ↔ "spacious").
- [ ] Live readout: seat count, comfort score, projected per-flight revenue at current fare — the tradeoff visible in one glance.
- [ ] Reconfiguration costs money and grounds the plane 1 week (reuses maintenance grounding machinery).
- [ ] Condition-based comfort ceiling: old airframes cap the comfort score (already partly modeled in `comfortScore`).

*Exit criteria: you can feel the economy/comfort tension in ten seconds of dragging.*

## Milestone 5 — Marketing slider

GDD §4.8 as amended (MVP slice only).

- [ ] `brandAwareness (0–100)` in `GameState`; weekly marketing budget slider on the Money tab.
- [ ] Awareness gain = f(spend) with diminishing returns; decay 3%/week at zero spend.
- [ ] `brandMultiplier` becomes f(reputation, awareness) — e.g. reputation sets the range, awareness fills it — replacing the current reputation-only formula.
- [ ] Marketing line in the weekly P&L.

*Exit criteria: a launch marketing push measurably fills planes, and stopping spend visibly fades demand over ~2 months.*

## Milestone 6 — Trust-fund arc, aunt letters, milestones

The objectives layer. GDD §3.1 + §6.

- [ ] Quarterly report screen framed as the aunt's letter, tone keyed to performance (3–4 letter templates × tone variants).
- [ ] Trust-fund resolution both ways: success → fund converts to gift + reputation bonus + achievement; failure → withdrawal event (the `closeQuarter()` TODO) and "hard mode" continues.
- [ ] Milestone system (Layer 1): ~10 contextual tasks with small cash rewards ("open your third route", "hit 80% load factor", "complete a heavy check", "reach 4.0★"). Tracker on the Dashboard; never blocks anything.
- [ ] Fail states: bankruptcy check (cash < 0 for 8 consecutive weeks, no sellable assets) with a game-over-and-restart screen; reputation-collapse warning banner below 2.0★.

*Exit criteria: a new player always knows what to do next, and year 1–3 has a narrative spine.*

## Milestone 7 — Money depth and explainability

GDD §3.2 (MVP slice) + §4.9, design pillar 4.

- [ ] One bank, 3 loan offers (small/medium/large with different rates/terms) replacing the hardcoded $1M/$5M buttons; a simple lending limit tied to net worth.
- [ ] Balance sheet view: cash, fleet value, debt, net worth sparkline (history already collected).
- [ ] **Tappable formulas:** every P&L line and the route demand number opens a breakdown sheet showing the actual formula with the player's numbers substituted in. This is the tutorial.
- [ ] Quarterly archive list on the Money tab.

*Exit criteria: any number a player doubts can be tapped and understood in one sheet.*

## Milestone 8 — New-game flow, polish, balance, TestFlight

- [ ] New-game screen: airline name entry, country card shown but India-only for MVP (others "coming soon" — sets up v1.0).
- [ ] Number-tick animations on the weekly settle; route map view on the Routes tab (city dots + lines, thickness = frequency, color = profitability) if time allows — list UI is the fallback.
- [ ] Move the tick driver from `Timer` to `CADisplayLink`-backed accumulation per GDD §9 (or consciously keep `Timer` and amend the GDD).
- [ ] Balance playtesting: 3 full trust-fund-arc playthroughs (cautious/aggressive/negligent archetypes); tune `Balance` constants only.
- [ ] App icon, launch screen, TestFlight build to 5–10 strangers. Watch the 2-hour test.

---

## Known starter-code issues (tracked, fix in the milestone noted)

| Issue | Where | Fix in |
|---|---|---|
| `advanceWeek()` never saves — autosave promise broken | `GameEngine.advanceWeek` | M0 |
| `ageYears` never increments; depreciation dead | tick loop | M0 |
| `assign()` ignores runway class | `GameEngine.assign` | M0 |
| Airport `weeklySlots` defined but never enforced | `openRoute` / frequency setter | M2 (with crew-hours capacity work) |
| Understaffing has zero effect | tick step 3 | M2 |
| Trust-fund success path unimplemented (TODO) | `closeQuarter` | M6 |
| `buyAircraft` is instant + full price (no order/delivery) | `GameEngine.buyAircraft` | M1 |
| Event/`EventOption` UUIDs use unseeded `UUID()` — harmless to sim math but noisy for replay diffing | models | M3 (generate ids from seeded RNG if replay diffing is ever needed) |

## Deliberately NOT in MVP (resist the urge)

Competitor AI, other 4 countries + special rules, international routes, 3-class cabins, hidden condition + inspections, manufacturer financing/warranty/relationships, credit score + 3 banks, ancillary toggles, marketing campaign types, notable staff characters, slot auctions, cargo, alliances. All specced in GDD — none needed to prove the loop.
