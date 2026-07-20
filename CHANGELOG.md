# SkyTycoon — Changelog

All notable changes to this project, with the reasoning behind them.
Format loosely follows [Keep a Changelog](https://keepachangelog.com); versions
track the build phases in [GAME_DESIGN.md](GAME_DESIGN.md) §8 and milestones in
[MVP_BACKLOG.md](MVP_BACKLOG.md). Every entry says **what** changed and **why**.

---

## Event pauses stop hijacking the speed control

- An event card no longer force-sets the sim speed to Paused, and no longer lights any pause indicator. The clock still stops while a card is up (via the pendingEvent guard in the tick), but the speed control keeps showing the player's chosen speed, the sim pill shows its running state (not the yellow held icon), and time resumes at that same speed the instant the event is answered. Because the event sheet self-sizes and leaves the pill visible behind it, an event was showing a false pause on the shorter cards; that is gone.

*Why:* per direction. Forcing speed to Paused, or lighting the held indicator, for a temporary event read as if the player had paused and made the timeline appear to jump on resume. The tick already holds itself during an event, so the UI should say what the player will get back: their speed, running.


## Lawsuits wait for the airline to grow; hiring desk auto-closes

- The tea-spill (−$180K) and hard-landing (−$300K) incident cards no longer fire in the opening months. Their intro weeks move out to week 30 and week 36, and each now also requires a real cash cushion (≥$360K and ≥$600K respectively), so a founder's first season can never be ended by a single lawsuit. A comfortable operator still meets them.
- The Hiring desk closes itself the moment the last applicant is hired or turned away, instead of leaving you on an empty "Nobody at the desk" screen to tap Done. Hiring the final applicant now dismisses the desk FIRST and raises that hire's contract card from the People screen itself, so closing the contract returns you straight to People with no empty tab behind it. Rejections and walk-aways that empty the desk dismiss with the departing applicant sliding out (the roster freezes its last snapshot so no blank desk is ever drawn).

*Why:* per direction. A $300K settlement against a $200K airline was a coin-flip game-over that punished nothing the player did; tying these to both time and cushion makes them a mid-game risk, not an opening trap. And an empty applicant desk had one obvious next action, so the game should take it.

- The Finances card's Cash view now carries a dashed coral debt line alongside the solid cash line, with a small line-sample legend: liquidity against what the bank is owed, on one instrument. Debt history is a new capped 260-week buffer appended each settle (optional in GameState, so old saves decode and the line grows from their next week). TrendChart gained a general secondary-series option.
- The trend tabs reorder to Cash, Net worth, Reputation, and Cash is the default view.

*Why:* per direction. Cash is the number you spend from day to day, so it leads; and cash climbing while the debt line stays flat is the honest picture of a business borrowing its way up.


## Wages read to the $50

- New wageMoney formatter shows wages at 0.05K precision ("$1.20K" instead of "$1.2K"; exact dollars under $1,000). Applied everywhere a wage prints: the wage stepper, roster rows, hire keys, the negotiation table, the signed contract, and the P&L wage breakdown.

*Why:* per direction. The compact money style rounded to $100, so a $50 wage step often left the display unchanged and the stepper looked dead even though the sim had moved.


## Pay the bank back early

- Every loan on the Money tab now shows its weekly payment and a "Pay down" key that opens a repayment drawer: the remaining balance meter, cash on hand, and a slider from zero to everything you can afford (armed at the maximum). The key says exactly what it does: "Pay $X", or "Pay it off · $X" when the slider covers the balance. Paying clamps to cash and balance, a cleared loan closes its file, and the sim clock holds while the drawer is up. New engine repayLoan(loanID:amount:), no prepayment penalty.
- The bank card also states plainly that loans deposit to cash in full on signing. They always did (cash += principal the moment you borrow), but the net worth board holds still because debt rises by the same amount, which read as the money never arriving.

*Why:* per direction. Debt you cannot voluntarily retire is a trap, not a tool; and the deposit note turns an accounting identity into something the player can see.


## Wage lever feels alive: hold to step, morale reacts the same day

- PillStepper keys (wage, fare, flights per week) now auto-repeat while held, so moving a wage $500 is a press, not ten taps.
- Changing a wage moves the Happiness meter immediately: morale takes a 25% step toward the new pay target the moment the wage changes, then the weekly drift keeps settling it. The target formula is extracted into happinessTarget(role:weeklyWage:staffLoad:) which the weekly tick runs too, so the same-day step and the drift can never point in different directions.

*Why:* per playtest feedback, the wage lever felt dead. You tapped, the number crept by $50, and happiness sat still until the next settle because morale only drifted weekly. A raise is news the day it lands; the immediacy rule says the instrument moves NOW even though the money still settles weekly.


## Poaching asks first

- Tapping a plane under "On other routes" now raises a confirmation dialog instead of moving it silently: "Move AI-C off BOS ✈ PHL?" with "Move it here" and "Keep it there", and a one-line reminder that it stops flying its old route the moment it moves. Free planes and removals stay one-tap. The sim clock holds while the dialog is up, same as the cancel-route dialog.

*Why:* per direction. Adding idle metal is routine, but pulling a plane off a working route cuts that route's capacity; a move with a real cost deserves a deliberate yes.


## Assignment desk decluttered

- The route's aircraft list is grouped into three shelves: planes on this route (checkmark, tap removes), free planes ready to add (plus, tap adds), and planes flying other routes folded into an "On other routes (N)" disclosure. Poaching still works with one tap; the stamped badge names the route each plane would come off, and the wordy "Assigning here pulls it off X" warning that repeated the badge is gone. Meta reads one line ("Orion 212 · 1,931 km", no wrap), on-order planes show "Delivers · N wk", and planes that can never fly the pair (range or runway) are not listed at all.

*Why:* per direction, the list was a mess at fleet size: every plane in the airline got a row, the same fact was printed twice, and the meta wrapped. The desk now answers the actual question, which is who is here and who could be, in one screen.


## Route-aware buying: the drawer that staffs the route

- The boarding pass key now reads "Configure" once a route has aircraft assigned; "Set up route" stays for fresh routes only.
- "Buy more aircraft" on the route screen is now "Add planes to this route" and pops the route-aware showroom as a drawer instead of pushing a screen. Anything acquired there lands on that route automatically: leases and used buys assign the moment the deal closes, and new orders remember their posting and join the route the week they deliver (falling back to idle if the route is gone or the fit no longer works).

*Why:* per direction. Buying from a route's desk and then hand-assigning the same plane was two steps that should be one; the drawer keeps you in the route's context, and delivery-time joining keeps on-order planes out of the sim until they actually exist.


## Asking wage dropped from applicant meta

- The applicant row's meta line no longer repeats "asks $X/wk"; it now reads just "waits N wk". The Hire key already carries the wage.

*Why:* per direction. The same number sat twice in a 60pt row; the button is the one that matters because it is the price you tap.


## Reject applicants, and a pin proving assignments move workload

- Each applicant row at the hiring desk now has a quiet reject cross in its corner: one tap and they leave the pool immediately (engine rejectApplicant). No penalty; you simply pass. A "Hiring desk" preview pins the row.
- Verified that assigning a plane to a route already moves the Workload meter instantly (it reads the same liveCrewDemandHours the tick runs). Added a "Workload moves on assignment" preview pin: baseline pilots at 65% next to the same pool at 120% with the overwork warning, immediately after one extra plane was leased and assigned with no settle between.

*Why:* per direction. Rejecting was the missing third answer at the desk (hire, haggle, or pass), and the workload pin turns an invisible immediacy guarantee into a regression test.


## Workload meter moves the moment you hire

- The Workload meter on the People cards (and the overwork warning) now reads a live projection instead of last week's settled value: crew demand hours from the current routes and assignments over current headcount. Hire someone and the meter drops before the sheet closes; assign a plane or bump frequency and it rises. The demand-hours formula is extracted into liveCrewDemandHours(), which the weekly tick runs on too, so the projection can never disagree with what next week books.

*Why:* per direction, joins are instant now, so a meter frozen on last week's number read as a bug. Same immediacy rule as fares and load factor: touch a lever and the instruments move NOW; money still settles weekly.


## Instant joins and the contract-signing moment

- New hires are on the job the moment the contract inks. The "+N joining", "joins next wk", and "on duty next wk" treatments are gone (the sim always counted hires immediately; the copy claimed otherwise). Fresh hires read "just joined" on the roster for their first week.
- Signing now has its moment: after a hire (direct, at asking from the negotiation table, or on an accepted offer), a self-sizing contract sheet presents with the employee's portrait springing in, the stamped terms (position, weekly wage, starts immediately), and their signature drawing itself across the line in the handwriting face, with a success haptic. Negotiated hires ink at the negotiated wage. A "Contract signed" preview pins the card.

*Why:* per direction, smoother UX. The fake one-week delay was pure copy debt that made hiring feel laggy; and a hire is the most personal transaction in the game, so it deserves the same ink-and-paper ceremony as the aunt's letters.


## Silver icons on the Fleet empty state and Showroom row

- The "No aircraft yet" airplane medallion and the Showroom cart icon on the Fleet screen now wear the polished-silver gradient with the soft glow, replacing their cornflower accent fills. The treatment is extracted into a reusable polishedSilver() modifier that SectionHeader also uses, so future icons take one call. An "Empty fleet" preview pins the state.

*Why:* per direction. Same v3.1.3 rule as the header icons: instruments on the console are silver; the accent is for active states and data, not stickers.


## Contractors split out of the wage line

- Contractor overflow spend (excess hours flown at market rate × 1.8) now books to its own WeeklyReport line, P&L statement row, and graphite pie slice instead of hiding inside Wages. The Contractors row explains itself: which pools overflowed and by what share of hours, with the formula noting that hiring staff moves this spend to wages at 1×. The wage explanation now reads "Total incl. overtime" only. Old saves decode with a nil contractor line, so past reports are unchanged.

*Why:* per playtest feedback, building your own team never visibly paid off because the wage line lumped salaries, overtime, and contractor premiums into one number. The economics were already right (own staff cost 1× per hour, contractors 1.8×); the ledger just could not show the trade. Now staffing up visibly drains the Contractors line into the cheaper Wages line.


## Machined meters (v3.1.4)

- MeterBar, the progress bar behind Happiness, Workload, Load factor, Condition and every other 0 to 1 readout, is now a machined instrument channel: a recessed groove with a dark cut above and a catch-light below, quarter graduations engraved in the floor, and a milled metal slug of the semantic color riding 1pt inside it with a rolled specular top, shaded underside, polished end bevel, and a faint color bleed out of the groove. At zero the slug rests as a pilot-light dot; at 100% the channel lip stays visible around the metal. One component, every meter in the game inherits it. A "Meters" preview pins all fill levels and colors; design doc updated.

*Why:* per direction, the flat capsule read as a default control. Meters are the game's most repeated surface, so this is the highest-leverage place to spend craft; the recess and slug put them in the same machined-metal family as the keys, panels, and wells.


## Skill number dropped from staff cards

- The "2.0 skill" readout beside the stars on the People staff cards is gone; the gold-star rating carries the skill on its own.

*Why:* per direction. The stars already say it; the decimal restated them in smaller type and added noise to the card header.


## Full-width job ad button

- "Post job ad" on the People staff cards now spans the full card width with a centered label, instead of hugging its text at the leading edge.

*Why:* per direction. It is the card's one primary action, and edge-to-edge matches the Set up route and Cancel route keys elsewhere.


## Seattle stamp removed

- The Seattle city stamp on boarding passes is gone: tried first franked beside the destination code, then as a ghost watermark behind it, and cut on review. The asset, the cityStamps map, and the preview pin are all removed; the pass is back to its clean pre-stamp layout.

*Why:* per direction, it looked bad on the ticket in both treatments. The dark-ink engraving never sat naturally on the carbon card, and the pass reads better without decoration competing with the flight data.


## Slide to lease

- The Lease button in the showroom's lease cards is now a SlideKey, a new design-system control: a bronze machined key travels a recessed groove past the engraved "Slide to lease" label, and the contract signs only at the end of the throw. Short pulls spring back; a full pull fires the success haptic and the receipt. Locked tiers keep the lock plate over the whole card. A "Lease tab" preview pins the control.

*Why:* a lease is a weekly obligation forever, not an impulse buy; a deliberate gesture makes signing feel like signing and stops accidental taps from adding a plane.


## Silver glow header icons everywhere (v3.1.3)

- All SectionHeader icons app-wide now wear the polished-silver gradient with the soft white glow, replacing the cornflower accent icons. One component change covers every card; the accent keeps its role for active states, selection, and data strokes. Design doc updated.

*Why:* per direction after First Flight - the silver instrument icons belong to the machined console language, and consistency is the premium.


## Silver glow icon on First Flight

- SectionHeader gained a silverIcon option: polished silver gradient with a soft white glow, for headers that live on metal panels. First Flight's checklist icon uses it.

*Why:* the cornflower accent icon read as a flat sticker on the machined housing; silver with glow belongs to the material.


## First Flight rides the hero's housing

- The checklist moved back below the net worth board and now renders on a MetalPanel - the same machined face, gradient rim, diagonal sheen, and inner hairline frame as the hero - so the founder's opening screen reads as one two-part console.

*Why:* per direction - position under the score, material matched to it.


## First Flight card refined

- The checklist now LEADS the Dashboard (above the hero) until the airline flies, with the accent stroke removed - hierarchy by position, not decoration.
- Step pointers are machined numbered discs (gunmetal gradient with a light-catching rim, checkmark on green metal when done), top-aligned to each row instead of vertically centered, with a hairline rail connecting the steps stepper-style.

*Why:* per direction - the founder's first decision deserves the top slot, and the hardware language should match the rest of the console.


## First Flight onboarding card

- New founders get a checklist card on the Dashboard, right under the hero: three steps (lease your first aircraft, open your first route, put the plane on the route), each row opening the relevant surface directly as a sheet - the showroom on the Lease tab, the route desk, or the first route's detail for assignment. Steps check off and strike through as the airline comes alive; the card retires itself once a plane is flying a route.
- ShowroomView gained an initialTab parameter; NewRouteSheet is presentable from anywhere.

*Why:* per request - a brand-new player was left staring at an empty dashboard with $200K and no pointer; the opening moves now live on the home screen.


## Map first-load alignment fix

- Airport dots no longer drift off the terrain on first load. The SceneKit camera's orthographic scale was computed from view.bounds, which is zero before layout, so the globe rendered at the wrong zoom until the first pan recomputed it. The scale now comes from SwiftUI geometry, so the very first frame matches the Canvas overlay's math.

*Why:* the overlay and terrain are only ever in sync if both derive from the same size; UIKit bounds during representable setup are not that size.


## The Foundation Era (GDD §0 charter + §22)

- Every game now starts with a flat $200K seed (difficulty-scaled). No airplane is affordable on day one: the opening move is a leased Orion feeder and one route that has to work. HQ overhead scales with fleet size ($2.5K + $1.4K per aircraft) instead of a flat $15K, and the reference fare is squeezed to 0.120 $/km.
- Fleet tiers: five license levels (Feeder → Regional → Jet → Mainline → Flag Carrier) unlocked at market-cap thresholds ($1.5M / $8M / $40M / $200M). Crossing one fires a celebration event card listing the freed models; the showroom shows locked metal behind a lock plate naming the requirement; engine guards enforce it. Old saves grandfathered at the top tier.
- The deep ladder: rival tables now run 54 (India) to 68 (US) carriers, from the flag carrier down to $120K charter outfits with generated market-flavored names. A fresh airline enters around #60-69 and climbs. The Industry sheet shows the top of the table plus your seven-carrier neighborhood; the share pie buckets the long tail.
- GAME_DESIGN.md gains §0 "The Feel", a vision charter: the fantasy, the four-era emotional arc, and the feel rules (earned never given, slow is the point, the world talks back, instruments not menus, one more week).

*Why:* per direction - the old start skipped the entire first act. Players should spend real time building a foundation and feel every rung of the climb.


## Stale pending cards refresh on load

- A pending event persisted by an older build kept its baked-in labels and body, so the previous card still showed the pre-crisp copy. On load, the engine now refreshes a pending card's title, options, and body from the current deck, rebuilding personalized lawsuit and recall bodies from the stored subject with no RNG consumed.

*Why:* copy fixes must reach cards already dealt, not just future draws. The truncated buttons the user saw were the old card replaying from the save.


## Crisp event copy, counsel in white, no em dashes in content

- Every option label across the deck is now a crisp one-liner: an action plus at most one number ("Fix it now · −$80K", "Hold the line"). Consequences the labels dropped moved into card bodies.
- Lawsuit and recall bodies rewritten in short sentences, ending with a "Counsel:" advice paragraph that renders in white with a blank line above it, standing apart from the gray narrative.
- Purged em dashes from all player-facing content (event bodies, verdicts, warnings, trend copy) per standing rule; replaced with periods, commas, or middle dots.
- Added a flat hard-landing preview (pilot subject, full card in one snapshot) alongside the sheet-presented tea-spill regression pin; verified the render: centered title, avatar medallion with badge, white counsel line, one-liner keys.

*Why:* twice-given rules are now written into the working rules file - crisp one-liner buttons, no em dashes ever, counsel advice visually distinct.


## Event cards: one-liner keys, the accused on the card, the tea

- All 15 long option labels across the deck shortened to one-liners ("Settle quietly · −$180K", "Send them in · −$10K each") — the trade-off details moved into the card bodies, which now spell out settle-vs-court and comply-vs-defer in prose. Buttons are back to strict single lines.
- Incident cards now show the person: the accused crew member's portrait replaces the category icon as the card medallion, with the spilling-tea render breaking over the portrait's bottom-right corner on the tea card (other incident cards get a small category badge there). New `engine.staffMember(id:)` lookup; the regression preview exercises the full arrangement.

*Why:* per rule — buttons are one-liners, period; and the lawsuit lands harder when the face on trial is someone you hired.


## Event card: self-sizing, centered, truncation-proof

- The event card sheet now sizes to its content (the receipt pattern: measured height → .height detent, capped 720, scroll fallback) — long lawsuit bodies render in full instead of compressing to "…" in the fixed medium detent.
- Titles center-align when they wrap; body text is fixedSize-vertical; option keys wrap to two centered lines (GameButtonStyle gains a `lines` parameter) instead of truncating mid-sentence.
- Added a sheet-presented lawsuit-card preview as the regression pin.

*Why:* repeated feedback — text may never truncate in bodies or buttons, and a wrapped heading must center. The medium detent hid all three; sizing to content removes the class of bug.


## 52-week P&L pads left at zero

- The Money tab's P&L chart now left-pads missing weeks at ZERO (both the revenue line and profit bars) and pins its x-domain — the blue line runs the full width along $0 until real history begins, instead of starting mid-air with a phantom -60 gap.

*Why:* same honesty rule as the finance charts, but flows pad at zero (nothing was earned), not at the first value.


## Route markets & competition (GDD §21); fleet aging

- Every pair has a market: 0–4 deterministic rival carriers (big business pairs draw more), endpoint affluence, and your capture share — appeal built from comfort (weighted up on affluent pairs), price-for-market, and route satisfaction, against rivals. Monopoly pairs capture 100% regardless of comfort; contested pairs grow the pie +45%/rival, so strong products barely feel rivals while weak ones collapse.
- Route detail shows the market strip (Demand · Passengers · Rivals · Your share) with a warning when rivals are eating you, phrased for the crowd ("this crowd pays for comfort" vs "shops on price"); route-desk prospects show rival counts.
- Condition now decays with age (~3/year, floor 20): old airframes burn more fuel, cost more to maintain, wear faster, and fetch less — renewal becomes a real decision. Fleet list sorts worst wear first.

*Why:* a 10% LF on an uncomfortable plane was wrong in both directions — passengers should flee to competitors where they exist, and fill any seat where they don't.


## Manufacturer recall (GDD §20)

- New technical event: the maker recalls the model you operate most of (named with seller and count in the card). Comply — all airframes of the type grounded 2 weeks, $10K logistics each, retrofit freshens wear −15 — or negotiate a deferral: $25K fines per airframe, +12 wear each, −0.1 reputation, and you keep flying a defect into the compounding-fatigue/hull-loss system.
- Recall events carry the subject model on the GameEvent (save-compat), mirroring the lawsuit cards' subject member; both choices log to the event history and chart rules.

*Why:* the classic fleet crisis — and the deferral option is priced exactly against the airworthiness rules, so it's a real gamble, not a discount.


## Campaign-leak audit: milestones localized

- The flag-carrier milestone read "Connect 6 of India's cities" in every campaign. Milestone titles now support a {nation} placeholder resolved through `Country.adjective` ("Connect 6 American cities" in a US game), applied in both the Milestones card and the celebration banner.
- Swept the rest of the player-visible content for campaign leaks: the event deck, trends, and remaining copy are market-neutral; rivals, staff names, the aunt, the map camera, and the #1 line were already localized in earlier passes.

*Why:* per direction — campaign immersion breaks on a single wrong country name, and the placeholder mechanism means future geo-flavored milestones can't leak by construction.


## Route desk gets a close button

- The New route sheet now has the standard xmark close in its header, matching the formula sheet — no more swipe-only dismissal.

*Why:* every other sheet offers an explicit way out; a drawer without one reads as a trap.


## Lawsuit incidents (GDD §19)

- Two new PR cards name a real roster member: scalding tea spilled on a passenger (cabin crew, $180K claim) or a hard landing injuring an elderly passenger's spine (pilot, $300K). The card quotes the accused's stars and tenure.
- Settle quietly (pay in full, never makes the news) or fight in court: win odds run 20% + 12% per star + 15% per tenure year (max 90%) — cleared costs 15% in legal fees and gains +0.15 reputation; liable costs 1.5× the claim and −0.8 reputation, each narrated by an immediate verdict card and logged to the charts.

*Why:* hiring quality becomes a legal defense — veterans win trials, green hires are settlements waiting to happen.


## The aunt signs her letters

- Bundled Caveat (SIL OFL, credited) as the game's handwriting face, registered lazily at first use — no project-file changes, works in previews too. `Font.handwriting(size:)` is available for future handwritten touches.
- New `HandwrittenSignature` component: the aunt's name in her own hand, written on with a left-to-right ink reveal (1.3s). It signs the letter archive on the Money tab and the quarter report card — Aunt Margaret, Meera, or whoever your campaign's matriarch is.

*Why:* the letters are the game's one human relationship; a typed sign-off undercut them. A real hand — animated like ink following the nib — makes each quarter's letter feel touched.


## Stub line trimmed; key labels never overflow

- The boarding-pass stub's meta line is just "on-time 35%" — "projected" and the sat score are gone (satisfaction has its own meter one screen deeper).
- All metal-key labels (GameButtonStyle and the Fleet menu chips) scale down to 80% before clipping — long labels can no longer overflow their keys.

*Why:* the stub line carried three facts where one earns its place; and text escaping a machined key breaks the physical illusion faster than anything.


## Ops wear row: tag holds the tail code only

- The Ops conditions wear row's stamped tag now shows just the tail code (PA-C); the wear percentage joins the right-hand action text ("100% wear — ground it" / "84% wear · service soon").

*Why:* the tag wrapped to two lines carrying both facts; a dog tag holds a name.


## The aunt is local; Major events tightened

- The trust fund's voice matches the campaign: Aunt Meera (India), Margaret (US), Beatrice (UK), Mei (China), Maggie (Australia) — headers, signatures, and the quarter report card all follow, and her letters localize the flavor lines (grandfather's trade, the endearment, miles vs kilometers).
- Major events list: latest 8 entries, one strict line each — fixed mono date column (Y1 W07), single-line title, red/green sign dot on the right; MAJOR EVENTS eyebrow on the disclosure.

