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
            trustFundCard
            if !engine.state.letters.isEmpty { lettersCard }
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

    @ViewBuilder private var trustFundCard: some View {
        GameCard {
            SectionHeader(title: "Aunt's Trust Fund", icon: "envelope.fill", accent: Theme.warn)
            switch engine.state.trustFundResolution {
            case .pending:
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
            case .succeeded:
                Label("Aunt's Approval — the fund converted to a gift. The airline is yours, properly.",
                      systemImage: "checkmark.seal.fill")
                    .font(.game(.caption, weight: .semibold)).foregroundStyle(Theme.profit)
            case .failed:
                Label("The fund was withdrawn — hard mode. Everything from here is yours alone.",
                      systemImage: "xmark.seal.fill")
                    .font(.game(.caption, weight: .semibold)).foregroundStyle(Theme.loss)
            }
        }
    }

    // ── Letters from Aunt Meera — the arc's voice ────────────────────────

    private var lettersCard: some View {
        let letters = engine.state.letters.reversed()
        return GameCard {
            SectionHeader(title: "Letters from Aunt Meera", icon: "envelope.open.fill",
                          accent: Theme.warn)
            if let latest = letters.first {
                letterView(latest)
            }
            if letters.count > 1 {
                DisclosureGroup {
                    ForEach(Array(letters.dropFirst())) { letter in
                        letterView(letter)
                        Divider().overlay(Theme.hairline)
                    }
                } label: {
                    Text("Older letters (\(letters.count - 1))")
                        .font(.game(.caption, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .tint(Theme.textSecondary)
            }
        }
    }

    private func letterView(_ letter: QuarterlyLetter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(letter.date.description)
                .font(.game(.caption2, weight: .bold)).tracking(1)
                .foregroundStyle(Theme.textSecondary)
            Text(letter.body)
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
            Text("— Aunt Meera")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(Theme.warn)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(Theme.warn.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
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
