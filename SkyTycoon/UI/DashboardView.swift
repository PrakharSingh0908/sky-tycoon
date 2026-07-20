//
//  DashboardView.swift
//  SkyTycoon — UI (sky accent)
//
//  Hero numbers, the trust-fund arc as an instrument, and the trends chart
//  (DESIGN_SYSTEM.md §4).
//

import SwiftUI

struct DashboardView: View {
    @Environment(GameEngine.self) private var engine
    @State private var trendMetric: TrendMetric = .cash
    @State private var financeRange: FinanceRange = .weekly
    @State private var settleFlash = false
    @State private var showingIndustry = false
    @State private var showingGazette = false
    @State private var eventsExpanded = false
    private let accent = Theme.sky

    enum TrendMetric: String, CaseIterable, Identifiable {
        // Cash leads: it is the number you spend from day to day.
        case cash = "Cash", netWorth = "Net worth", reputation = "Reputation"
        var id: String { rawValue }
    }

    /// Weekly = 13 week points; Monthly = 12 four-week buckets; Yearly =
    /// quarter buckets over the whole 5-year history. Buckets keep each
    /// period's LAST value (these are level series, not flows).
    enum FinanceRange: String, CaseIterable, Identifiable {
        case weekly = "W", monthly = "M", yearly = "Y"
        var id: String { rawValue }
    }

