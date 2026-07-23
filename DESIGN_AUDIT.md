# SkyTycoon — Subtraction Audit

*A legibility pass. Nothing is added here. Every note either removes an
element, merges two into one, or collapses the rare behind a tap. The goal
is that each screen answers one question at a glance, and the one number
that matters is the one your eye lands on first.*

## The three faults, everywhere

1. **The same fact is printed many times.** Profit appears in ~5 places
   (hero "last wk", the HQ Last-week card, the Money statement, the Finances
   chart, records). Debt in 3, net worth in 2, a route's load factor in 3–4,
   an aircraft's rating in 3, its status badge in 2. Repetition doesn't
   reassure; it makes the eye distrust that any one is *the* one.
2. **Everything is shouting.** Nearly every value is color-coded, half the
   rows carry an all-caps tracked eyebrow (NEEDS ATTENTION, IN FORCE,
   DECISION, RAISE CAPITAL, STRATEGIC APPROACH…), and several cards stack
   three or four bold "headline" elements. When everything is emphasized,
   nothing is.
3. **Chrome is doing no work.** Split-flap seams, panel grooves, ticket
   notches and perforation lines, the plane icon on a card that *is* a
   flight, chevrons on rows that are obviously tappable, a tinted disc behind
   an already-tinted icon. Beautiful once; noise by the fiftieth glance.

Fix those three and the app reads twice as clearly without losing a single
piece of information.

---

## Ranked by impact

### 1. Delete the HQ "Last week" card. *(highest)*
`DashboardView.lastWeekCard` re-states what the Money **Statement** already
owns — revenue, costs, profit, an expense pie, and per-route P&L — including
a *second* expense pie. Profit already lives in the hero and the Finances
chart. **Remove the card**; if HQ needs a closing beat, the hero's "last
week" well already carries it. One dense card and a duplicate pie gone,
zero information lost.

### 2. Collapse the Route Detail "Economics" card to its levers.
It is a five-layer wall: fare/frequency steppers, then Distance / proj. LF /
on-time, then Demand / rivals / share, then three prose warnings, then price
fairness, satisfaction, flight rating, catering — **30+ elements, 8
color-coded values fighting for the eye.** Keep visible only what you act
on: **fare, frequency, projected load factor, satisfaction.** Fold Demand /
rivals / share and the maturity/over-supply warnings behind a "Market"
disclosure. **Drop the Distance tile** (it's in the title `DEL ✈︎ BOM` and
on the map). This is the single biggest legibility win on any screen.

### 3. Strip the dead chrome. *(cheap, broad)*
- **Chevrons on tappable rows** — Your Desk alerts, first-flight steps,
  route rows. The whole row is the button; the chevron is noise. Remove.
- **Boarding pass:** drop the decorative `PerforationLine` and the airplane
  icon in the flight path (the card already *is* a flight). The punched
  ticket notches are the one flourish worth keeping — but only one flourish.
- **Ambient event:** remove the tinted circle behind the icon; the icon's
  own color is the signal.
- **Hero:** the split-flap seams/extrusions and `PanelGroove` can lose depth
  without losing the instrument feel.

### 4. One emphasis per card; one eyebrow style.
Pick a single headline element per card and let everything else go neutral
(`textSecondary`), colored **only** on true exception (loss, danger).
Today Route Detail color-codes eight values and Fleet three badge colors —
flatten them. And unify the eyebrows: NEEDS ATTENTION / IN FORCE / DECISION /
RAISE CAPITAL / STRATEGIC APPROACH / BOARDROOM are the same visual gesture
repeated; one quiet caption style, used sparingly, reads as calm structure
instead of a ransom note.

### 5. Give each metric exactly one home.
- **Profit:** the Money statement (detail) + the Finances chart (trend).
  Remove it from the HQ Last-week card (see #1); keep the hero well as the
  single glance.
- **Debt:** the Loans card owns it. Drop the Balance-sheet "Debt" tile and
  the dashed debt line on the Finances chart (or keep the line and drop the
  tile — just not both).
- **Net-worth trend:** the Finances chart already plots it as a metric.
  **Remove the duplicate chart on the Balance sheet** and compress its four
  tiles (Cash / Fleet / Debt / Net worth) into one quiet line.
- **Aircraft rating & status:** Fleet is the aircraft's home. In the Route
  Detail assign rows and boarding pass, the stars and the spec/status are a
  second rendering of the same thing — keep the name + the one fact that
  route context needs (can it fly this pair / is it in the shop), drop the
  rest.

### 6. Shorten the Fleet card.
Each card stacks a header, a large photo, two full meters, a red warning
box, a status line, and three equal-weight buttons — it runs a full screen
per aircraft. **Make the photo smaller (or a tap-to-view)**, set the two
meters compact and side-by-side (already are — tighten), and give the three
action keys a hierarchy (Route leads; Cabin/Service recede) instead of three
identical metal keys. The airworthiness warning should only turn loud past
the danger line; below it, a quiet dot.

### 7. Collapse the rare by default.
Show what's true now; hide what usually isn't. Fold the assign card's "free"
and "on other routes" aircraft behind disclosures (keep "on this route"
open); auto-collapse loan **Offers** to a count until tapped; on the Capital
card, don't reserve space for offer types that aren't currently on the table.

---

## The five-minute version

If only five things get done, do these — they carry ~80% of the gain:

1. **Remove the HQ Last-week card** (kills a whole duplicate + a second pie).
2. **Collapse Route Detail's market stats + warnings behind "Market"; drop
   Distance.**
3. **Remove chevrons and the boarding-pass perforation/plane-icon chrome.**
4. **Stop color-coding every value; one headline + one eyebrow style per card.**
5. **Delete the Balance-sheet net-worth chart and its debt tile** (both
   already shown elsewhere).

None of these removes information. Each removes a *copy* of information, a
decoration, or an emphasis — which is exactly what makes a dense tycoon UI
feel effortless instead of busy.
