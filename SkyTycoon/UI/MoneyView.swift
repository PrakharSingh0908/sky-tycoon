//
//  MoneyView.swift
//  SkyTycoon — UI (mint accent)
//
//  P&L chart, the weekly statement, and loans with balance meters
//  (DESIGN_SYSTEM.md §4).
//

import SwiftUI

struct MoneyView: View {
    @Environment(GameEngine.self) private var engine
    private let accent = Theme.mint

    var body: some View {
        GameScreen(title: "Money", accent: accent) {
            if engine.state.trustFundActive { trustFundCard }
            GameCard {
                SectionHeader(title: "52-week P&L", icon: "chart.bar.fill", accent: accent)
                Text("Profit bars · revenue line")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                ProfitChart(reports: engine.state.reports)
            }
            if let r = engine.latestReport { statementCard(r) }
            loansCard
        }
    }

    // ── Trust fund: the tutorial arc as a progress instrument ────────────

    private var trustFundCard: some View {
        GameCard {
            SectionHeader(title: "Aunt's Trust Fund", icon: "envelope.fill", accent: Theme.warn)
            Text("Reach 4 consecutive profitable quarters by \(engine.state.trustFundDeadline.description).")
                .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < engine.state.consecutiveProfitableQuarters
                              ? Theme.profit : Color.white.opacity(0.10))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                Text("\(engine.state.consecutiveProfitableQuarters)/4 profitable quarters")
                    .font(.game(.caption, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .animation(.snappy, value: engine.state.consecutiveProfitableQuarters)
        }
    }

    // ── The weekly statement ─────────────────────────────────────────────

    private func statementCard(_ r: WeeklyReport) -> some View {
        GameCard {
            SectionHeader(title: "Last week — \(r.date.description)",
                          icon: "doc.text.fill", accent: accent)
            statementRow("Revenue", r.revenue, positive: true)
            Divider().overlay(Theme.hairline)
            statementRow("Fuel", -r.fuelCost)
            statementRow("Wages", -r.wageCost)
            statementRow("Maintenance", -r.maintenanceCost)
            statementRow("Loan payments", -r.loanCost)
            statementRow("Lease payments", -r.leaseCost)
            statementRow("Cabin & catering", -r.cabinCost)
            statementRow("Overhead", -r.overheadCost)
            Divider().overlay(Theme.hairline)
            HStack {
                Text("Profit").font(.game(.headline, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                TickerText(text: r.profit.money,
                           font: .game(.headline, weight: .bold),
                           color: r.profit >= 0 ? Theme.profit : Theme.loss)
            }
        }
    }

    private func statementRow(_ label: String, _ amount: Double, positive: Bool = false) -> some View {
        HStack {
            Text(label).font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            TickerText(text: amount.money,
                       font: .game(.subheadline, weight: .semibold),
                       color: positive ? Theme.profit
                            : (amount == 0 ? Theme.textSecondary : Theme.textPrimary))
        }
    }

    // ── Loans ────────────────────────────────────────────────────────────

    private var loansCard: some View {
        GameCard {
            SectionHeader(title: "Loans", icon: "building.columns.fill", accent: accent)
            if engine.state.loans.isEmpty {
                Text("No active loans. The bank is feeling generous.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
            ForEach(engine.state.loans) { loan in
                MeterRow(label: "Remaining of \(loan.principal.money)",
                         value: loan.remaining / max(loan.principal, 1),
                         display: loan.remaining.money,
                         color: Theme.warn)
            }
            HStack(spacing: 8) {
                Button("Borrow $1M") { engine.takeLoan(amount: 1_000_000) }
                    .buttonStyle(GameButtonStyle(color: accent, prominent: true))
                Button("Borrow $5M") { engine.takeLoan(amount: 5_000_000) }
                    .buttonStyle(GameButtonStyle(color: accent))
            }
        }
    }
}

#Preview {
    MoneyView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