*Why:* an American campaign scolded in "beta" by Aunt Meera broke the fiction the same way the staff names did; and the events list needed the same grid discipline as the trend rows — a column for each fact, nothing wrapping.


## Industry rows aligned; wear escalates and surfaces in Ops

- Industry trend rows rebuilt on a strict grid: tag column, single-line name, and ONE mono readout per trend ("−12% aircraft · 37wk", green/red by favor); the story line runs full-width beneath instead of truncating mid-word. The NEXT rival line no longer wraps (name scales, readout holds).
- Aircraft worn past 80% now appear in the Dashboard's Ops conditions card: amber "VT-A · 84% wear · Service soon", turning loss-red "Hull-loss risk — ground it" past 90%.
- Wear is no longer linear: metal fatigue compounds (0.7× accumulation when fresh, ~1.6× near the line), so the last 20% arrives faster than the first — early servicing is now mechanically rewarded.

*Why:* the trend rows wrapped into four ragged lines per entry; wear risk deserved dashboard visibility since ignoring it is now lethal; and a linear wear clock made "run it to 89% then service" the optimal exploit — compounding fatigue punishes brinkmanship.


## Tray picker polish + fairness label trim

- Catering tiles get an 8pt gutter, full-width swatch plates, and tile-width short names (None / Sandwich / Fruit / Bento) — the full tray names were colliding edge-to-edge across the row.
- "Price fairness (feeds satisfaction)" is just "Price fairness" — the parenthetical wrapped the meter label to two lines.

