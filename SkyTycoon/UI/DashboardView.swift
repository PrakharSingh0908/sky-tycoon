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
    @State private var settleFlash = false
    @State private var showingIndustry = false
    private let accent = Theme.sky

    enum TrendMetric: String, CaseIterable, Identifiable {
        case netWorth = "Net worth", cash = "Cash", reputation = "Reputation"
        var id: String { rawValue }
    }

    var body: some View {
        GameScreen(title: "Dashboard", accent: accent) {
            heroCard
            if engine.state.reputation < 2.0 { reputationCollapseBanner }
            if !engine.state.activeEffects.isEmpty { opsConditionsCard }
            industryCard
            trendsCard
            if let report = engine.latestReport { lastWeekCard(report) }
            milestonesCard
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
        }
    }

    // ── Hero: the numbers that matter, always rolling ────────────────────
    // The one standing gradient border (v2.1: borders are hierarchy, and
    // the score IS the hierarchy). Flashes profit-green on weekly settle.

    private var heroCard: some View {
        GameCard(highlight: settleFlash ? Theme.profit : accent) {
            HStack(alignment: .top) {
                StatTile(label: "Net worth", value: engine.netWorth.money,
                         color: engine.netWorth >= 0 ? Theme.sienna : Theme.loss,
                         font: .display(.largeTitle))
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StarRating(rating: engine.state.reputation, size: 13)
                    TickerText(text: String(format: "%.1f reputation", engine.state.reputation),
                               font: .game(.caption, weight: .semibold),
                               color: Theme.textSecondary)
                }
            }
            HStack(spacing: 20) {
                StatTile(label: "Cash", value: engine.state.cash.money,
                         color: engine.state.cash >= 0 ? Theme.profit : Theme.loss)
                if let report = engine.latestReport {
                    StatTile(label: "Last week",
                             value: (report.profit >= 0 ? "+" : "") + report.profit.money,
                             color: report.profit >= 0 ? Theme.profit : Theme.loss)
                }
                StatTile(label: "Fleet", value: "\(engine.state.fleet.count)")
                StatTile(label: "Routes", value: "\(engine.state.routes.count)")
            }
        }
    }

    // ── Industry standing: the ladder to climb (starts at the bottom) ────

    private var industryCard: some View {
        let (rank, total) = engine.industryRank
        return Button {
            showingIndustry = true
        } label: {
            GameCard {
                HStack {
                    SectionHeader(title: "Industry standing", icon: "chart.bar.xaxis", accent: accent)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold)).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 20) {
                    StatTile(label: "Rank", value: "#\(rank) of \(total)",
                             color: rank <= 3 ? Theme.profit : Theme.textPrimary)
                    StatTile(label: "Market cap", value: engine.marketCap.money)
                    StatTile(label: "Market share",
                             value: String(format: "%.1f%%", engine.marketShare * 100))
                }
                if let next = engine.nextRival {
                    Text("Next up: \(next.name) · \(next.marketCap.money) market cap")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                } else {
                    Text("India's largest carrier. The sky is yours.")
                        .font(.game(.caption2, weight: .semibold)).foregroundStyle(Theme.profit)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingIndustry) { IndustrySheet() }
    }

    // ── Trends ───────────────────────────────────────────────────────────

    private var trendsCard: some View {
        GameCard {
            SectionHeader(title: "Trends", icon: "chart.xyaxis.line", accent: accent)
            HStack(spacing: 8) {
                ForEach(TrendMetric.allCases) { metric in
                    Button(metric.rawValue) { trendMetric = metric }
                        .buttonStyle(GameButtonStyle(color: accent, prominent: trendMetric == metric))
                }
            }
            switch trendMetric {
            case .netWorth:
                TrendChart(values: engine.state.netWorthHistory, color: Theme.sienna)
            case .cash:
                TrendChart(values: engine.state.cashHistory, color: Theme.profit)
            case .reputation:
                TrendChart(values: engine.state.reputationHistory, color: Theme.warn,
                           format: { String(format: "%.1f★", $0) })
            }
        }
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
                        Text("\(route.originID) ⇄ \(route.destinationID)")
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
        var all = Balance.industryRivals.map {
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
        .preferredColorScheme(.light)
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
                              ? AnyShapeStyle(Theme.sienna)
                              : AnyShapeStyle(Color.black.opacity(0.12)))
                        .frame(width: geo.size.width * fraction)
                }
                .frame(height: 6)
            }
        }
    }
}

#Preview {
    DashboardView().environment(GameEngine.previewGame())
        .preferredColorScheme(.light)
}

#Preview("Industry sheet") {
    IndustrySheet()
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.light)
}