    var body: some View {
        GameScreen(title: "Dashboard", accent: accent) {
            heroCard
            // The founder's checklist rides just under the score, on the
            // same machined housing, until the airline flies.
            if !firstFlightDone { firstFlightCard }
            if engine.state.reputation < 2.0 { reputationCollapseBanner }
            if !engine.state.activeEffects.isEmpty || !wornAircraft.isEmpty {
                opsConditionsCard
            }
            trendsCard
            industryCard
            if let report = engine.latestReport { lastWeekCard(report) }
            milestonesCard
            savedGamesCard
        }
        // One-shot settle flash: the hero border blinks profit-green when a
        // week's numbers land, then eases back. Nothing moves while reading.
        .onChange(of: engine.latestReport?.id) { old, _ in
            guard old != nil else { return }   // skip initial appearance
            withAnimation(.snappy) { settleFlash = true }
        }
        .task(id: settleFlash) {
            guard settleFlash else { return }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.7)) { settleFlash = false }
        }
    }

    // ── First flight: the opening moves, right on the home screen ───────
    // A new founder shouldn't hunt through tabs to make their first
    // decision. Three steps, each a live action; the card retires itself
    // when the airline is actually flying.

    @State private var showingShowroom = false
    @State private var showingNewRoute = false
    @State private var showingFirstRoute = false

    private var hasAssignedRoute: Bool {
        engine.state.routes.contains { !$0.assignedAircraftIDs.isEmpty }
    }
    private var firstFlightDone: Bool {
        !engine.state.fleet.isEmpty && !engine.state.routes.isEmpty && hasAssignedRoute
    }

    private var firstFlightCard: some View {
        MetalPanel {
            SectionHeader(title: "First flight", icon: "checklist", accent: accent)
            Text("Three moves and \(engine.state.airlineName) is an airline.")
                .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                firstFlightRow(number: 1, isLast: false,
                               done: !engine.state.fleet.isEmpty,
                               title: "Lease your first aircraft",
                               detail: "No capital needed. A feeder flies day one.") {
                    showingShowroom = true
                }
                firstFlightRow(number: 2, isLast: false,
                               done: !engine.state.routes.isEmpty,
                               title: "Open your first route",
                               detail: "Pick a pair where the demand is.") {
                    showingNewRoute = true
                }
                firstFlightRow(number: 3, isLast: true,
                               done: hasAssignedRoute,
                               title: "Put the plane on the route",
                               detail: "Assign it and the week starts earning.") {
                    if engine.state.routes.first != nil {
                        showingFirstRoute = true
                    } else {
                        showingNewRoute = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingShowroom) {
            NavigationStack { ShowroomView(initialTab: .lease) }
        }
        .sheet(isPresented: $showingNewRoute) { NewRouteSheet() }
        .sheet(isPresented: $showingFirstRoute) {
            if let route = engine.state.routes.first {
                NavigationStack { RouteDetailView(routeID: route.id) }
            }
        }
    }

    /// A machined step disc: numbered gunmetal until done, then a
    /// checkmark on profit-tinted metal. Same material family as the keys.
    private func stepDisc(number: Int, done: Bool) -> some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: done
                    ? [Color(red: 0.40, green: 0.72, blue: 0.51),
                       Color(red: 0.17, green: 0.40, blue: 0.27)]
                    : [Color(white: 0.32), Color(white: 0.14)],
                startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(LinearGradient(
                colors: [.white.opacity(0.45), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom), lineWidth: 1)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(number)")
                    .font(.data(.caption, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
        .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
    }

    private func firstFlightRow(number: Int, isLast: Bool, done: Bool,
                                title: String, detail: String,
                                action: @escaping () -> Void) -> some View {
        Button {
            if !done { action() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Disc rides the TOP of the row; a hairline rail runs to
                // the next step, stepper-style.
                VStack(spacing: 3) {
                    stepDisc(number: number, done: done)
                    if !isLast {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.game(.subheadline, weight: done ? .regular : .semibold))
                        .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                        .strikethrough(done)
                    if !done {
                        Text(detail)
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, isLast ? 0 : 12)
                Spacer()
                if !done {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    // ── Reputation collapse: the soft-fail spiral warning (GDD §4.5) ────

    private var reputationCollapseBanner: some View {
        GameCard {
            Label("Reputation collapse: demand is cratering. Fix punctuality, comfort, and service before the spiral locks in.",
                  systemImage: "exclamationmark.octagon.fill")
                .font(.game(.caption, weight: .semibold))
                .foregroundStyle(Theme.loss)
        }
    }

    // ── Milestones (Layer 1): always know what to do next ───────────────

    private var milestonesCard: some View {
        let done = engine.state.completedMilestones
        let next = Balance.milestones.filter { !done.contains($0.id) }.prefix(3)
        let lastDone = Balance.milestones.last { done.contains($0.id) }
        return GameCard {
            HStack {
                SectionHeader(title: "Milestones", icon: "flag.checkered", accent: accent)
                Spacer()
                Text("\(done.count)/\(Balance.milestones.count)")
                    .font(.game(.caption, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            if let lastDone {
                milestoneRow(lastDone, done: true)
            }
            ForEach(Array(next)) { milestone in
                milestoneRow(milestone, done: false)
            }
            if next.isEmpty {
                Text("All milestones complete. The sandbox is yours.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func milestoneRow(_ milestone: MilestoneDef, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Theme.profit : Theme.textSecondary)
            Text(milestone.displayTitle(for: engine.state.country))
                .font(.game(.subheadline))
                .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                .strikethrough(done)
            Spacer()
            Text("+\(milestone.reward.money)")
                .font(.game(.caption, weight: .semibold))
                .foregroundStyle(done ? Theme.textSecondary : Theme.profit)
        }
    }

    // ── Ops conditions: timed event modifiers currently in force ────────

    /// Delivered airframes worn past 80% — an ops condition, not just a
    /// Fleet-card footnote (GDD §17).
    private var wornAircraft: [Aircraft] {
        engine.state.fleet
            .filter { $0.status != .onOrder && $0.wear >= 80 }
            .sorted { $0.wear > $1.wear }
    }

    private var opsConditionsCard: some View {
        GameCard {
            SectionHeader(title: "Ops conditions", icon: "exclamationmark.bubble.fill",
                          accent: Theme.warn)
            ForEach(engine.state.activeEffects) { effect in
                HStack {
                    StatusBadge(text: effect.label,
                                color: effect.multiplier > 1 && effect.kind == .demand
                                    || effect.multiplier < 1 && effect.kind == .fuelPrice
                                    ? Theme.profit : Theme.warn)
                    Spacer()
                    Text("\(effect.weeksRemaining) wk remaining")
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
            }
            ForEach(wornAircraft) { plane in
                let critical = plane.wear >= Balance.wearDangerThreshold
                HStack {
                    StatusBadge(text: plane.nickname,
                                color: critical ? Theme.loss : Theme.warn)
                    Spacer()
                    Text(critical ? "\(Int(plane.wear))% wear · ground it"
                                  : "\(Int(plane.wear))% wear · service soon")
                        .font(.game(.caption))
                        .foregroundStyle(critical ? Theme.loss : Theme.textSecondary)
                }
            }
        }
    }

    // ── Hero: the numbers that matter, always rolling ────────────────────
    // The one standing gradient border (v2.1: borders are hierarchy, and
    // the score IS the hierarchy). Flashes profit-green on weekly settle.

    // v3.1.2: the score lives on a machined MetalPanel — raised metal face,
    // engraved labels, and the supporting stats sunk into instrument wells.
    private var heroCard: some View {
        // No standing accent stroke — the machined housing carries the
        // hierarchy; only the weekly settle still flashes the rim green.
        MetalPanel(highlight: settleFlash ? Theme.profit : nil) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    engravedLabel("Net worth")
                    Spacer()
                    // The carrier's nameplate on its own board.
                    engravedLabel("✈︎ \(engine.state.airlineName)")
                }
                netWorthText
            }
            PanelGroove()
            HStack(alignment: .top, spacing: 8) {
                reputationTile
                if let report = engine.latestReport {
                    heroWell("Last wk",
                             (report.profit >= 0 ? "+" : "") + report.profit.money,
                             report.profit >= 0 ? Theme.profit : Theme.loss)
                }
                heroWell("Fleet", "\(engine.state.fleet.count)", Theme.textPrimary)
                heroWell("Routes", "\(engine.state.routes.count)", Theme.textPrimary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The score as a split-flap row: every character in its own machined
    /// flap cell — gradient tile, hairline rim, the horizontal seam — with
    /// the glyph in lit 3D metal (red alloy when negative, silver positive).
    private var netWorthText: some View {
        // No currency cell: the eyebrow already says what this is.
        let value = engine.netWorth.money.replacingOccurrences(of: "$", with: "")
        let negative = engine.netWorth < 0
        return HStack(spacing: 3) {
            ForEach(Array(value.enumerated()), id: \.offset) { _, ch in
                flapCell(String(ch), negative: negative)
            }
        }
        .animation(.snappy, value: value)
    }

    private func flapCell(_ glyph: String, negative: Bool) -> some View {
        let faceTop: Color = negative ? Color(red: 1.00, green: 0.68, blue: 0.62) : .white
        let faceBottom: Color = negative ? Color(red: 0.66, green: 0.27, blue: 0.23) : Color(white: 0.55)
        let cell = RoundedRectangle(cornerRadius: 5)
        return Text(glyph)
            .font(.system(size: 26, weight: .semibold, design: .monospaced))
            .foregroundStyle(LinearGradient(colors: [faceTop, faceBottom],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.55), radius: 0, y: 1.2)   // glyph extrusion
            .contentTransition(.numericText())
            .frame(width: 28, height: 44)
            .background(cell.fill(LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.06)],
                startPoint: .top, endPoint: .bottom)))
            .overlay {
                // The seam every split-flap character breaks on.
                Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1.5)
            }
            .overlay(cell.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.16), .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
    }

    /// Reputation's board tile: the numeral with a single gold star, in the
    /// row with its peers (the score line above stays net worth alone).
    private var reputationTile: some View {
        InstrumentWell {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    TickerText(text: String(format: "%.1f", engine.state.reputation),
                               font: .data(.subheadline, weight: .semibold),
                               color: Theme.textPrimary)
                        .overlay {
                            Rectangle().fill(Color.black.opacity(0.38)).frame(height: 1)
                        }
                    if let star = UIImage(named: "gold_star") {
                        Image(uiImage: star).resizable().scaledToFit()
                            .frame(height: 12)
                    }
                }
                engravedLabel("Rating")
            }
        }
    }

    /// Engraved console label: mono caps, cut into the metal (dark under-edge).
    private func engravedLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.data(.caption2)).tracking(0.85)
            .foregroundStyle(Color.white.opacity(0.55))
            .shadow(color: .black.opacity(0.8), radius: 0, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// A split-flap board tile: mono caps value glowing in its semantic
    /// color on the black floor, with the flap seam across the glyphs.
    private func heroWell(_ label: String, _ value: String, _ color: Color) -> some View {
        InstrumentWell {
            VStack(alignment: .leading, spacing: 3) {
                TickerText(text: value.uppercased(),
                           font: .data(.subheadline, weight: .semibold),
                           color: color)
                    .overlay {
                        // The horizontal seam every split-flap character has.
                        Rectangle().fill(Color.black.opacity(0.38)).frame(height: 1)
                    }
                engravedLabel(label)
            }
        }
    }

    // ── Saved games: the three slots, one tap away ───────────────────────

    @State private var showingSlots = false

    private var savedGamesCard: some View {
        Button {
            showingSlots = true
        } label: {
            GameCard {
                HStack {
                    Image(systemName: "tray.full")
                        .font(.subheadline).foregroundStyle(Theme.cornflower)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved games")
                            .font(.game(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Load, start new, or clear one of 3 slots")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSlots) { SaveSlotsView() }
    }

    // ── Industry standing: the ladder to climb (starts at the bottom) ────

    private var industryCard: some View {
        let (rank, _) = engine.industryRank
        let trends = engine.industryTrends.sorted {
            ($0.horizon == .long ? 0 : 1) < ($1.horizon == .long ? 0 : 1)
        }
        return GameCard {
            // The standing: taps through to the full ladder.
            Button { showingIndustry = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionHeader(title: "Industry", icon: "chart.bar.xaxis", accent: accent)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TickerText(text: "#\(rank)",
                                   font: .display(.largeTitle),
                                   color: rank <= 3 ? Theme.profit : Theme.textPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            TickerText(text: engine.marketCap.money,
                                       font: .game(.headline, weight: .semibold))
                            Text("Market cap")
                                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            TickerText(text: String(format: "%.1f%%", engine.marketShare * 100),
                                       font: .game(.headline, weight: .semibold))
                            Text("Share")
                                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.leading, 12)
                    }
                    if let next = engine.nextRival {
                        let progress = min(1, engine.marketCap / next.marketCap)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("NEXT · \(next.name.uppercased())")
                                    .font(.data(.caption2)).tracking(0.85)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Spacer(minLength: 8)
                                TickerText(text: "\(Int(progress * 100))% of \(next.marketCap.money)",
                                           font: .game(.caption2, weight: .medium),
                                           color: Theme.textSecondary)
                                    .fixedSize()
                            }
                            MeterBar(value: progress, color: Theme.cornflower, height: 4)
                        }
                    } else {
                        Text("The market's largest carrier. The sky is yours.")
                            .font(.game(.caption2, weight: .medium)).foregroundStyle(Theme.profit)
                    }
                }
            }
            .buttonStyle(.plain)

            // The market's weather (GDD §14) reads as a folded newspaper: a
            // concise clipping with the lead story; a tap opens the Gazette.
            if let lead = trends.first {
                Divider().overlay(Theme.hairline)
                Button { showingGazette = true } label: {
                    gazetteTeaser(lead: lead, count: trends.count)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingIndustry) { IndustrySheet() }
        .sheet(isPresented: $showingGazette) {
            IndustryGazetteView(trends: trends, dateline: engine.state.date.description,
                                country: engine.state.country)
        }
    }

    // A folded newspaper clipping: masthead, the lead headline, a one-line
    // standfirst, and the count — set on a small black-paper panel. The full
    // Gazette (flip through every story) is one tap away.
    private func gazetteTeaser(lead: IndustryTrend, count: Int) -> some View {
        let ink = Color(red: 0.93, green: 0.91, blue: 0.85)
        let inkSoft = Color(red: 0.68, green: 0.66, blue: 0.61)
        func rule() -> some View { Rectangle().fill(inkSoft.opacity(0.4)).frame(height: 1) }
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                rule()
                Text("THE SKYWARD GAZETTE")
                    .font(.system(size: 9, weight: .heavy, design: .serif))
                    .tracking(1.2).foregroundStyle(ink)
                    .fixedSize()
                rule()
            }
            Text(lead.name)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(lead.detail)
                .font(.system(size: 12, design: .serif)).italic()
                .foregroundStyle(inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            rule().padding(.top, 2)
            HStack {
                Text("\(count) \(count == 1 ? "story" : "stories") today")
                    .font(.system(size: 10, design: .serif)).italic()
                    .foregroundStyle(inkSoft)
                Spacer()
                HStack(spacing: 4) {
                    Text("Read the Gazette")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(ink)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.065))
                .overlay(RoundedRectangle(cornerRadius: Theme.corner)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    // ── Trends ───────────────────────────────────────────────────────────

    private var trendsCard: some View {
        GameCard {
            HStack {
                SectionHeader(title: "Finances", icon: "chart.xyaxis.line", accent: accent)
                rangePicker
            }
            // Quiet text tabs: the chart is the hero, not the switcher.
            HStack(spacing: 16) {
                ForEach(TrendMetric.allCases) { metric in
                    Button {
                        trendMetric = metric
                    } label: {
                        VStack(spacing: 4) {
                            Text(metric.rawValue)
                                .font(.game(.subheadline,
                                            weight: trendMetric == metric ? .medium : .regular))
                                .foregroundStyle(trendMetric == metric
                                                 ? Theme.textPrimary : Theme.textSecondary)
                            Capsule()
                                .fill(trendMetric == metric ? Theme.cornflower : .clear)
                                .frame(width: 16, height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .sensoryFeedback(.selection, trigger: trendMetric)

            // How much, which way — before any axis reading.
            let series = currentSeries
            if let first = series.first, let last = series.last {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TickerText(text: formatMetric(last),
                               font: .game(.title2, weight: .semibold))
                    if first != 0 || trendMetric == .reputation {
                        deltaBadge(first: first, last: last)
                    }
                    Spacer()
                }
            }
            let (window, unit) = rangeShape
            // The cash view carries a dashed debt line: liquidity against
            // what the bank is owed, on one instrument.
            let debtSeries = trendMetric == .cash
                ? rangeSeries(engine.state.debtHistory ?? []) : []
            TrendChart(values: series,
                       color: Theme.cornflower, window: window, unit: unit,
                       events: chartEventMarks,
                       secondary: debtSeries,
                       format: trendMetric == .reputation
                           ? { String(format: "%.1f★", $0) } : { $0.money })
            if trendMetric == .cash, !(engine.state.debtHistory ?? []).isEmpty {
                HStack(spacing: 12) {
                    legendChip(color: Theme.cornflower, text: "Cash", dashed: false)
                    legendChip(color: Theme.loss, text: "Debt", dashed: true)
                    Spacer()
                }
            }

            // The rules on the chart, expandable into the history book:
            // latest 8, one strict line each — date column, title, sign dot.
            if !(engine.state.eventLog ?? []).isEmpty {
                DisclosureGroup(isExpanded: $eventsExpanded) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach((engine.state.eventLog ?? []).suffix(8).reversed()) { entry in
                            HStack(spacing: 10) {
                                Text("Y\((entry.totalWeek - 1) / 52 + 1) W\(String(format: "%02d", (entry.totalWeek - 1) % 52 + 1))")
                                    .font(.data(.caption2)).tracking(0.85)
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 58, alignment: .leading)
                                Text(entry.title)
                                    .font(.game(.caption)).foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Circle()
                                    .fill(entry.isNegative ? Theme.loss : Theme.profit)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("MAJOR EVENTS")
                        .font(.data(.caption2)).tracking(0.85)
                        .foregroundStyle(Theme.textSecondary)
                }
                .tint(Theme.textSecondary)
            }
        }
    }

    /// A tiny line-sample legend: solid or dashed stroke plus its name.
    private func legendChip(color: Color, text: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(.clear)
                .frame(width: 16, height: 1)
                .overlay(Rectangle().stroke(color,
                    style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [3, 2] : [])))
            Text(text).font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
        }
    }

    /// Event weeks → the chart's x units for the active range (weekly
    /// points, 4-week months, 13-week quarters).
    private var chartEventMarks: [ChartEventMark] {
        let now = engine.state.date.totalWeeks
        let divisor: Double = switch financeRange {
        case .weekly: 1; case .monthly: 4; case .yearly: 13
        }
        return (engine.state.eventLog ?? []).map {
            ChartEventMark(id: $0.id,
                           offset: Double($0.totalWeek - now) / divisor,
                           negative: $0.isNegative)
        }
    }

    private var currentSeries: [Double] {
        switch trendMetric {
        case .netWorth: rangeSeries(engine.state.netWorthHistory)
        case .cash: rangeSeries(engine.state.cashHistory)
        case .reputation: rangeSeries(engine.state.reputationHistory)
        }
    }

    private func formatMetric(_ v: Double) -> String {
        trendMetric == .reputation ? String(format: "%.1f★", v) : v.money
    }

    /// Range delta: ▲/▼ with the change over the visible window.
    private func deltaBadge(first: Double, last: Double) -> some View {
        let delta = last - first
        let text: String
        if trendMetric == .reputation {
            text = String(format: "%@%.1f", delta >= 0 ? "▲" : "▼", abs(delta))
        } else if first != 0 {
            text = String(format: "%@%.0f%%", delta >= 0 ? "▲" : "▼",
                          abs(delta / abs(first)) * 100)
        } else {
            text = delta >= 0 ? "▲" : "▼"
        }
        return TickerText(text: text,
                          font: .game(.caption, weight: .medium),
                          color: delta >= 0 ? Theme.profit : Theme.loss)
    }

    /// W / M / Y — mono tags, white-filled when active (speed-segment style).
    private var rangePicker: some View {
        HStack(spacing: 2) {
            ForEach(FinanceRange.allCases) { range in
                Button {
                    financeRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.data(.caption2, weight: .medium))
                        .frame(width: 24, height: 20)
                        .background(financeRange == range ? AnyShapeStyle(Color.white)
                                    : AnyShapeStyle(.clear),
                                    in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(financeRange == range ? Theme.bg : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.corner))
        .sensoryFeedback(.selection, trigger: financeRange)
    }

    private var rangeShape: (window: Int, unit: String) {
        switch financeRange {
        case .weekly: (13, "w")
        case .monthly: (12, "mo")
        case .yearly: (20, "q")
        }
    }

    /// Downsample a weekly level series into the selected range's buckets
    /// (last value per bucket, aligned to now).
    private func rangeSeries(_ raw: [Double]) -> [Double] {
        switch financeRange {
        case .weekly:
            return Array(raw.suffix(13))
        case .monthly:
            return bucketLast(raw, size: 4, keep: 12)
        case .yearly:
            return bucketLast(raw, size: 13, keep: 20)
        }
    }

    private func bucketLast(_ raw: [Double], size: Int, keep: Int) -> [Double] {
        var out: [Double] = []
        var i = raw.count
        while i > 0 && out.count < keep {
            out.append(raw[i - 1])
            i -= size
        }
        return out.reversed()
    }

    // ── Last week ────────────────────────────────────────────────────────

    private func lastWeekCard(_ report: WeeklyReport) -> some View {
        GameCard {
            SectionHeader(title: "Last week · \(report.date.description)",
                          icon: "clock.arrow.circlepath", accent: accent)
            HStack(spacing: 20) {
                StatTile(label: "Revenue", value: report.revenue.money)
                StatTile(label: "Costs", value: (report.profit - report.revenue).money,
                         color: Theme.textSecondary)
                StatTile(label: "Profit", value: report.profit.money,
                         color: report.profit >= 0 ? Theme.profit : Theme.loss)
            }
            // Where the money went.
            let slices = report.expenseSlices
            if !slices.isEmpty {
                Divider().overlay(Theme.hairline)
                ExpensePie(slices: slices)
            }
            // Per-route P&L (route margin: revenue − fuel), best first.
            if !engine.state.routes.isEmpty {
                Divider().overlay(Theme.hairline)
                ForEach(engine.state.routes.sorted { $0.lastWeeklyProfit > $1.lastWeeklyProfit }) { route in
                    HStack {
                        (Text(route.originID)
                            + Text("  \(Image(systemName: "airplane"))  ")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                            + Text(route.destinationID))
                            .font(.game(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("LF \(Int(route.lastLoadFactor * 100))%")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TickerText(text: route.lastWeeklyProfit.money + "/wk",
                                   font: .game(.subheadline, weight: .semibold),
                                   color: route.lastWeeklyProfit >= 0 ? Theme.profit : Theme.loss)
                    }
                }
            }
        }
    }
}

// ── The industry, in full: share pie + cap ladder ─────────────────────────

private struct IndustrySheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    private let accent = Theme.sky
    /// Rival slice/bar palette; the player is always Theme.sky.
    private let palette: [Color] = Theme.chartPalette

    private struct Carrier: Identifiable {
        let name: String
        let cap: Double
        let pax: Double
        let isPlayer: Bool
        var id: String { name }
    }

    private var carriers: [Carrier] {
        var all = Balance.rivals(for: engine.state.country).map {
            Carrier(name: $0.name, cap: $0.marketCap, pax: $0.weeklyPax, isPlayer: false)
        }
        all.append(Carrier(name: engine.state.airlineName.isEmpty ? "You"
                                : engine.state.airlineName,
                           cap: engine.marketCap, pax: engine.weeklyPax, isPlayer: true))
        return all.sorted { $0.cap > $1.cap }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("The industry")
                    .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                    .padding(.top, 20)

                SectionHeader(title: "Market share · weekly passengers",
                              icon: "chart.pie.fill", accent: accent)
                ExpensePie(slices: shareSlices)

                Divider().overlay(Theme.hairline)

                SectionHeader(title: "The ladder · \(carriers.count) carriers",
                              icon: "chart.bar.xaxis", accent: accent)
                Text("The top of the table, and the fight you are in. Bars are log-scaled; the numbers are exact.")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                VStack(spacing: 8) {
                    ForEach(ladderRows, id: \.id) { row in
                        switch row {
                        case .carrier(let rank, let carrier):
                            capRow(rank: rank, carrier)
                        case .gap(let hidden):
                            Text("· · · \(hidden) carriers · · ·")
                                .font(.data(.caption2)).tracking(0.85)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Button("Done") { dismiss() }
                    .buttonStyle(GameButtonStyle(color: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.bgElevated)
        .presentationDetents([.large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
    }

    /// A 69-carrier pie is noise: the majors get slices, the long tail
    /// becomes one graphite bucket, and you are always cornflower.
    private var shareSlices: [ExpenseSlice] {
        let majors = carriers.filter { !$0.isPlayer }.prefix(6)
        let player = carriers.first { $0.isPlayer }
        let restPax = carriers.filter { !$0.isPlayer }.dropFirst(6)
            .map(\.pax).reduce(0, +)
        var slices: [ExpenseSlice] = []
        for (i, carrier) in majors.enumerated() {
            slices.append(ExpenseSlice(label: carrier.name, amount: carrier.pax,
                                       color: palette[i % palette.count]))
        }
        if restPax > 0 {
            slices.append(ExpenseSlice(label: "Everyone else", amount: restPax,
                                       color: Color(white: 0.38)))
        }
        if let player {
            slices.append(ExpenseSlice(label: player.name,
                                       amount: max(player.pax, 1), color: accent))
        }
        return slices
    }

    /// Top 3 of the table, an ellipsis for the gap, then your fight:
    /// three above you, you, three below.
    private enum LadderRow: Identifiable {
        case carrier(rank: Int, Carrier)
        case gap(hidden: Int)
        var id: String {
            switch self {
            case .carrier(_, let c): c.id
            case .gap(let n): "gap-\(n)"
            }
        }
    }

    private var ladderRows: [LadderRow] {
        let all = carriers
        guard let playerIndex = all.firstIndex(where: { $0.isPlayer }) else {
            return all.prefix(10).enumerated().map { .carrier(rank: $0 + 1, $1) }
        }
        let topEnd = 3
        let windowStart = max(playerIndex - 3, 0)
        let windowEnd = min(playerIndex + 3, all.count - 1)
        var rows: [LadderRow] = []
        if windowStart <= topEnd {
            // The window reaches the top: one continuous run.
            for i in 0...windowEnd { rows.append(.carrier(rank: i + 1, all[i])) }
        } else {
            for i in 0..<topEnd { rows.append(.carrier(rank: i + 1, all[i])) }
            rows.append(.gap(hidden: windowStart - topEnd))
            for i in windowStart...windowEnd { rows.append(.carrier(rank: i + 1, all[i])) }
        }
        return rows
    }

    private func capRow(rank: Int, _ carrier: Carrier) -> some View {
        // Log scale: $8M and $9B on one axis without erasing the small end.
        let maxCap = carriers.first?.cap ?? 1
        let floorLog = 6.0   // $1M
        let span = max(log10(maxCap) - floorLog, 0.1)
        let fraction = max(0.04, (log10(max(carrier.cap, 1_500_000)) - floorLog) / span)
        return HStack(spacing: 8) {
            Text("#\(rank)")
                .font(.data(.caption2, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(carrier.name)
                        .font(.game(.caption, weight: carrier.isPlayer ? .bold : .semibold))
                        .foregroundStyle(carrier.isPlayer ? accent : Theme.textPrimary)
                    if carrier.isPlayer {
                        StatusBadge(text: "You", color: accent)
                    }
                    Spacer()
                    TickerText(text: carrier.cap.money,
                               font: .game(.caption2, weight: .bold),
                               color: Theme.textSecondary)
                }
                GeometryReader { geo in
                    Capsule()
                        .fill(carrier.isPlayer
                              ? AnyShapeStyle(Theme.cornflower)
                              : AnyShapeStyle(Color.white.opacity(0.14)))
                        .frame(width: geo.size.width * fraction)
                }
                .frame(height: 6)
            }
        }
    }
}

// ── The Industry Gazette (v3.1.5) ────────────────────────────────────────
// The market's weather, set as a newspaper: black newsprint, serif type, a
// masthead, and one article per active trend that the reader flips through.

/// Black paper: an ink-dark sheet with a deterministic grain and a vignette,
/// so the newsprint feels pressed rather than flat.
private struct NewspaperBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.055)
            Canvas { ctx, size in
                let cols = 64, rows = 130
                for r in 0..<rows {
                    for c in 0..<cols {
                        // Sin-hash noise: stable across redraws, no RNG.
                        let h = sin(Double(c) * 12.9898 + Double(r) * 78.233) * 43758.5453
                        let n = h - h.rounded(.down)
                        guard n > 0.85 else { continue }
                        let x = size.width * Double(c) / Double(cols)
                        let y = size.height * Double(r) / Double(rows)
                        let op = (n - 0.85) / 0.15 * 0.055
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)),
                                 with: .color(.white.opacity(op)))
                    }
                }
            }
            RadialGradient(colors: [.clear, .black.opacity(0.5)],
                           center: .center, startRadius: 140, endRadius: 540)
        }
        .ignoresSafeArea()
    }
}

private struct IndustryGazetteView: View {
    @Environment(\.dismiss) private var dismiss
    let trends: [IndustryTrend]
    let dateline: String
    let country: Country
    @State private var page = 0

    // Warm newsprint ink on black paper.
    private static let ink = Color(red: 0.93, green: 0.91, blue: 0.85)
    private static let inkSoft = Color(red: 0.70, green: 0.68, blue: 0.63)

    var body: some View {
        ZStack {
            NewspaperBackground()
            TabView(selection: $page) {
                ForEach(Array(trends.enumerated()), id: \.element.id) { index, trend in
                    ScrollView(showsIndicators: false) {
                        GazetteArticle(trend: trend, dateline: dateline, country: country,
                                       ink: Self.ink, inkSoft: Self.inkSoft)
                            .padding(.horizontal, 26)
                            .padding(.top, 60)
                            .padding(.bottom, 96)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)

            // The fold furniture: close, and a page-turn footer.
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Self.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.06), in: Circle())
                            .overlay(Circle().strokeBorder(Self.inkSoft.opacity(0.3), lineWidth: 1))
                    }
                }
                Spacer()
                if trends.count > 1 { pageTurner }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .presentationDetents([.large])
        .presentationBackground(Color(red: 0.05, green: 0.05, blue: 0.055))
        .preferredColorScheme(.dark)
        .holdsSimClock()
    }

    /// A hairline-ruled page turner: ‹ PAGE i OF n › — the newspaper's foot.
    private var pageTurner: some View {
        HStack(spacing: 14) {
            turnButton("chevron.left", enabled: page > 0) {
                page = max(0, page - 1)
            }
            VStack(spacing: 3) {
                Rectangle().fill(Self.inkSoft.opacity(0.4)).frame(height: 1)
                Text("PAGE \(page + 1) OF \(trends.count)")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1.5).foregroundStyle(Self.inkSoft)
                Rectangle().fill(Self.inkSoft.opacity(0.4)).frame(height: 1)
            }
            .frame(width: 130)
            turnButton("chevron.right", enabled: page < trends.count - 1) {
                page = min(trends.count - 1, page + 1)
            }
        }
    }

    private func turnButton(_ symbol: String, enabled: Bool, _ act: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { act() } } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Self.ink)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.05), in: Circle())
                .overlay(Circle().strokeBorder(Self.inkSoft.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.25)
        .disabled(!enabled)
    }
}

/// One trend, set as a front-page story: masthead, kicker, headline, an
/// italic standfirst, drop-capped body, and a ruled pull-stat.
private struct GazetteArticle: View {
    let trend: IndustryTrend
    let dateline: String
    let country: Country
    let ink: Color
    let inkSoft: Color

    private var pct: Int { Int(((trend.multiplier - 1) * 100).rounded()) }
    private var kicker: String { trend.horizon == .long ? "LONG-RANGE FORECAST" : "MARKET BULLETIN" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Text(kicker)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .tracking(2).foregroundStyle(inkSoft)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 18)
            Text(trend.name)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            Text(trend.detail)
                .font(.system(size: 15, design: .serif)).italic()
                .foregroundStyle(inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            rule.padding(.vertical, 16)
            bodyColumns
            pullStat.padding(.top, 20)
            Text("— The Skyward Gazette · \(country.displayName) Desk")
                .font(.system(size: 12, design: .serif)).italic()
                .foregroundStyle(inkSoft)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 22)
        }
    }

    private var masthead: some View {
        VStack(spacing: 5) {
            doubleRule
            Text("THE SKYWARD GAZETTE")
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .tracking(1).foregroundStyle(ink)
                .minimumScaleFactor(0.7).lineLimit(1)
            HStack {
                Text("\(country.displayName.uppercased()) EDITION")
                Spacer()
                Text(dateline)
            }
            .font(.system(size: 10, weight: .medium, design: .serif))
            .tracking(1).foregroundStyle(inkSoft)
            doubleRule
        }
    }

    /// Body prose composed from the trend's own facts — deterministic, no sim.
    private var bodyColumns: some View {
        let dir = pct >= 0 ? "climbed" : "eased"
        let lever = trend.kind.label
        let first = "\(country.adjective) carriers woke to a market that has \(dir) \(abs(pct)) percent on \(lever). "
            + (trend.favorsPlayer
               ? "For operators with a steady hand, the winds are fair — and the well-run stand to gain while the timid hesitate."
               : "It is a squeeze felt across every route map, and the margin between prudence and loss has rarely been thinner.")
        let second = trend.horizon == .long
            ? "Analysts describe a regime rather than a ripple, one expected to hold for the better part of \(trend.weeksRemaining) weeks before the cycle turns again."
            : "The bulletin should pass inside \(trend.weeksRemaining) weeks, though seasoned hands know better than to wager on the timing of a market's moods."
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(String(first.prefix(1)))
                    .font(.system(size: 52, weight: .heavy, design: .serif))
                    .foregroundStyle(ink)
                    .padding(.top, -8)
                Text(String(first.dropFirst()))
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(ink.opacity(0.92))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(second)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(ink.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pullStat: some View {
        let tint = trend.favorsPlayer ? Theme.profit : Theme.loss
        return VStack(spacing: 6) {
            rule
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(trend.kind.label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .tracking(1.5).foregroundStyle(inkSoft)
                Spacer()
                Text("\(pct >= 0 ? "+" : "")\(pct)%")
                    .font(.system(size: 30, weight: .heavy, design: .serif))
                    .foregroundStyle(tint)
                Text("for \(trend.weeksRemaining) wk")
                    .font(.system(size: 12, design: .serif)).italic()
                    .foregroundStyle(inkSoft)
            }
            rule
        }
    }

    private var rule: some View { Rectangle().fill(inkSoft.opacity(0.45)).frame(height: 1) }
    private var doubleRule: some View {
        VStack(spacing: 2) {
            Rectangle().fill(ink.opacity(0.8)).frame(height: 2)
            Rectangle().fill(ink.opacity(0.8)).frame(height: 1)
        }
    }
}

#Preview("Foundation start") {
    DashboardView()
        .environment(GameEngine.newGame(airlineName: "Foundation Air",
                                        country: .us, seed: 7))
        .preferredColorScheme(.dark)
}

#Preview("Industry gazette") {
    let engine = GameEngine.previewGame()
    return IndustryGazetteView(
        trends: engine.industryTrends.isEmpty
            ? [IndustryTrend(id: UUID(), key: "slump", name: "Economic Slowdown",
                             detail: "Belt-tightening: discretionary travel dries up first.",
                             kind: .demand, horizon: .long, multiplier: 0.92, weeksRemaining: 89)]
            : engine.industryTrends,
        dateline: engine.state.date.description, country: .us)
        .environment(engine)
        .preferredColorScheme(.dark)
}

#Preview {
    DashboardView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

#Preview("Industry sheet") {
    IndustrySheet()
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

// §22 regression pin: a brand-new airline shows the $200K seed and a
// bottom-of-ladder rank, not a leg up.