*Why:* device pass — the row read as one run-on string of text; short names let the art carry the identity.


## Bento needs the oven too

- The Asian bento now shares the galley-oven requirement: +10 with ovens on every aircraft, −12 without (a cold premium main breaks a bigger promise than a cold sandwich). The fruit platter is now the only oven-agnostic tray, and the route-detail warning names the right dish.

*Why:* per direction — and it restores the triangle: without the oven rule, the bento was strictly best for anyone who could afford it.


## Tray picker matches the seat picker

- The route detail's catering control is now a swatch row like the cabin architect's seat tiers: the four options (None + three trays) sit side by side with the tray art as the swatch, teal fill + stroke on the selection, and the per-pax price under each. The compact menu is gone; the cold-sandwich warning stays.

*Why:* per request — one selection grammar for visual options everywhere; the art was hidden inside a menu nobody would open.


## The three trays (catering art + rebalance)

- Catering tiers are now the user's tray set with real art (Resources/Food): Sandwich box ($2/pax, +4 — but −8 served cold without galley ovens on every aircraft), Fruit platter ($5/pax, +6, oven-agnostic), Asian bento ($9/pax, +10, the premium tray). The route-detail menu shows the tray renders.
- The one-build-old snacks/hotMeals values decode into platter/bento, so no save breaks.

*Why:* the trays make the trade triangle physical — cheap-but-hardware, safe-but-delicate, premium-but-pricey — and the art sells the fantasy better than an SF fork ever could.


## Catering (GDD §18) + event rules on the charts

- Routes can now serve food: none / snacks ($2/pax, +3 satisfaction) / hot meals ($6/pax) from the route detail's economics card, charged on the cabin & catering line. Hot meals require a $40K galley oven on EVERY aircraft flying the route (Fleet → Service → "Fit galley oven"): with ovens +8 satisfaction, without −10 — cold meals dissuade passengers and reputation follows. The card warns which aircraft lack hardware. Food art slots are wired (Resources/Food/) with SF-symbol fallbacks until the assets arrive.
- Major events now draw as dashed red/green rules on the Finances chart (all three ranges, scaled to the bucket), and a "Major events" disclosure under the chart expands into the last 10 entries with dates. Fired cards and hull losses persist to a capped event log (save-compat).

*Why:* catering is a classic tycoon promise-vs-hardware trap; and the charts showed consequences without causes — the rules let you read "that cliff was the crash" at a glance.


## Airworthiness & hull loss (GDD §17); no decision without impact

