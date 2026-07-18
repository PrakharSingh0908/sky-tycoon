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
            if !engine.state.activeEffects.isEmpty { opsConditionsCard }
            trendsCard
            if let report = engine.latestReport { lastWeekCard(report) }
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
        }
    }
}
