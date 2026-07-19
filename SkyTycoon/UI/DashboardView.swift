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
    @State private var trendMetric: TrendMetric = .netWorth
    @State private var financeRange: FinanceRange = .weekly
    @State private var settleFlash = false
    @State private var showingIndustry = false
    @State private var eventsExpanded = false
    private let accent = Theme.sky

    enum TrendMetric: String, CaseIterable, Identifiable {
        case netWorth = "Net worth", cash = "Cash", reputation = "Reputation"
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
            Text(milestone.title)
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
                    Text(critical ? "\(Int(plane.wear))% wear — ground it"
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
        let (rank, total) = engine.industryRank
        return Button {
            showingIndustry = true
        } label: {
            GameCard {
                HStack {
                    SectionHeader(title: "Industry", icon: "chart.bar.xaxis", accent: accent)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
                // The rank IS the story: big, with cap and share reading
                // as its supporting instruments.
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
                // The market's weather (GDD §14): the standing regime and
                // any short shocks, each with its live lever effect.
                if !engine.industryTrends.isEmpty {
                    Divider().overlay(Theme.hairline)
                    ForEach(engine.industryTrends.sorted {
                        ($0.horizon == .long ? 0 : 1) < ($1.horizon == .long ? 0 : 1)
                    }) { trend in
                        trendRow(trend)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingIndustry) { IndustrySheet() }
    }

    // One aligned line per fact: tag + name + a single mono readout
    // (effect · weeks); the story gets its own full-width line beneath.
    private func trendRow(_ trend: IndustryTrend) -> some View {
        let pct = Int(((trend.multiplier - 1) * 100).rounded())
        let kind = switch trend.kind {
        case .demand: "demand"; case .fuel: "fuel"
        case .wages: "wages"; case .aircraftPrices: "aircraft"
        }
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(trend.horizon == .long ? "LONG" : "SHORT")
                    .font(.data(.caption2)).tracking(0.85)
                    .foregroundStyle(trend.horizon == .long ? Theme.cornflower : Theme.warn)
                    .frame(width: 46, alignment: .leading)
                Text(trend.name)
                    .font(.game(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                (Text("\(pct >= 0 ? "+" : "")\(pct)% \(kind)")
                    .foregroundStyle(trend.favorsPlayer ? Theme.profit : Theme.loss)
                 + Text(" · \(trend.weeksRemaining)wk")
                    .foregroundStyle(Theme.textTertiary))
                    .font(.data(.caption2, weight: .semibold))
                    .lineLimit(1).fixedSize()
            }
            Text(trend.detail)
                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .padding(.leading, 54)
        }
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
            TrendChart(values: series,
                       color: Theme.cornflower, window: window, unit: unit,
                       events: chartEventMarks,
                       format: trendMetric == .reputation
                           ? { String(format: "%.1f★", $0) } : { $0.money })

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

                SectionHeader(title: "Market cap · top \(carriers.count)",
                              icon: "chart.bar.xaxis", accent: accent)
                Text("Bars are log-scaled; the numbers are exact.")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                VStack(spacing: 8) {
                    ForEach(Array(carriers.enumerated()), id: \.element.id) { index, carrier in
                        capRow(rank: index + 1, carrier)
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

    private var shareSlices: [ExpenseSlice] {
        var colorIndex = 0
        return carriers.map { carrier in
            if carrier.isPlayer {
                return ExpenseSlice(label: carrier.name, amount: max(carrier.pax, 1),
                                    color: accent)
            }
            let color = palette[colorIndex % palette.count]
            colorIndex += 1
            return ExpenseSlice(label: carrier.name, amount: carrier.pax, color: color)
        }
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

#Preview {
    DashboardView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

#Preview("Industry sheet") {
    IndustrySheet()
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