- Flying an airframe past 90% wear now risks losing it: quadratic weekly probability (0.3% at 92%, 8% at 100%), seeded, max one per week. The Fleet card carries a quiet red airworthiness line instead of a popup — heed it or answer for it.
- A crash destroys the plane, kills passengers and named roster crew (the flight's pilot/cabin complement are removed from your pools), drops reputation 1.5 stars and all route satisfaction by 20, levies $200K/life in court settlements immediately, and lands an 8-week −20% "Safety scare" demand trend. A single-option reckoning card narrates the loss.
- The event deck's one consequence-free option (film shoot "Decline politely") now protects satisfaction (+2) — every decision has weight.

*Why:* wear was a cost curve without stakes — flying wrecks was viable. Real consequences make maintenance a decision, and the deliberately quiet warning keeps the player's agency: the game warns where an operator would look, once.


## Event pity timer (GDD §16)

- Event cards now arrive on a designed rhythm: 22% base weekly chance ramping +13% per event-free week (capped 85%), grace cut from 6 to 3 weeks. Expected cadence ~2–3 weeks; five-week droughts drop below 3%. Save-compat via optional anchor field; year-1's consecutive-negatives guard unchanged.

*Why:* per direction — this is a decision game as much as a simulation; a flat 16% coin flip produced six-week droughts where the player just watched numbers.


## Routes screen: home map + crafted layout

- The map opens on YOUR campaign's market: US games frame the continental US, India keeps the subcontinent (UK/China/Australia framings ready for v1.0). Focused route maps still frame their own pair.
- The screen now has the design system's section grammar: a NETWORK eyebrow over the map with live "N RTE · M APT" counts, the chrome "Plan a new route" key promoted to directly under the map instead of buried below every pass, and the pass list under its own BOARDING PASSES eyebrow — plus a quiet empty-state line for brand-new airlines.

*Why:* a US campaign opening on India broke the fantasy instantly; and the screen was an unlabeled stack — map, passes, and the primary action all floating at equal weight. Eyebrows give it the same sectioned, instrument-panel rhythm as the Dashboard.


## Contractor overflow (GDD §15)

- Staff overtime is capped at a practical +20% of roster capacity (paid at 1.5×); all demand beyond it is flown by contractors at market hourly × 1.8. Flights keep operating — understaffing now costs money instead of producing impossible workloads.
- Workload meter reports the employees' actual load (caps at 120%); a new `lastContractorShare` drives honest card copy: "Roster maxed out: contractors cover 62% of pilots hours at premium rates. Hire to bring it in-house."
- Happiness pressure follows the staff's own load; punctuality strain still follows total under-roster (contractors are unreliable). Save-compat via optional field.

*Why:* "your pilots are working 979% over roster" was a cartoon number that hid the real decision — hire or pay the premium.


## Country-flavored people and rivals

- Staff and applicant names now draw from the campaign country's pools: US (also UK/Australia for now) games generate names like Tyler Bennett and Madison Cooper; India keeps Rohan Iyer and Priya Sharma. Surnames are per-country too.
- The industry ladder is per-country: US campaigns climb past Keys Island Charters → Cactus Feeders → … → TransAmerican Airways → Pacific Crown ($12M–$18B, scaled to the richer US market); India keeps its Palm Air → Himalaya Air ladder.
- Dashboard's #1 line is market-neutral ("The market's largest carrier").
- Gender inference for avatar backfill uses the union of all name pools, so old saves stay correct.

*Why:* an American campaign staffed by Indian names against Himalaya Air broke the fantasy the moment you noticed; the world should speak the market's language.


## Fleet keys no longer clipped

- The Fleet action bank's horizontal scroller now reserves 12pt below (2pt above) the keys, so the extruded base lip and drop shadow render instead of being cut by the scroll bounds and trailing fade mask.

*Why:* device testing — the keys read as flat-bottomed slabs with their machined depth sheared off.


## Hiring sheet declutter

- Applicant cards restructured: avatar + name + single-line meta (stars · asking wage · patience window) on top, then the patience meter when relevant, then a full-width key row — obsidian "Negotiate" and bronze "Hire · $4.2K/wk" splitting the width evenly.

*Why:* device testing — five elements on one line squeezed the meta into a four-line sliver and truncated "Negotiate" to "Negot…"; stacking info over actions gives both room, and putting the asking wage on the Hire key makes the commitment legible at the point of tap.


## Map: unconnected airports fade back

- City dots without any route drop from 60% to 28% white (halo 45% → 22%); connected airports keep the full teal.

*Why:* with 26 US fields every dot at near-equal weight read as noise — dimming the unserved ones makes your actual network the figure and the rest the ground.


## Sim clock no longer covers bottom controls

- `GameScreen`'s scroll content now reserves 92pt of bottom clearance (was 24), so the last row of buttons on every tab can scroll fully above the floating sim clock pill.

*Why:* device testing — the pill overlaid the bottom-most keys (Fleet action bank, roster rows) with no way to reach them; scroll clearance is the standard floating-control fix and one change covers all screens.


## Lease copy + Orion rename

- Lease screen no longer says "Payments never end" (both the tab intro and the per-card caption) — the /wk price and the Return fee spec already carry the terms; intro now reads "Instant delivery, no capital outlay."
- Vayu Aeroworks is now Orion Aeroworks; the utility line is the Orion 205/208/210/212.

*Why:* per feedback — the "never ends" line read as a warning label on the game's recommended first purchase, and Orion carries more shine than Vayu while keeping the Cessna-style numbering. (Loyalty counts keyed to the old seller name lie dormant in existing saves; new Orion orders start their own ladder.)


## Globe map: device gesture + sync fixes

- Killed SceneKit's implicit 0.25s ease on camera changes (`SCNTransaction.animationDuration = 0` in the representable's apply): the Canvas overlay draws instantly, so the eased globe lagged behind it — dots and arcs visibly slid off the terrain during every pan on device.
- Pan and pinch are now ONE high-priority simultaneous gesture pair owned by the map. Previously pan sat on `.gesture` while pinch was high-priority: the page ScrollView won vertical drags, cancelling the pan mid-gesture (globe snapped back), and the split arbitration made pinches stutter.
- Pan speed now derives from the gesture-start zoom, so pinching mid-drag can't warp the pan rate.

*Why:* first real-device session — both problems are invisible in the simulator workflow (no fingers, screenshots between interactions) but made the map feel broken in the hand.


## Industry trends (GDD §14)

- New two-horizon trend system: one long economic regime is always in force (expansion/slowdown, oil supercycle, cheap credit, labor squeeze; 52–104 wk) plus up to two short shocks (fuel spike, travel rush, business surge, safety scare, pilot shortage, used-metal glut, order boom; 3–12 wk, ~10%/wk spawn). All seeded-RNG deterministic.
- Real economic teeth: trends multiply route demand, fuel price, the wage bill, and aircraft prices — new-order quotes move live, lease rates lock at signing, used listings bake the multiplier in at generation. They stack with event effects on the same levers.
- Dashboard card renamed "Industry standing" → "Industry" and now lists active trends: LONG/SHORT tag, name, story line, live lever effect (+12% demand, green/red by whether it favors you), and weeks remaining.
- `GameState.industryTrends` is optional for save-compat; old saves seed their first regime on the next settle.

*Why:* between events the economy was a flat line — every era felt identical. Regimes give the game macro weather worth planning around, shocks create tactical buy/shrink windows, and the card explains the forces instead of moving numbers silently.


## Roster row cleanup

- The staff roster row no longer wraps: the "On duty next wk" badge is gone — that fact now lives on the meta line ("$440/wk · on duty next wk", cornflower while pending); name and meta are both single-line; Fire is a quiet obsidian key instead of a red-tinted one.
- Added a "Roster rows" preview with the disclosure expanded so the row has a regression pin.

*Why:* three competitors for one row's width (two-line badge, wrapping meta, wide button) made every roster entry three lines tall; the joining status is information, not a state that needs a stamped tag.


## US map expansion, map pinch fix, the cabin-window moment

- 12 more US airports (Houston, Philadelphia, Detroit, Charlotte, Orlando, San Diego, Tampa, St. Louis, Portland, Nashville, Salt Lake City, New Orleans) — the US market now has 26 fields spanning both coasts, the Gulf, and the mountain west. Distances come from the existing haversine fallback.
- Map pinch-zoom promoted to a high-priority gesture so the enclosing ScrollView can't steal it, and the range widened (0.85×–12×) for a comfortable in/out sweep.
- New `WindowRevealView` (Resources/Art/window_welcome.png): founding a new airline now flies the camera through the cabin porthole — the window holds a beat, then zooms into the sky and fades into the fresh game.
- Grounded screen rebuilt around the same window: the last look out at sunset, the failure story, and the run's final ledger at the bottom as board tiles (Survived / Fleet / Routes / Rating) above the restart key.

*Why:* 14 airports made the US map feel emptier than India's 19; the pinch existed but lost the gesture race inside the scroll view. The window image bookends a run — you fly in through it at founding and look out of it when the banks call time — which gives the loop an emotional frame no stat card can.


## Realistic aircraft names, airline tail codes, nameplate

- Every airframe now carries a real-world-style designation from its maker: Vayu's utility line numbers like Cessna (Vayu 205/208/210/212), Northline's regionals name for seat count like ATR (NR-70…NR-120), Meridian's M-series tracks seats like the E-jets (M50…M260, widebodies M230/M300/M375), and Kestrel's KD/KJ lines are its Dash/CRJ-style competitors (KD-72…, KJ-80/90/265). Specs and photos unchanged — `makeSpec` just takes an explicit name.
- Tail codes now carry the airline's initials: "Blue Dart" registers BD-A, BD-B… (`GameEngine.fleetPrefix`; single-word names use their first two letters). New purchases use it, and a load-time retag re-registers auto-issued codes on existing saves.
- The hero board shows the carrier's nameplate: "✈︎ <AIRLINE>" engraved opposite the NET WORTH eyebrow.

