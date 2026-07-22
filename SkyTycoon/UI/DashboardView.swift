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
    @State private var gazettePage = 0
    @State private var eventsExpanded = false
    /// The hero's supporting stats (rating, last week, fleet, routes) collapse
    /// behind a disclosure so the score leads.
    @State private var heroStatsExpanded = false
    /// A route the player tapped to open from the attention card (GDD §26).
    @State private var routeRef: RouteRef?
    /// Jump to the Fleet tab (worn-aircraft rows are tappable — service them).
    var onOpenFleet: () -> Void = {}

    private struct RouteRef: Identifiable { let id: UUID }
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
        GameScreen(title: "HQ", accent: accent,
                   trailing: AnyView(profileButton)) {
            heroCard
            // An ambient event (GDD §25) sits here as a quiet decision —
            // time keeps running, and it unfolds on its own if ignored.
            if let ambient = engine.ambientEvent { ambientEventCard(ambient) }
            // The founder's checklist rides just under the score, on the
            // same machined housing, until the airline flies.
            if !firstFlightDone { firstFlightCard }
            if engine.state.reputation < 2.0 { reputationCollapseBanner }
            // Finances leads the board, above the ops desk.
            trendsCard
            // Your Desk (§34): news, eroding routes (§26), timed effects,
            // and the fleet that needs a look — the whole ops board in one.
            if hqHasContent { headquartersCard }
            industryCard
            // Marketing lives at HQ now (§34) — an ongoing brand decision.
            marketingCard
            if let report = engine.latestReport { lastWeekCard(report) }
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
        .sheet(item: $routeRef) { ref in
            NavigationStack { RouteDetailView(routeID: ref.id) }
        }
    }

    // ── Routes need attention: defend what you built (GDD §26) — rows
    // embedded in the Head Quarter card.

    @ViewBuilder private var routeAttentionRows: some View {
        ForEach(engine.routesNeedingAttention) { alert in
            Button {
                routeRef = RouteRef(id: alert.id)
            } label: {
                HStack {
                    StatusBadge(text: alert.title,
                                color: alert.critical ? Theme.loss : Theme.warn)
                    Spacer()
                    Text(alert.reason)
                        .font(.game(.caption))
                        .foregroundStyle(alert.critical ? Theme.loss : Theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)
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
                let route = engine.state.routes.first
                let routeLabel = route.map { "\($0.originID) ✈︎ \($0.destinationID)" }
                firstFlightRow(number: 1, isLast: false,
                               done: !engine.state.routes.isEmpty,
                               title: "Open your first route",
                               detail: "Pick a pair where the demand is.") {
                    showingNewRoute = true
                }
                firstFlightRow(number: 2, isLast: false,
                               done: !engine.state.fleet.isEmpty,
                               title: routeLabel.map { "Lease an aircraft for \($0)" }
                                   ?? "Lease your first aircraft",
                               detail: "No capital needed. A feeder flies day one.") {
                    showingShowroom = true
                }
                firstFlightRow(number: 3, isLast: true,
                               done: hasAssignedRoute,
                               title: routeLabel.map { "Put the plane on \($0)" }
                                   ?? "Put the plane on the route",
                               detail: "Assign it and the week starts earning.") {
                    if route != nil {
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

    // ── Ambient event: a decision that doesn't stop the clock (GDD §25) ──

    private func ambientIcon(for category: EventCategory) -> String {
        switch category {
        case .market: "chart.line.downtrend.xyaxis"
        case .weather: "cloud.bolt.rain.fill"
        case .labor: "person.3.fill"
        case .technical: "wrench.and.screwdriver.fill"
        case .opportunity: "sparkles"
        case .regulatory: "checkmark.shield.fill"
        case .pr: "megaphone.fill"
        case .story: "envelope.open.fill"
        }
    }

    @ViewBuilder
    private func ambientEventCard(_ event: GameEvent) -> some View {
        let tint = event.isNegative ? Theme.warn : Theme.profit
        let daysLeft = max(0, (event.autoResolveDay ?? 0) - engine.state.date.totalDays)
        let defaultIdx = min(max(0, event.defaultOptionIndex), event.options.count - 1)
        GameCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: ambientIcon(for: event.category))
                        .font(.system(size: 19)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Decision".uppercased())
                        .font(.data(.caption2)).tracking(1.2)
                        .foregroundStyle(tint)
                    Text(event.title)
                        .font(.display(.title3)).foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            // Ambient bodies are a single short paragraph; the counsel line
            // (major lawsuit cards only) never reaches here.
            Text(event.body)
                .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                ForEach(Array(event.options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        engine.resolveEvent(option: option)
                    } label: {
                        Text(option.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GameButtonStyle(color: tint, prominent: index == 0))
                }
            }
            .padding(.top, 2)
            Text(daysLeft <= 0
                 ? "Unattended, this settles now as \u{201C}\(event.options[defaultIdx].label)\u{201D}."
                 : "Left undecided, we \u{201C}\(event.options[defaultIdx].label)\u{201D} in \(daysLeft) day\(daysLeft == 1 ? "" : "s").")
                .font(.game(.caption2)).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
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

    /// The Gazette pages (GDD §33): breaking news first, then the rival
    /// watch, then the market trends (long regimes before short shocks).
    private var gazetteItems: [GazetteItem] {
        var items: [GazetteItem] = []
        if let news = engine.currentPressHeadline { items.append(.news(news)) }
        if let press = engine.currentRivalPress { items.append(.rival(press)) }
        let trends = engine.industryTrends.sorted {
            ($0.horizon == .long ? 0 : 1) < ($1.horizon == .long ? 0 : 1)
        }
        items += trends.map { .trend($0) }
        return items
    }

    // ── Marketing (§34): buy awareness, awareness buys demand — an HQ call.
    private var marketingCard: some View {
        GameCard {
            SectionHeader(title: "Marketing", icon: "megaphone.fill", accent: accent)
            MeterRow(label: "Brand awareness", value: engine.state.brandAwareness / 100,
                     display: "\(Int(engine.state.brandAwareness))/100",
                     color: Theme.health(0.3 + engine.state.brandAwareness / 150))
            HStack(spacing: 10) {
                Text("Budget").font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                Slider(value: Binding(
                    get: { engine.state.weeklyMarketingSpend },
                    set: { engine.setMarketingSpend($0) }
                ), in: 0...Balance.marketingSpendMax, step: 2_000)
                .tint(accent)
                TickerText(text: engine.state.weeklyMarketingSpend.money + "/wk",
                           font: .game(.caption, weight: .bold))
                    .frame(width: 76, alignment: .trailing)
            }
            Text("Demand \(String(format: "%+.1f", (Balance.awarenessMultiplier(engine.state.brandAwareness) - 1) * 100))% from awareness · decays \(Int(Balance.awarenessDecay * 100))%/wk without spend")
                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
        }
    }

    /// Head Quarter shows when there's news to read or a condition to act on.
    private var hqHasContent: Bool {
        !gazetteItems.isEmpty || !engine.routesNeedingAttention.isEmpty
            || !engine.state.activeEffects.isEmpty
            || !wornAircraft.isEmpty || !engine.agingAircraft.isEmpty
    }

    // The Head Quarter (§33): the newsroom AND the ops board in one — the
    // Gazette (news + its effects, as trends) on top, then eroding routes,
    // the timed modifiers in force, and the aircraft that need a look.
    private var headquartersCard: some View {
        let items = gazetteItems
        let hasOps = !engine.routesNeedingAttention.isEmpty
            || !engine.state.activeEffects.isEmpty || !wornAircraft.isEmpty
            || !engine.agingAircraft.isEmpty
        return GameCard {
            SectionHeader(title: "Your Desk", icon: "briefcase.fill", accent: accent)
            if !items.isEmpty { gazette(items) }
            if !items.isEmpty && hasOps { Divider().overlay(Theme.hairline) }
            routeAttentionRows
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
                // Tap a worn plane to jump to the Fleet, where it leads the
                // list (sorted worst-wear first) ready to service or ground.
                Button {
                    onOpenFleet()
                } label: {
                    HStack {
                        StatusBadge(text: plane.nickname,
                                    color: critical ? Theme.loss : Theme.warn)
                        Spacer()
                        Text(critical ? "\(Int(plane.wear))% wear · ground it"
                                      : "\(Int(plane.wear))% wear · service soon")
                            .font(.game(.caption))
                            .foregroundStyle(critical ? Theme.loss : Theme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            // Aging fleet (GDD §26 Pillar 4): old airframes cost ever more
            // to run — plan their replacement. Tap to jump to the Fleet.
            ForEach(engine.agingAircraft) { plane in
                Button {
                    onOpenFleet()
                } label: {
                    HStack {
                        StatusBadge(text: plane.nickname, color: Theme.textSecondary)
                        Spacer()
                        Text("\(Int(plane.ageYears)) yrs · plan replacement")
                            .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── Ambition ladder: the next big goal (GDD §26 Pillar 5) ────────────

    private func ambitionCard(_ ambition: AmbitionDef) -> some View {
        let progress = engine.ambitionProgress(ambition)
        return GameCard {
            SectionHeader(title: "Ambition", icon: "trophy.fill", accent: accent)
            Text(ambition.title)
                .font(.display(.title3)).foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(ambition.detail)
                .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // A slim progress rail.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bgElevated).frame(height: 6)
                    Capsule().fill(accent)
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.data(.caption2)).foregroundStyle(accent)
                Spacer()
                Text("Reward \(ambition.reward.money)")
                    .font(.game(.caption2)).foregroundStyle(Theme.textTertiary)
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
            // The supporting stats collapse behind a disclosure — the score
            // leads; tap to unfold rating, last week, fleet, and routes.
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    heroStatsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    engravedLabel(heroStatsExpanded ? "Hide details" : "Rating, fleet & more")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(heroStatsExpanded ? 180 : 0))
                }
                // The whole row is the target — including the gap by the chevron.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if heroStatsExpanded {
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
                // The tiles fade in place as the card grows — no sliding up
                // over the heading, which was the odd part.
                .transition(.opacity)
            }
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

    // ── Profile: identity, year, milestone, and the save slots ───────────

    @State private var showingProfile = false

    /// The airline's monogram in a machined silver disc — the profile hub's
    /// key, top-right of the dashboard.
    private var profileButton: some View {
        Button { showingProfile = true } label: {
            Text(engine.fleetPrefix)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.58)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .white.opacity(0.5), radius: 3)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(LinearGradient(
                        colors: [Color(white: 0.22), Color(white: 0.10)],
                        startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.45), .white.opacity(0.08)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingProfile) { ProfileSheet() }
    }

    // ── Industry standing: the ladder to climb (starts at the bottom) ────

    private var industryCard: some View {
        let (rank, _) = engine.industryRank
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
            // The Gazette (news portal) moved to the Head Quarter card (§33).
        }
        .sheet(isPresented: $showingIndustry) { IndustrySheet() }
    }

    // Warm newsprint ink on the little black-paper panel.
    private static let gazetteInk = Color(red: 0.93, green: 0.91, blue: 0.85)
    private static let gazetteInkSoft = Color(red: 0.68, green: 0.66, blue: 0.61)
    /// A foil-stamped sheen for the headline: bright warm white catching the
    /// light up top, settling to a dimmer warm gray below.
    private static let gazetteFoil = LinearGradient(
        colors: [Color(red: 1.0, green: 0.98, blue: 0.93),
                 Color(red: 0.80, green: 0.75, blue: 0.66)],
        startPoint: .top, endPoint: .bottom)
    /// Didot — the high-contrast display serif of mastheads (a system font,
    /// no bundling); it falls back to the system serif if ever unavailable.
    private static func didot(_ size: CGFloat) -> Font { .custom("Didot-Bold", size: size) }

    /// One flippable page of the Gazette: breaking news, a rival's jab, or a
    /// market trend.
    enum GazetteItem: Identifiable {
        case news(RivalQuote)
        case rival(RivalQuote)
        case trend(IndustryTrend)
        var id: String {
            switch self {
            case .news(let q): "news-\(q.headline)"
            case .rival(let q): "rival-\(q.headline)-\(q.attribution)"
            case .trend(let t): "trend-\(t.id)"
            }
        }
    }

    /// The market's weather as a swipeable newspaper, inline on the home
    /// page: a fixed masthead, then one concise story per page. Flip with a
    /// horizontal swipe; the dots keep your place. No drill-down.
    private func gazette(_ items: [GazetteItem]) -> some View {
        let ink = Self.gazetteInk, inkSoft = Self.gazetteInkSoft
        func rule() -> some View { Rectangle().fill(inkSoft.opacity(0.4)).frame(height: 1) }
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                rule()
                Text("THE SKYWARD GAZETTE")
                    .font(Self.didot(13))
                    .tracking(1.4).foregroundStyle(ink).fixedSize()
                rule()
            }
            TabView(selection: $gazettePage) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Group {
                        switch item {
                        case .news(let q): newsStory(q)
                        case .trend(let t): gazetteStory(t)
                        case .rival(let q): rivalStory(q)
                        }
                    }
                    .tag(index).padding(.horizontal, 4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 126)
            .animation(.snappy, value: gazettePage)
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        Circle()
                            .fill(ink.opacity(i == gazettePage ? 0.9 : 0.28))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    /// Breaking news (an acquisition, §33): a bold foil headline over the
    /// story line, bylined to the Gazette.
    private func newsStory(_ q: RivalQuote) -> some View {
        let inkSoft = Self.gazetteInkSoft
        return VStack(spacing: 5) {
            Text("BREAKING")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .tracking(1.8).foregroundStyle(Theme.cornflower)
            Text(q.headline)
                .font(Self.didot(23))
                .foregroundStyle(Self.gazetteFoil)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text(q.quote)
                .font(.system(size: 12.5, design: .serif)).italic()
                .foregroundStyle(inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// A rival's line in the press: kicker, foil headline, the pull-quote
    /// itself (the star), and the byline.
    private func rivalStory(_ q: RivalQuote) -> some View {
        let inkSoft = Self.gazetteInkSoft
        return VStack(spacing: 5) {
            Text("RIVAL WATCH")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .tracking(1.6).foregroundStyle(inkSoft)
            Text(q.headline)
                .font(Self.didot(21))
                .foregroundStyle(Self.gazetteFoil)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(q.quote)
                .font(.system(size: 14, design: .serif)).italic()
                .foregroundStyle(Self.gazetteInk)
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(q.attribution)")
                .font(.system(size: 10, design: .serif))
                .foregroundStyle(inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// One story, told in a glance: kicker, serif headline, italic
    /// standfirst, and a single readout (the lever's move and its duration).
    private func gazetteStory(_ trend: IndustryTrend) -> some View {
        let inkSoft = Self.gazetteInkSoft
        let pct = Int(((trend.multiplier - 1) * 100).rounded())
        let tint = trend.favorsPlayer ? Theme.profit : Theme.loss
        return VStack(spacing: 5) {
            Text(trend.horizon == .long ? "LONG-RANGE FORECAST" : "MARKET BULLETIN")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .tracking(1.6).foregroundStyle(inkSoft)
            Text(trend.name)
                .font(Self.didot(26))
                .foregroundStyle(Self.gazetteFoil)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(trend.detail)
                .font(.system(size: 12, design: .serif)).italic()
                .foregroundStyle(inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(trend.kind.label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1).foregroundStyle(inkSoft)
                Text("\(pct >= 0 ? "+" : "")\(pct)%")
                    .font(.system(size: 17, weight: .heavy, design: .serif))
                    .foregroundStyle(tint)
                Text("· \(trend.weeksRemaining) wk")
                    .font(.system(size: 11, design: .serif)).italic()
                    .foregroundStyle(inkSoft)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
        // Weeks per chart bucket: 1 (W), ~4.3 (M, 30-day), 13 (Y, quarter).
        let divisor: Double = switch financeRange {
        case .weekly: 1; case .monthly: 30.0 / 7.0; case .yearly: 13
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

    /// Downsample the DAILY level series into the selected range's buckets
    /// (last value per bucket, aligned to now) — GDD §23. The newest bucket
    /// takes today's value, so the chart's tip advances every day while the
    /// week/month/quarter granularity holds steady.
    private func rangeSeries(_ raw: [Double]) -> [Double] {
        switch financeRange {
        case .weekly:  return bucketLast(raw, size: 7, keep: 13)   // ~13 weeks
        case .monthly: return bucketLast(raw, size: 30, keep: 12)  // ~12 months
        case .yearly:  return bucketLast(raw, size: 91, keep: 20)  // ~5 years, by quarter
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
                Text("The top of the table, and the fight you are in.")
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

// ── The Profile hub ──────────────────────────────────────────────────────
// One crafted sheet: who you are (airline name, country, year), where you
// stand (milestone progress), and the save slots (load, new, delete).

private struct ProfileSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(GameSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var deletingSlot: Int?
    @State private var refresh = 0
    @State private var showingCard = false

    private var done: Set<String> { engine.state.completedMilestones }

    /// Snapshot of the airline for the shareable card (GDD §30).
    private var cardData: AirlineCardData {
        let (rank, total) = engine.industryRank
        return AirlineCardData(
            airlineName: engine.state.airlineName,
            monogram: engine.fleetPrefix,
            adjective: engine.state.country.adjective,
            year: engine.state.date.year,
            rank: rank, total: total,
            rating: engine.state.reputation,
            fleetCount: engine.state.fleet.filter { $0.status != .onOrder }.count,
            routeCount: engine.state.routes.count,
            netWorth: engine.netWorth.money,
            marketCap: engine.marketCap.money,
            bestWeek: (engine.state.records?.bestWeekProfit ?? 0).money,
            fuselage: Color(engine.state.livery.fuselage),
            stripe: Color(engine.state.livery.stripe),
            tail: Color(engine.state.livery.tail))
    }

    private var shareButton: some View {
        Button {
            showingCard = true
        } label: {
            Label("Share your airline card", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GameButtonStyle(color: accent, prominent: true))
    }
    private var nextMilestone: MilestoneDef? {
        Balance.milestones.first { !done.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                identity
                // Airline card hidden for now — needs a redesign pass.
                operationsCard
                milestoneSummary
                ambitionsCard
                recordsCard
                Divider().overlay(Theme.hairline)
                SectionHeader(title: "Saved games", icon: "tray.full.fill", accent: accent)
                Text("Three slots. The active game autosaves every week.")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                ForEach(1...GameEngine.slotCount, id: \.self) { slot in
                    slotCard(slot)
                }
                .id(refresh)
                Button("Done") { dismiss() }
                    .buttonStyle(GameButtonStyle(color: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4).padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
        .background(Theme.bgElevated)
        .presentationDetents([.large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
        .confirmationDialog("Delete this saved game? There is no undo.",
                            isPresented: Binding(get: { deletingSlot != nil },
                                                 set: { if !$0 { deletingSlot = nil } }),
                            titleVisibility: .visible) {
            Button("Delete save", role: .destructive) {
                if let slot = deletingSlot { GameEngine.deleteSave(slot: slot); refresh += 1 }
                deletingSlot = nil
            }
            Button("Keep it", role: .cancel) { deletingSlot = nil }
        }
        .sheet(isPresented: $showingCard) { ShareCardSheet(data: cardData) }
    }

    private let accent = Theme.sky

    // ── Who you are ──────────────────────────────────────────────────────
    private var identity: some View {
        HStack(spacing: 14) {
            Text(engine.fleetPrefix)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.58)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .white.opacity(0.5), radius: 4)
                .frame(width: 68, height: 68)
                .background(Circle().fill(LinearGradient(
                    colors: [Color(white: 0.22), Color(white: 0.09)],
                    startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.45), .white.opacity(0.08)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.state.airlineName)
                    .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Text("\(engine.state.country.displayName) · \((engine.state.difficulty ?? .standard).displayName)")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                Text("YEAR \(engine.state.date.year) · WEEK \(engine.state.date.week)")
                    .font(.data(.caption2)).tracking(0.9)
                    .foregroundStyle(Theme.cornflower)
            }
            Spacer(minLength: 0)
        }
    }

    // ── Where you stand ──────────────────────────────────────────────────
    private var milestoneSummary: some View {
        GameCard {
            HStack {
                SectionHeader(title: "Milestones", icon: "flag.checkered", accent: accent)
                Spacer()
                Text("\(done.count)/\(Balance.milestones.count)")
                    .font(.game(.caption, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            MeterBar(value: Double(done.count) / Double(max(1, Balance.milestones.count)),
                     color: Theme.profit)
            if let next = nextMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                    Text(next.displayTitle(for: engine.state.country))
                        .font(.game(.subheadline)).foregroundStyle(Theme.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text("+\(next.reward.money)")
                        .font(.game(.caption, weight: .semibold)).foregroundStyle(Theme.profit)
                }
                .padding(.top, 2)
            } else {
                Text("All milestones complete. The sandbox is yours.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // ── The ambition ladder, full climb (GDD §26 Pillar 5) ───────────────
    private var ambitionsCard: some View {
        let done = engine.state.completedAmbitions ?? []
        let current = engine.currentAmbition
        return GameCard {
            HStack {
                SectionHeader(title: "Ambitions", icon: "trophy.fill", accent: accent)
                Spacer()
                Text("\(done.count)/\(Balance.ambitions.count)")
                    .font(.game(.caption, weight: .bold)).foregroundStyle(Theme.textSecondary)
            }
            MeterBar(value: Double(done.count) / Double(max(1, Balance.ambitions.count)),
                     color: accent)
            ForEach(Balance.ambitions) { a in
                let isDone = done.contains(a.id)
                let isCurrent = current?.id == a.id
                HStack(spacing: 8) {
                    Image(systemName: isDone ? "checkmark.circle.fill"
                          : isCurrent ? "trophy.fill" : "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(isDone ? Theme.profit
                                         : isCurrent ? accent : Theme.textTertiary)
                    Text(a.title)
                        .font(.game(.subheadline))
                        .foregroundStyle(isDone || isCurrent ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    if isDone {
                        Text("Done").font(.game(.caption2, weight: .semibold))
                            .foregroundStyle(Theme.profit)
                    } else if isCurrent {
                        Text("\(Int(engine.ambitionProgress(a) * 100))% · +\(a.reward.money)")
                            .font(.game(.caption2, weight: .semibold)).foregroundStyle(accent)
                    } else {
                        Text("+\(a.reward.money)")
                            .font(.game(.caption2)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }

    // ── Personal bests (GDD §29) ─────────────────────────────────────────
    // ── Operations autopilot (GDD §36) ───────────────────────────────────
    private var operationsCard: some View {
        GameCard {
            SectionHeader(title: "Operations", icon: "gearshape.2.fill", accent: accent)
            Toggle(isOn: Binding(
                get: { engine.autoServiceWorn },
                set: { engine.setAutoServiceWorn($0) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-service worn aircraft")
                        .font(.game(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Grounds and services any plane past \(Int(Balance.autoServiceWearThreshold))% wear before it can fall out of the sky. Each check costs \(Double(30_000).money).")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(accent)
        }
    }

    private var recordsCard: some View {
        let r = engine.state.records ?? Records()
        return GameCard {
            SectionHeader(title: "Records", icon: "rosette", accent: accent)
            VStack(spacing: 8) {
                recordRow("Best week", r.bestWeekProfit.money)
                recordRow("Best route, one week", r.bestRouteProfit.money)
                recordRow("Largest fleet", "\(r.largestFleet)")
                recordRow("Highest rating", String(format: "%.1f★", r.highestReputation))
                recordRow("Peak market cap", r.highestMarketCap.money)
                recordRow("Most passengers, one week", "\(Int(r.mostWeeklyPax))")
            }
        }
    }

    private func recordRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.data(.subheadline, weight: .semibold)).foregroundStyle(Theme.textPrimary)
        }
    }

    // ── Save slots (load / new / delete), housed here ────────────────────
    @ViewBuilder private func slotCard(_ slot: Int) -> some View {
        let isActive = slot == GameEngine.activeSlot && session.engine != nil
        GameCard(highlight: isActive ? Theme.cornflower : nil) {
            HStack {
                Text("SLOT \(slot)")
                    .font(.data(.caption2)).tracking(0.85).foregroundStyle(Theme.textSecondary)
                Spacer()
                if isActive { StatusBadge(text: "Playing", color: Theme.cornflower) }
            }
            if let state = GameEngine.slotState(slot) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.airlineName)
                            .font(.game(.headline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Text("\(state.country.displayName) · \(state.date.description)")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    TickerText(text: state.cash.money,
                               font: .game(.subheadline, weight: .semibold),
                               color: state.cash >= 0 ? Theme.profit : Theme.loss)
                }
                HStack(spacing: 8) {
                    if !isActive {
                        Button("Load") { session.activate(slot: slot); dismiss() }
                            .buttonStyle(GameButtonStyle(color: accent, prominent: true))
                    }
                    Button("New game") { session.beginNewGame(inSlot: slot); dismiss() }
                        .buttonStyle(GameButtonStyle(color: accent))
                    Spacer()
                    if !isActive {
                        Button("Delete") { deletingSlot = slot }
                            .buttonStyle(GameButtonStyle(color: Theme.loss))
                    }
                }
            } else {
                Text("Empty slot")
                    .font(.game(.subheadline)).foregroundStyle(Theme.textTertiary)
                Button("New game") { session.beginNewGame(inSlot: slot); dismiss() }
                    .buttonStyle(GameButtonStyle(color: accent, prominent: true))
            }
        }
    }
}

#Preview("Profile") {
    ProfileSheet()
        .environment(GameSession())
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

#Preview("Foundation start") {
    DashboardView()
        .environment(GameEngine.newGame(airlineName: "Foundation Air",
                                        country: .us, seed: 7))
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
