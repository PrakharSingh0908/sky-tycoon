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
            milestonesCard
            trendsCard
            if let report = engine.latestReport { lastWeekCard(report) }
        }
    }

    // ── Reputation collapse: the soft-fail spiral warning (GDD §4.5) ────

    private var reputationCollapseBanner: some View {
        GameCard {
            Label("Reputation collapse — demand is cratering. Fix punctuality, comfort, and service before the spiral locks in.",
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

    private var heroCard: some View {
        GameCard {
            HStack(alignment: .top) {
                StatTile(label: "Net worth", value: engine.netWorth.money,
                         color: engine.netWorth >= 0 ? Theme.textPrimary : Theme.loss,
                         font: .game(.largeTitle, weight: .bold))
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
                TrendChart(values: engine.state.netWorthHistory, color: accent)
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
            SectionHeader(title: "Last week — \(report.date.description)",
                          icon: "clock.arrow.circlepath", accent: accent)
            HStack(spacing: 20) {
                StatTile(label: "Revenue", value: report.revenue.money)
                StatTile(label: "Costs", value: (report.profit - report.revenue).money,
                         color: Theme.textSecondary)
                StatTile(label: "Profit", value: report.profit.money,
                         color: report.profit >= 0 ? Theme.profit : Theme.loss)
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

#Preview {
    DashboardView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