*Why:* "5 Turboprop" read as a placeholder, not a product — maker-branded model numbers make the showroom feel like a real market with real rivalries; initialed registrations and the nameplate make the fleet and the board feel owned.


## Fleet action bank on bronze/obsidian

- The Fleet card's Route / Cabin / Service keys now use the same materials as the route card's action pair: bronze for the leading Route key, obsidian for Cabin and Service. The per-system anodized hues (blue/violet/amber) are gone; `menuChip` takes a `MetalFinish` directly.

*Why:* per request — one material grammar for action rows everywhere (bronze leads, obsidian supports) instead of a second color-coding system that only existed on this card.


## Flap row drops the currency cell

- The split-flap net-worth row no longer shows a $ cell — just sign, digits, and magnitude (− 4.74 M).

*Why:* the eyebrow label already names the metric and every other number on screen is dollars; one fewer cell keeps the board tighter.


## Stamped metal tags + plane glyph everywhere

- `StatusBadge` re-machined as a stamped silver tag: silver-gradient plate, punched wire hole on the leading edge, debossed mono lettering (dark strike, light catching the cut), and the semantic color as a thin anodized wash — replacing the hairline-outline chips. All badges (staff counts, LEASED, IN SHOP, IDLE, route tags) pick it up.
- Every remaining ⇄ between airport codes replaced with the ✈︎ text-presentation glyph (Fleet badges, route-detail titles, Money statement rows, showroom range notes, cabin warnings, cancel dialog) — it renders in any string context, matching the Dashboard's inline plane.

*Why:* outline chips were the last flat-ink element left on the machined surfaces; a punched dog-tag is the aviation-native form of a status label, and the wash keeps the color semantics without breaking the silver. The exchange arrows read as a currency swap, not a flight.


## Plane glyph in route P&L rows

- The Last Week card's per-route rows now show a small airplane between the airport codes (DEL ✈ BLR) instead of the ⇄ exchange arrows.

*Why:* the exchange glyph read as a currency/swap symbol, not a flight; the airplane matches the boarding-pass header's plane motif.


## Hero polish: no standing stroke, uniform tiles

- Removed the standing cornflower rim from the hero panel — the machined housing carries the hierarchy on its own; the rim still flashes profit-green on the weekly settle.
- `InstrumentWell` now fills its row height, so the Rating / Last wk / Fleet / Routes tiles machine to one consistent height.

*Why:* the accent stroke was a leftover from the flat-card era and fought the departure-board housing; unequal tile heights broke the single-strip read of the board row.


## Split-flap hero score

- Net worth now renders as a true split-flap row: one machined cell per character (28×44 gradient tile, hairline rim, the horizontal flap seam) with the glyph in lit 3D mono metal — red alloy when negative, silver when positive — and a numeric roll transition on change.
- `MetalPanel` gained the double housing: a second inner hairline frame machined into the face, like the border-in-border of a real departure board.
- Board-tile row pinned to equal heights.

*Why:* the plain 3D text still read as styled type on empty space; giving every character its own flap cell makes the hero an actual departure-board instrument — denser, more detailed, and it turns the weekly settle into a visible flap-roll moment.


## Anodized chart palette + hero restructure

- `Theme.chartPalette` replaced: the blue-ramp-into-grays made turbine pie slices indistinguishable. Now nine anodized-metal hues (steel blue, bronze, teal, violet, gold, copper rose, silver, slate, graphite) ordered so neighbors contrast; the blade root-to-tip shading keeps them metallic. Expense pie and industry share turbine both pick it up; ExpensePie slice indices are sequential now.
- Hero: net worth is extruded 3D metal type (stacked dark extrusion under a lit gradient face, red when negative) spanning the panel; reputation dropped into the four-tile board row as "3.5 ★ RATING", replacing the cash tile that duplicated the headline number.

*Why:* one chromatic family is right for strokes but wrong for categorical slices — an 80% leases week read as a gray disc; distinct anodized hues keep the machined look while making shares legible. The cash tile echoed net worth almost verbatim in normal play, so reputation earns the slot and the score line stands alone.


## Departure-board hero (dark console)

- Hero console re-darkened per feedback, restyled after a split-flap departure board: `MetalPanel` housing back to near-black with a faint sheen; `InstrumentWell` floors are black board tiles (the saturated anodized washes are dialed to a whisper and unused on the hero).
- Well values are now mono uppercase glyphs glowing in their semantic color (profit green / loss red / white) with a 1px flap seam across the characters — the board's type carries the color, not the tile.

*Why:* the bright brushed face + saturated wells washed out the score and fought the Blueprint near-black canvas; a departure board is the aviation-native reference for "dark steel, luminous type" and keeps the popping metallics reserved for the buttons.


## Machined hero console (MetalPanel v3.1.2)

- New panel-scale metal components in the design system: `MetalPanel` (raised brushed face with diagonal sheen, light-catching rim, extruded base — the one hero surface per screen), `InstrumentWell` (recessed cutout with inverted rim and an optional anodized tint floor), and `PanelGroove` (engraved divider line).
- Dashboard hero rebuilt on them: engraved mono labels (1px dark under-edge), net worth on the raised face, reputation in a gold-tinted well under the stars, and cash / last week / fleet / routes sunk into wells whose anodized floors carry the semantics (profit green / loss red / cornflower) with white values on top.
- Metal keys gained a subtle 0.97 pressed scale alongside the 2.5pt travel.

*Why:* the hero is the score and deserved the console treatment, not a flat card; per feedback the metals are bright and the wells saturated ("popping, not dull") — color lives in the anodized floors so values stay white-legible, keeping the one-accent rule for flat surfaces intact.


## Brighter gold-star asset

- Replaced `Resources/Icons/gold_star.png` with a new 1024px version — brighter, more saturated gold with cleaner facets. No code changes; every `StarRating` picks it up.

*Why:* the first star read bronze-brown at 12pt on the dark UI; the brighter gold keeps ratings legible at small sizes and separates the star iconography from the new bronze button keys.


## Bronze and obsidian metal keys

- `MetalFinish` enum (chrome / gunmetal / bronze / obsidian) now owns each key's face gradient, rim, base lip, and label ink; `MetalKeyModifier` and `GameButtonStyle` are built on it. `GameButtonStyle(finish:)` selects a material directly; the legacy `prominent:`/`tint:` API still works (chrome/gunmetal).
- Route boarding-pass stub: "Set up route" is now a bronze key (dark-bronze ink), "Cancel route" an obsidian black key — replacing the white chrome + red-tinted pair.
- Design-system doc and the "Metal keys" preview updated with the four finishes.

*Why:* per request for black-and-bronze buttons on the route card — bronze ties the commit action to the gold-star material family while obsidian recedes for the destructive exit; making finishes a first-class enum turns the pair into a reusable component instead of one-off colors.


## Gold-star rating asset

- `StarRating` now renders the metallic gold-star photo (`Resources/Icons/gold_star.png`) instead of SF Symbol stars, everywhere ratings appear: staff skill (People, Hiring, Negotiation) and reputation (Dashboard hero, quarter report).
- Fills are fractional, not stepped — the bright star is masked to the exact rating fraction over a desaturated 22%-opacity socket, so 3.4★ shows 40% of the fourth star.
- SF Symbol path kept as a fallback if the asset ever fails to load.

*Why:* the flat symbol stars were the last non-material iconography left after the v3.1.1 metal keys; a machined gold star matches the anodized-hardware direction, and the fractional mask makes small rating differences (2.2 vs 2.6) visible instead of rounding to the same half-star glyph.


## [Unreleased — design-system branch]

### 2026-07-19 — Anodized key tints; color-coded fleet action bank

**Changed**
- MetalKey gains an anodized tint: a colored wash over the gunmetal
  face (the white primary key stays plain metal). Quiet GameButtonStyle
  keys now anodize with their color — destructive keys read as
  red-anodized metal with white lettering.
- The fleet action bank is color-coded: Route in blue, Cabin in
  violet, Service in amber — one hue per system, same machined body.


### 2026-07-19 — Fleet menu chips join the key bank

**Fixed**
- The fleet card's Route/Service menu chips still wore the old flat
  tinted style beside the metal Cabin button. They now use the shared
  .metalKey surface (gunmetal face, cornflower icons), so the action
  row reads as one bank of console keys.


### 2026-07-19 — MetalKey extracted as a component; sizing bug fixed

**Fixed**
- Quiet metal keys stretched to full row width: the extruded base lip
  was a greedy RoundedRectangle sibling in a ZStack, which expanded
  every button. The lip is now a background of the key face, so keys
  size to their content again.

**Changed**
- The metal treatment lives in a reusable MetalKeyModifier
  (.metalKey(prominent:pressed:)) shared by GameButtonStyle and
  PillStepper, with a component preview covering both variants, the
  destructive label, and the stepper keys.


### 2026-07-19 — Buttons become machined metal keys

**Changed**
- GameButtonStyle rebuilt as physical console keys: gradient metal
  faces (brushed white primary, gunmetal secondary), a light-catching
  top rim, an extruded base lip, a drop shadow, and 2.5pt press-travel
  with the key visually sinking onto its base (scale-press retired).
  PillStepper's -/+ keys get the mini gunmetal treatment. Recorded in
  the design doc as Blueprint's one sanctioned exception to the
  zero-elevation rule — a console's buttons are physical.


### 2026-07-19 — Portraits displayed open, not cropped

