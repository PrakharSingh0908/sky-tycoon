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
    @State private var explanation: Explanation?
    private let accent = Theme.mint

    var body: some View {
        GameScreen(title: "Money", accent: accent) {
            trustFundCard
            if !engine.state.letters.isEmpty { lettersCard }
            balanceSheetCard
            marketingCard
            GameCard {
                SectionHeader(title: "52-week P&L", icon: "chart.bar.fill", accent: accent)
                Text("Profit bars · revenue line. Tap any statement line below for its formula.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                ProfitChart(reports: engine.state.reports)
            }
            if let r = engine.latestReport { statementCard(r) }
            loansCard
        }
        .sheet(item: $explanation) { FormulaSheet(explanation: $0) }
    }

    // ── Balance sheet (M7): what the airline is worth ────────────────────

    private var balanceSheetCard: some View {
        GameCard {
            SectionHeader(title: "Balance sheet", icon: "building.columns.fill", accent: accent)
            HStack(spacing: 20) {
                StatTile(label: "Cash", value: engine.state.cash.money,
                         color: engine.state.cash >= 0 ? Theme.profit : Theme.loss)
                StatTile(label: "Fleet value", value: engine.fleetValue.money)
                StatTile(label: "Debt", value: engine.totalDebt.money,
                         color: engine.totalDebt > 0 ? Theme.warn : Theme.textSecondary)
                StatTile(label: "Net worth", value: engine.netWorth.money,
                         color: engine.netWorth >= 0 ? Theme.textPrimary : Theme.loss)
            }
            TrendChart(values: engine.state.netWorthHistory, color: accent)
        }
    }

    // ── Marketing (M5): buy awareness, awareness buys demand ─────────────

    private var marketingCard: some View {
        GameCard {
            SectionHeader(title: "Marketing", icon: "megaphone.fill", accent: accent)
            MeterRow(label: "Brand awareness", value: engine.state.brandAwareness / 100,
                     display: "\(Int(engine.state.brandAwareness))/100",
                     color: Theme.health(0.3 + engine.state.brandAwareness / 150))
            HStack(spacing: 10) {
                Text("Weekly budget").font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
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
                Label("Aunt's Approval: the fund converted to a gift. The airline is yours, properly.",
                      systemImage: "checkmark.seal.fill")
                    .font(.game(.caption, weight: .semibold)).foregroundStyle(Theme.profit)
            case .failed:
                Label("The fund was withdrawn (hard mode). Everything from here is yours alone.",
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
            // Collapsed to a one-line teaser; the archive opens on demand.
            if let latest = letters.first {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        letterView(latest)
                        ForEach(Array(letters.dropFirst())) { letter in
                            letterView(letter)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 6) {
                        Text(latest.date.description)
                            .font(.data(.caption2, weight: .bold))
                            .foregroundStyle(Theme.warn)
                        Text("“\(latest.body.prefix(48))…”")
                            .font(.system(.caption, design: .serif)).italic()
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(letters.count)")
                            .font(.data(.caption2, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
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
            Text("Aunt Meera")
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
            SectionHeader(title: "Last week · \(r.date.description)",
                          icon: "doc.text.fill", accent: accent)
            // Expense share at a glance; the rows below carry the exact numbers.
            let slices = r.expenseSlices
            if !slices.isEmpty {
                ExpensePie(slices: slices)
                Divider().overlay(Theme.hairline)
            }
            statementRow("Revenue", r.revenue, positive: true) { revenueExplanation(r) }
            Divider().overlay(Theme.hairline)
            statementRow("Fuel", -r.fuelCost) { fuelExplanation(r) }
            statementRow("Wages", -r.wageCost) { wagesExplanation(r) }
            statementRow("Maintenance", -r.maintenanceCost) { maintenanceExplanation(r) }
            statementRow("Loan payments", -r.loanCost) { loansExplanation(r) }
            statementRow("Lease payments", -r.leaseCost) { leaseExplanation(r) }
            statementRow("Cabin & catering", -r.cabinCost) { cabinExplanation(r) }
            statementRow("Marketing", -r.marketingCost) { marketingExplanation(r) }
            statementRow("Overhead", -r.overheadCost) {
                Explanation(title: "Overhead", subtitle: "Fixed weekly HQ costs",
                            rows: [("HQ operations", Balance.hqOverheadPerWeek.money)],
                            formula: "overhead = flat \(Balance.hqOverheadPerWeek.money)/week")
            }
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

    /// A statement line that explains itself when tapped (pillar 4).
    private func statementRow(_ label: String, _ amount: Double, positive: Bool = false,
                              explain: @escaping () -> Explanation) -> some View {
        Button {
            explanation = explain()
        } label: {
            HStack(spacing: 6) {
                Text(label).font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                Image(systemName: "questionmark.circle")
                    .font(.caption2).foregroundStyle(Theme.textSecondary.opacity(0.5))
                Spacer()
                TickerText(text: amount.money,
                           font: .game(.subheadline, weight: .semibold),
                           color: positive ? Theme.profit
                                : (amount == 0 ? Theme.textSecondary : Theme.textPrimary))
            }
        }
        .buttonStyle(.plain)
    }

    // ── Formula content, built from live state ───────────────────────────

    private func revenueExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = engine.state.routes.map { route in
            ("\(route.originID) ⇄ \(route.destinationID) · LF \(Int(route.lastLoadFactor * 100))%",
             route.lastWeeklyRevenue.money)
        }
        rows.append(("Total", r.revenue.money))
        return Explanation(title: "Revenue", subtitle: "Fares collected across the network",
                           rows: rows,
                           formula: "revenue = Σ passengers × fare\npassengers = min(demand, seats offered)")
    }

    private func fuelExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = engine.state.routes
            .filter { $0.lastWeeklyFuel > 0 }
            .map { ("\($0.originID) ⇄ \($0.destinationID)", $0.lastWeeklyFuel.money) }
        rows.append(("Total", r.fuelCost.money))
        return Explanation(title: "Fuel", subtitle: "The airframe burns fuel, full or empty",
                           rows: rows,
                           formula: "fuel = seats(max) × km × burn/seat-km\n     × flights × country × condition × events")
    }

    private func wagesExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = StaffRole.allCases.compactMap { role in
            guard let pool = engine.state.staff[role], pool.headcount > 0 else { return nil }
            return ("\(role.displayName) · \(pool.headcount) × \(pool.weeklyWage.money)",
                    (Double(pool.headcount) * pool.weeklyWage).money)
        }
        rows.append(("Total incl. overtime/contractors", r.wageCost.money))
        return Explanation(title: "Wages", subtitle: "Base pay plus 1.5× beyond roster hours",
                           rows: rows,
                           formula: "wages = Σ headcount × wage\n      + overtime hours × hourly × 1.5")
    }

    private func maintenanceExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = engine.state.fleet
            .filter { $0.status != .onOrder }
            .map { plane in
                ("\(plane.nickname) · wear \(Int(plane.wear)) · cond \(Int(plane.condition))",
                 (Balance.specs[plane.type]!.baseMaintPerWeek
                    * (1 + plane.wear / 200) * (1.6 - 0.6 * plane.condition / 100)).money)
            }
        rows.append(("Total", r.maintenanceCost.money))
        return Explanation(title: "Maintenance", subtitle: "Wear and condition drive the bill",
                           rows: rows,
                           formula: "maint = base × (1 + wear/200)\n      × (1.6 − 0.6 × condition/100)")
    }

    private func loansExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = engine.state.loans.map {
            ("Loan \($0.principal.money) @ \(String(format: "%.2f", $0.weeklyInterestRate * 100))%/wk",
             $0.weeklyPayment.money)
        }
        rows.append(("Total", r.loanCost.money))
        return Explanation(title: "Loan payments", subtitle: "Fixed weekly amortization",
                           rows: rows,
                           formula: "payment = P × r / (1 − (1+r)^−weeks)")
    }

    private func leaseExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = engine.state.fleet
            .filter { $0.acquisition == .leased }
            .map { ($0.nickname, $0.weeklyLeaseCost.money) }
        rows.append(("Total", r.leaseCost.money))
        return Explanation(title: "Lease payments", subtitle: "They never end. That's the deal",
                           rows: rows,
                           formula: "lease = new price × \(String(format: "%.2f", Balance.leaseRatePerWeek * 100))% / week")
    }

    private func cabinExplanation(_ r: WeeklyReport) -> Explanation {
        var rows: [(String, String)] = engine.state.fleet
            .filter { $0.status != .onOrder }
            .map { plane in
                ("\(plane.nickname) · \(plane.cabin.material.displayName)",
                 plane.cabin.weeklyUpkeep(spec: Balance.specs[plane.type]!).money)
            }
        rows.append(("Total", r.cabinCost.money))
        return Explanation(title: "Cabin & catering", subtitle: "Seats, ovens, and wifi upkeep",
                           rows: rows,
                           formula: "cabin = seats × material rate\n     + ovens × $600 + wifi service")
    }

    private func marketingExplanation(_ r: WeeklyReport) -> Explanation {
        Explanation(title: "Marketing", subtitle: "Awareness lifts demand across the network",
                    rows: [("Weekly budget", engine.state.weeklyMarketingSpend.money),
                           ("Brand awareness", "\(Int(engine.state.brandAwareness))/100"),
                           ("Demand effect",
                            String(format: "%+.1f%%", (Balance.awarenessMultiplier(engine.state.brandAwareness) - 1) * 100))],
                    formula: "gain = 8 × spend / (spend + $60K)\nawareness decays 3%/week unspent")
    }

    // ── The bank (M7): three offers, one limit ───────────────────────────

    private var loansCard: some View {
        GameCard {
            SectionHeader(title: "The bank", icon: "building.columns.fill", accent: accent)
            Text("Lending limit: total debt ≤ \(Balance.borrowingLimit(netWorth: engine.netWorth).money) (from net worth). Current debt \(engine.totalDebt.money).")
                .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            ForEach(engine.state.loans) { loan in
                MeterRow(label: "Remaining of \(loan.principal.money)",
                         value: loan.remaining / max(loan.principal, 1),
                         display: loan.remaining.money,
                         color: Theme.warn)
            }
            // Offers stay folded until you're actually shopping for money.
            DisclosureGroup {
                VStack(spacing: 10) {
                    ForEach(Balance.loanOffers) { offer in
                        let allowed = engine.canBorrow(offer)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.name).font(.game(.subheadline, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(offer.amount.money) · \(String(format: "%.2f", offer.weeklyRate * 100))%/wk · \(offer.weeks) wk")
                                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button(allowed ? "Borrow" : "Over limit") { engine.takeLoan(offer: offer) }
                                .buttonStyle(GameButtonStyle(color: accent, prominent: allowed))
                                .disabled(!allowed)
                                .opacity(allowed ? 1 : 0.4)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Offers (\(Balance.loanOffers.count))", systemImage: "banknote")
                    .font(.game(.caption, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .tint(Theme.textSecondary)
        }
    }
}

#Preview {
    MoneyView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