**Changed**
- PersonAvatar no longer clips portraits into circles: the character
  busts render whole (caps and uniforms intact), sitting open on the
  surface. Only the monogram fallback keeps its quiet disc, since
  bare initials need a container.


### 2026-07-19 — Portraits backfilled into existing saves

**Fixed**
- Staff hired before the portrait feature showed monogram fallbacks
  forever (their records carry avatar = nil). GameEngine now backfills
  on load: gender inferred from the first-name pools, variant picked
  from a stable hash of the person's UUID — deterministic, no RNG
  stream consumed, same face on every load. Verified against a live
  pre-feature save in the simulator.


### 2026-07-19 — Staff portraits + showroom spec-sheet cards

**Added**
- 50 owner-provided staff portraits (Resources/StaffAvatars): pilots,
  cabin crew, ground & maintenance, and HQ (HR set), each in male and
  female variants. StaffMember and JobApplicant carry an avatar
  (optional — old saves fall back to a monogram), assigned at
  generation from the seeded RNG with gender-matched names (name
  pools split male/female, with some international additions for the
  US market). PersonAvatar component renders portraits on roster
  rows, hiring-sheet applicants, and the negotiation table.

**Changed**
- Showroom cards rebuilt as spec sheets: aircraft name + mono seller
  eyebrow + fit badge, photo hero, a four-column mono spec strip
  (seats / range / cruise-or-age / delivery), condition meter (used),
  then a price readout with sub-caption and a verb-only CTA — the
  numbers a buyer compares, not a sentence.


### 2026-07-18 — US market (new default) + three save slots

**Added**
- United States as the default founding country: 14 airports with
  real coordinates (majors class-3), haversine distances, and a new
  per-country demandLevel lever (US 1.5) so gravity demand scales to
  US metro sizes. Country picker on the founding screen is now truly
  selectable (US first/default, India second). Sanity-verified
  headless: right-sized US opener nets ~+150K/wk at LF 70%.
- Save system: 3 slots. GameSession owns the running engine; the
  Dashboard's Saved Games card opens a slots sheet with Load / New
  game / Delete (confirmed), active slot badged and autosaving
  weekly. Legacy saves migrate to slot 1.

**Changed**
- Route desk origin defaults to the country's first airport instead
  of hardcoded DEL; its demand ranking includes demandLevel so it
  matches the sim exactly.


### 2026-07-18 — Finances: W/M/Y ranges and a redesigned chart

**Added**
- Range picker on the Finances card (speed-segment style): Weekly =
  last 13 weeks, Monthly = 12 four-week buckets, Yearly = quarter
  buckets across the full 5-year history (level series keep each
  bucket's last value). Chart x-axis units follow (w / mo / q).

**Changed**
- The chart itself: heavy metric chips became quiet text tabs with a
  cornflower underline; a current-value + range-delta header answers
  "how much, which way" before any axis reading (▲/▼ percent, or ★
  for reputation); the plot gained a "now" marker dot, a thinner
  line, softer area fill, and mono tertiary axis labels.


### 2026-07-18 — Industry card: rank only, ladder strip removed

**Changed**
- The Industry Standing card shows just "#10" (no "of 10") and drops
  the 10-segment ladder strip — the rank number and the next-rival
  progress bar carry the story; the strip read as a stepper control.


### 2026-07-18 — Charts pinned to their data span

**Fixed**
- TrendChart and the load-factor sparkline now clamp the x-axis to
  exactly the (padded) data span via chartXScale. Swift Charts was
  rounding the axis outward (-51 → -60w), which reintroduced the gap
  and left-edge cliff the flat padding was meant to remove.


### 2026-07-18 — Finances card, honest chart windows, industry card redesign

**Changed**
- "Trends" is now "Finances" and sits above Industry Standing.
- TrendChart/LoadFactorSparkline take a fixed window (52/26 wk) and
  left-pad flat at the first value — no invented slope across weeks
  that never happened; young games read as a flat line into real data.
- Industry Standing redesigned: the rank is the hero (#10 large, "of
  10" beside), market cap and share as right-aligned instruments, a
  10-segment ladder strip with beaten rivals faintly lit and your
  position in cornflower, and a NEXT line with a progress bar toward
  the next rival's cap ("24% of $8.00M").


### 2026-07-18 — Speed control back to one tap

**Changed**
- The compact clock pill keeps the speed segments inline (pause/one/
  two/three chevrons — one tap, always reachable); the date + week
  strip block, marked with a chevron-up hint, is what expands into
  the time console (labeled day strip + Step wk). *Why:* speed is
  the most frequent action in the game; it can't cost two taps.


### 2026-07-18 — The time console: a crafted clock

**Changed**
- The sim clock pill is now a two-state instrument. Compact: play
  state, date, and a 7-segment week strip that fills day by day
  toward the settle (the heartbeat, shown instead of implied — today
  in cornflower). Tap to expand into the time console: mono date
  eyebrow, labeled M-S day strip, the speed control, and a new
  "Step wk" primary — advance exactly one game week and hold.

**Added**
- GameEngine.stepOneWeek(): pause + one advanceWeek, enabling the
  deliberate-play loop (adjust while paused → step → read results).
  Deterministic; same tick the clock drives. Disabled during clock
  holds.


### 2026-07-18 — "Blueprint" v3.1 replaces Warm Paper (Dovetail re-theme)

**Changed (everything visual, again)**
- Dark command center: ink #0A0A0A canvas, carbon cards, steel
  hairlines — surfaces stack by TONE with zero shadows and zero
  gradients. 8px radii everywhere (4px tags); pills retired.
- One chromatic accent: cornflower #6798FF on icons, active states,
  hero stroke, and data strokes — never button fills. Primary buttons
  are white-filled rects with ink text; secondary are graphite
  outlines; functional red/amber/green kept muted for P&L semantics.
- Type: SF with 600-capped headings and tight display tracking; MONO
  eyebrows/tags/codes with positive tracking (the instrument voice).
  Serif retired with the Warm Paper experiment.
- Charts stroke cornflower; expense turbine and industry bars use a
  blue-ramp palette. Aunt Meera's letters sit on ink insets with the
  serif italic kept for her voice only.


### 2026-07-18 — "Warm Paper" v3.0: the Steep re-theme

**Changed (everything visual)**
- Light editorial theme replaces the dark Flight Deck: paper-white
  canvas, flat mist cards (24pt, no shadow), hairline dividers;
  ink/slate/ash text; ONE chromatic accent — blush peach surfaces
  with sienna ink (hero card, Aunt Meera's letters, celebration
  banner, formula chips); muted functional green/red/amber retained
  for P&L semantics only; tab accents collapsed to ink.
- Serif regular (New York) is the headline voice everywhere —
  screen mastheads, sheet titles, boarding-pass airport codes; the
  sans caps at medium (500) centrally in Font.game. Values keep
  monospaced digits, not the full-mono readout.
- Buttons are pills: filled ink lozenge + ghost outline pair. Meters
  are quiet rounded tracks (graduations and needles retired). Charts
  stroke sienna; slices/bars use a warm-ramp editorial palette.
- Floating artifacts (the Steep exception that earns shadow): the
  satellite map, boarding passes, and the sim clock pill get white
  surfaces, hairline rings, and the soft 10% lift. The map keeps its
  own dark imagery palette.
- Verified by renders: Dashboard, Routes, Money, People, New Game.


### 2026-07-18 — Industry card opens the full market picture

**Added**
- Tapping the Dashboard's Industry Standing card opens an industry
  sheet: market share as the turbine pie (all ten carriers, player in
  the accent color, exact percentages in the legend) and the top-10
  market-cap ladder as ranked bars — log-scaled so the $8M end and
  the $9B end share one axis (noted on-screen; the mono figures are
  exact). The player row carries a "You" badge and the gradient bar.
  Chevron affordance added to the card; clock holds while the sheet
  is open.


### 2026-07-18 — Industry rank on the Dashboard

**Added**
- An "Industry standing" card: rank among nine fictional incumbents
  (Palm Air Charters $8M up to Himalaya Air $9B), market cap (net
  worth + 6x trailing-year profit, floored at zero), and market share
  (live-projected weekly pax vs industry traffic). Shows the next
  rival to overtake; a fresh airline starts #10 of 10 at ~1% share.
  All sim-side computed properties — deterministic, nothing stored.


### 2026-07-18 — Balance pass (audited by simulation) + difficulty select

**Fixed (the big one)**
- The economy was unwinnable: bot playtests (2 archetypes x 15 seeds,
  160 weeks) went bankrupt 30/30 because the opening play's cost floor
  equaled its PEAK revenue, and the seasonal trough bled -48K/wk.
  Tuned four constants: referenceFarePerKm 0.11→0.125, lease rate
  0.0018→0.0014/wk, maintenance seat-slope 250→180, demandK 520→550.
  Post-tune matrix: conservative play survives 15/15 and usually wins
  the trust fund (~6.5M net); fleet-planning expansion nets ~15.5M;
  mismatched fleets (big props on thin markets) still fail — the
  skill curve survived the tune.

**Added**
- Difficulty, chosen at founding: Relaxed (cash x1.25, demand x1.10,
  costs x0.90), Standard (the calibrated game, all x1.0), Tycoon
  (x0.75 / x0.93 / x1.10 — bots: passive play can't win the fund,
  smart expansion wins 5/10). Save-compatible (old saves = Standard);
  determinism untouched (Standard is the identity). Picker card on
  the new-game screen; three tests added. GDD amendment 11 has the
  full audit method and numbers.


### 2026-07-18 — Route desk, 11 new airports, Routes tab promoted

**Added**
- 11 airports join India: AMD, JAI, LKO, COK, NAG, TRV, GAU, BBI,
  IXC, plus class-1 strips SXR and VNS (turboprop territory) — 19
  total. Balance.distance gains a haversine fallback (coords x 1.06
  route factor) so new pairs never need hand-tabled distances; the
  calibrated legacy table still wins where it exists.
- The "Open new route" card is now a route desk: a full sheet with
  one-tap origin chips (slots shown) and every destination ranked by
  estimated weekly demand using the sim's own gravity formula, each
  row carrying distance, demand, and runway class — with Flying / No
  slots / Open states. Multiple routes can be opened in one visit.
  *Why:* two dropdowns hid the interesting decision; ranking markets
  IS the tycoon fantasy.

**Changed**
- Tab order: Dashboard, Routes, Fleet, People, Money (Routes before
  Fleet — the network is the game's second screen).


### 2026-07-18 — Satellite globe: 3D projection back, GPU-rendered

**Changed**
- The satellite map is a 3D globe again: Blue Marble textures a
  SceneKit sphere with an orthographic camera, and the route/city
  overlay draws in Canvas with matching orthographic math. The flat
  CPU-drawn version (same day) redrew a 5400px image per drag frame —
  janky and flat-looking; the GPU renders the textured sphere for
  free and only on change. The sphere uses custom explicit-UV
  geometry after SCNSphere's undocumented texture seam misaligned
  terrain by ~18 degrees (verified dot-on-city in the simulator:
  DEL/BOM/BLR sit on their real terrain). Rotation is built as
  quaternions (pitch after yaw) so SceneKit's euler order can't
  surprise. Drag rotates, pinch zooms, focus framing unchanged.


### 2026-07-18 — Satellite map replaces the vector globe

**Changed**
- The Routes map now drapes routes over NASA Blue Marble satellite
  imagery (public domain, 2.4MB bundled, fully offline — no tile
  servers, no keys), dimmed with a multiply scrim to sit in the ops
  theme. Flat equirectangular camera replaces the orthographic globe:
  drag pans, pinch zooms (1.2-12x), focus-framing on route detail
  unchanged. City dots gained halos for legibility on bright terrain.
  Natural Earth geojson + the globe renderer removed. *Why:* user
  direction (satellite overlay look); a flat projection makes real
  imagery drapeable in a single draw call, and at domestic zoom the
  globe's curvature was invisible anyway.


### 2026-07-18 — Pending starts visible on the collapsed roster row

**Changed**
- The roster disclosure label now reads "Roster (8) · 2 join next wk"
  in teal while hires are pending, so the start-week signal shows
  without expanding the dropdown (it already appeared on the pool
  header and inside the roster rows).


### 2026-07-18 — New hires say when they start

**Added**
- Roster members hired during the current (unsettled) week show an
  "On duty next wk" badge, and the pool header shows "+N joining"
  next to the staff count until their first week closes. *Why:* the
  immediacy rule's one staffing lag — a fresh hire only counts toward
  crew hours at the next settle — was invisible, so overwork warnings
  seemed to ignore the hire you just made.


### 2026-07-18 — The Immediacy Rule: changes act now, money settles weekly

**Changed**
- Live projections: boarding passes, the route detail's Economics
  card, and per-aircraft rows now show load factor and margin
  projected from CURRENT settings via the same computeEconomics the
  tick uses — touch a fare and the numbers move instantly. Captions
  say "projected"; settled truth stays on "Last week" surfaces.
- Posting a job ad now delivers its first applicant wave immediately
  (same seeded-RNG draw the weekly tick uses; determinism intact).
- Kept slow on purpose: deliveries (factory lead time), checks and
  refits (physical grounding), reputation/awareness drift (instant
  reputation would delete the recovery arc). Recorded as GDD §10.


### 2026-07-18 — Panel index numbers removed from card headers

**Changed**
- SectionHeader drops the two-digit panel index ("01", "02"...);
  headers keep the icon, label, and hairline rule. All 13 numbered
  call sites cleaned up. *Why:* user direction; the numbers read as
  serial-number noise rather than instrument labeling.


### 2026-07-18 — Receipt sheet sizes itself to the receipt

**Fixed**
- The acquisition receipt now measures its content and uses an exact
  .height presentation detent (+ home-indicator allowance) instead of
  .medium, so the whole receipt is visible with no cropping and no
  scrolling. The earlier scroll-anchor fix stopped the top clipping
  but still left the Done button below the fold at .medium; sizing
  the sheet to the content is the actual fix. ScrollView remains as
  a safety net when the receipt exceeds the screen (tiny devices,
  XXL type). Added a sheet-presented preview as the regression pin —
  the flat preview never exercised detents, which is how this
  survived two fixes.


### 2026-07-18 — Assign card always offers the showroom

**Changed**
- The route detail's Assign Aircraft card now ends with a route-aware
  showroom link in every state: a quiet "Buy more aircraft" when the
  fleet has candidates, the prominent "Get an aircraft for this route"
  when nothing fits (previously the link existed only in the
  nothing-fits case). *Why:* growing a route's capacity shouldn't
  require detouring via the Fleet tab.


### 2026-07-18 — Receipt sheet no longer crops at the top

**Fixed**
- The acquisition receipt's content is taller than the .medium sheet
  detent on smaller screens, and the overflow clipped at the TOP
  (cutting the signature disc in half). The receipt now lives in a
  top-anchored ScrollView (bounce only when content exceeds the
  detent) and the sheet can expand to .large. Nothing can crop; at
  worst it scrolls.


### 2026-07-18 — Cabin Architect polish pass

**Changed**
- Readouts consolidated into one instrument card on a single type
  scale: Seats/Refit/Upkeep tiles aligned, comfort as a full-width
  gauge (22/100 readout), effective-range row with the brochure figure
  right-aligned instead of a wrapping parenthetical.
- Controls grouped into one card with hairline sections: pitch/width
  rulers (aligned mono values), seat-tier swatches evenly distributed
  across the width, full-row galley stepper, wifi toggle with its
  service cost as a sublabel (moved out of the CTA block).
- Refit warning boxed in the standard warn treatment; close button
  machined (was still a circle); header breathing room. *Why:* the
  screen mixed three type scales and free-floating rows; the card
  rhythm every other screen uses was missing.


### 2026-07-18 — Game Feel v2.1 shipped: hierarchy borders, de-clutter, win moments

**Added**
- GameCard(highlight:): gradient hairline + tinted glow for the few
  surfaces that deserve attention; Theme.accentGradient; .fadeEdge()
  gradient-mask modifier; CelebrationBanner; QuarterReportCard.
- Milestone completions slide a celebration banner in from the top
  (auto-dismisses in 3.5s); quarter close presents a graded report
  card (grade from quarter profit + streak, clock held); deliveries
  animate into the fleet list and sales animate out; the Dashboard
  hero wears the one standing gradient border and blinks profit-green
  when a week settles. All diffed from existing state — no sim changes.

**Changed (de-clutter)**
- People: applicants moved out of pool cards into a per-role Hiring
  sheet ("Applicants waiting (N)" button); roster collapsed by default.
- Money: Aunt Meera's letters collapse to a one-line teaser + count;
  bank offers fold behind a disclosure; balance-sheet readouts scale
  down instead of wrapping ("$6.23 M" across two lines is gone —
  TickerText is now lineLimit(1) + minimumScaleFactor globally).
- Fleet: Sell/Return moved into the Service menu (with resale value
  shown on Sell), removing the always-on red button from every card;
  the action row fades at its trailing edge instead of cutting.

*Why:* the v2.1 plan (DESIGN_SYSTEM.md §2.6) — borders as hierarchy
not decoration, one clear thing per card, and the loop's wins made
visible without a single image asset or sim-layer change.


### 2026-07-18 — Fleet status line: tighter badge, full-width spread

**Changed**
- The fleet card's route badge drops the word "Flying" ("DEL ⇄ BOM"
  says it), and the status row distributes across the card: badge on
  the left, weekly lease cost pushed to the right edge.


### 2026-07-18 — Ticket punches finished; dropdown shows LF not condition

**Fixed**
- The boarding-pass punch notches showed a dark ring: the card's own
  drop shadow bled through the punched holes. Each punch is now capped
  with a screen-background disc, and the perforation dashes extend to
  meet the notches (padding 16→13). *Why:* the punch is the ticket's
  signature detail; a smudged hole reads as a rendering bug.

**Changed**
- Aircraft dropdown rows on the pass show the route's load factor
  instead of the plane's condition (condition stays on Fleet cards,
  where the maintenance decision lives).


### 2026-07-18 — Boarding-pass stub: full-width load factor

**Changed**
- The stub's load-factor gauge now spans the full ticket width, with
  on-time/satisfaction (left) and the weekly profit ticker (right) on
  their own row beneath; stub height 102→124 so the notch geometry
  keeps up. *Why:* user direction; the gauge is the pass's primary
  instrument and was squeezed to half width by the profit block.


### 2026-07-18 — Boarding passes list their active aircraft

**Added**
- Each route's boarding pass gains a collapsible "Aircraft on this
  route (N)" dropdown above the perforation, one row per assigned
  plane: registration, type, and condition (or an "In shop" badge
  while grounded). Hidden entirely on unstaffed routes. It sits in
  the flexible top section because the ticket stub is fixed-height
  (the punched notches depend on it). *Why:* seeing who actually
  flies a route previously required opening the detail screen.


### 2026-07-18 — Milestones move to the bottom of the Dashboard

**Changed**
- Dashboard order is now hero → trends → last week → milestones, with
  panel indices renumbered to match. *Why:* user direction; the live
  numbers are the daily read, the objective checklist is reference.


### 2026-07-18 — Globe coastlines no longer tear at the view edge

**Fixed**
- Land rings crossing the orthographic horizon tore into slivers
  (visible around the Black Sea when panning). Two causes: hidden
  vertices were dropped and each visible fragment force-closed,
  drawing closure lines across the map; and the -0.02 horizon
  overshoot let just-hidden points project folded back inside the
  disc. Land now projects whole rings with behind-horizon vertices
  clamped onto the horizon rim (the standard orthographic treatment),
  and fills even-odd so lake holes like the Caspian render as water.
  Verified with the camera parked on the Black Sea with the full
  horizon in frame.


### 2026-07-18 — Expense chart restyled as a turbofan face

**Changed**
- ExpensePie's ring is now 24 swept fan blades (root-to-tip shading,
  tip leading root) around a spinner hub inside a nacelle ring — an
  aircraft engine seen head-on, drawn entirely in Canvas geometry.
  Each blade takes the color of the expense category owning its
  angular slot, so proportion still reads from the chart while the
  legend keeps exact percentages. Added a component preview with
  sample slices as the visual regression pin. *Why:* user direction;
  it turns the one purely generic chart into the game's strongest
  Flight Deck moment without adding a single image asset.


### 2026-07-18 — "Flight Deck" v2.0: aerospace-mechanical design pass

**Changed** (see DESIGN_SYSTEM.md v2.0 for the full contract + plan)
- Typography split into two voices: labels/prose move from SF Rounded
  to plain SF (engineering grotesk); every sim value renders in SF
  Mono, enforced centrally by TickerText. *Why:* placard vs readout is
  the core aerospace convention, and enforcing mono in one component
  covers every live number without call-site discipline.
- Geometry machined: cards/sheets/clock pill 18pt→10pt, controls get a
  new 6pt token; capsules and circular buttons retired across the app.
- Instrument detailing, all drawn UI: MeterBar is now a rectangular
  gauge with 10% graduation cuts and a value needle; SectionHeader is
  a placard (mono panel index + label + hairline rule), numbered on
  Dashboard/Route detail/Money; the expense donut gained 12 radial
  graduation cuts. No images or gimmick graphics anywhere.


### 2026-07-18 — Expense-share donut on Dashboard and Money

**Added**
- ExpensePie (UI/Components): a Canvas donut of last week's cost
  share with a percent legend, fed by WeeklyReport.expenseSlices
  (eight themed categories, zero-cost ones dropped, biggest first).
  Shown on the Dashboard's Last Week card and atop the Money tab's
  weekly statement. *Why:* the statement lists exact amounts but
  never showed proportion — "is fuel or wages eating me" should be
  answerable at a glance, per the sim-explains-itself pillar.


### 2026-07-18 — Label-free network map; focused mini-map on route detail

**Changed**
- The Routes-tab globe no longer draws airport code labels; city dots
  and arcs carry the network view. *Why:* user direction; nine code
  chips over domestic India read as clutter at network zoom.
- Route detail now opens with a 200pt embedded map focused on that
  route: only its arc is drawn, only its two endpoint codes are
  labeled, and the camera auto-frames the pair (zoom derived from the
  cities' angular separation, nudged north so the arc bow fits).
  RouteMapView gained a focusRouteID parameter for this; nil keeps
  the full-network behavior.


### 2026-07-18 — Assigned planes can be tapped off a route

**Fixed**
- In the route detail's Assign Aircraft card, tapping a plane that is
  already on this route now unassigns it (engine.unassign existed;
  the row only ever called assign). *Why:* the checkmark rows read as
  toggles, but there was no way to pull a plane off a route from the
  UI at all — the sim supported it, the surface never exposed it.


### 2026-07-18 — Receipt icon no longer overflows its disc

**Fixed**
- The acquisition receipt's icon is now resizable + scaledToFit in a
  32pt box instead of font-sized at 28pt. *Why:* SF Symbols size by
  point/cap height, not bounding width; the "signature" glyph (lease
  receipts) is far wider than tall, so at 28pt it ran past the 64pt
  circle and looked cropped. The receipt preview now pins the leased
  kind, since signature is the widest-glyph stress case.


### 2026-07-18 — Route detail money card cut to three numbers

**Changed**
- The route detail's "Unit economics" card is now "Last week" with
  just Revenue, Cost, and Margin. Removed margin/flight, seats/wk,
  demand/wk, the breakeven load-factor meter, and the "Why these
  numbers?" formula sheet (plus its now-orphaned Explanation state).
  *Why:* user direction; the fare card above already carries the
  tuning levers, and six stats plus a meter buried the only question
  that matters at a glance — is this route making money.


### 2026-07-18 — Chevron speed control; whole sim clock 2x slower

**Changed**
- The speed control now reads pause / › / ›› / ››› instead of 1x/2x/4x
  text, switchable exactly as before (with an accessibility label per
  speed). *Why:* user direction; arrows read as speed at a glance
  without parsing numbers, matching tycoon-game convention.
- One week now takes 16 real seconds at base speed (was 8), halving
  every speed uniformly via the single secondsPerWeek constant. *Why:*
  weeks flew past too fast to react to route P&L between ticks.
- SimSpeed.label left the sim layer; glyph choice is UI-side now.


### 2026-07-18 — Unstaffed routes draw dashed on the globe

**Changed**
- Route arcs on the map now draw with a 6-6 dash when no aircraft is
  assigned; solid once a plane flies them (both glow and core strokes
  dash so they stay aligned). *Why:* flight-map convention reads
  dashed = planned, solid = operating; previously an idle route only
  differed by its neutral color, easy to miss at a glance.


### 2026-07-18 — Case-flattening root-caused: Hinglish keyboard, not the field

**Fixed**
- The "can't type capitals" bug was never the TextField: the dev
  simulator (India region) ships with English (India) + Hinglish
  (hi_Latn) + Hindi-transliteration keyboards, with multilingual
  prediction on. Hinglish is a caseless Latin QWERTY that looks
  identical to English and flattens typed capitals, and asciiCapable
  cannot exclude it. Removed the Hindi keyboards from the simulator
  (Settings-level, not app code) and restored .words autocapitalization
  now that the field's input is trustworthy. *Why:* two prior fixes
  tuned field flags to chase a keyboard-language problem; recording
  the real mechanism so it isn't re-chased on device reports.


### 2026-07-18 — Airline-name field never rewrites capitalization

**Fixed**
- Switched the name field from .words to .never autocapitalization.
  *Why:* word-mode auto-shift owns case at word boundaries and on some
  keyboards flattens mid-word capitals, so CamelCase brand names like
  "SkyTycoon" couldn't be typed. A brand-name field must reproduce
  keystrokes exactly; the player controls every capital via shift.


### 2026-07-18 — Founding CTA gets an accessible docked box

**Changed**
- The docked "Found the airline" button now sits in a solid elevated
  box with a hairline top edge, and its disabled state no longer dims
  the whole control to 40% opacity. Instead it renders at full opacity
  in neutral colors with a hint line ("Enter an airline name to take
  off."). *Why:* opacity-dimmed controls on a dark background fall
  below readable contrast, and a ghost button explains nothing; a
  full-contrast state plus a reason is legible to everyone.


### 2026-07-18 — Sticky founding CTA; hot-reload wiring for UI work

**Changed**
- "Found the airline" is now docked above the bottom safe area via
  safeAreaInset, with a fade so scroll content slips underneath. It
  also rides above the keyboard while naming the airline. *Why:* the
  CTA lived at the end of the scroll content, so on smaller screens
  you had to scroll past five countries to found the airline.

**Added**
- DEBUG-only InjectionIII hot reload: the app loads the injection
  bundle at launch (no-op if the InjectionIII mac app isn't running)
  and an InjectionReloader modifier re-renders the whole hierarchy on
  each injection. Sim state lives in GameEngine, so redraws lose
  nothing. Requires the free InjectionIII app; see commit message.
  *Why:* UI iteration currently costs a full rebuild + relaunch;
  injection turns a body tweak into a ~1s live swap in the simulator.


### 2026-07-18 — Airline-name field keeps the keyboard Latin-script

**Fixed**
- The airline-name field now requests an ASCII-capable keyboard
  (.keyboardType(.asciiCapable)), so devices with Hindi or other
  transliteration keyboards enabled no longer surface Devanagari
  suggestions while naming the airline. *Why:* the field accepted any
  system keyboard; on an India-configured device that meant Hindi
  predictive input in a field that expects a Latin brand name.


### 2026-07-18 — Word-caps airline names; em dashes swept from UI copy

**Fixed**
- The airline-name field now auto-capitalizes every word
  (.textInputAutocapitalization(.words)) and no longer autocorrects,
  so names like "Sky Bharat" type naturally. *Why:* the default
  sentence-casing keyboard only shifts the first word, which fought
  the most common airline-name shape (two capitalized words).

**Changed**
- Removed em dashes from every user-visible string (warnings, section
  headers, country blurbs, showroom copy, Aunt Meera's letters, event
  bodies), replacing each with a colon, comma, period, or the middot
  the design system already uses. *Why:* user direction; the copy now
  has one consistent separator style instead of three.


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
