//
//  ExpensePie.swift
//  SkyTycoon — UI components
//
//  Where the money went: a donut of last week's expense share with a
//  percent legend. Used on the Dashboard's Last Week card and the Money
//  tab's weekly statement (GDD pillar 4: the sim explains itself).
//

import SwiftUI

struct ExpenseSlice: Identifiable {
    let label: String
    let amount: Double
    let color: Color
    var id: String { label }
}

extension WeeklyReport {
    /// Nonzero cost categories, biggest first, themed for the pie.
    var expenseSlices: [ExpenseSlice] {
        [
            ExpenseSlice(label: "Fuel", amount: fuelCost, color: Theme.orange),
            ExpenseSlice(label: "Wages", amount: wageCost, color: Theme.violet),
            ExpenseSlice(label: "Maintenance", amount: maintenanceCost, color: Theme.warn),
            ExpenseSlice(label: "Loans", amount: loanCost, color: Theme.sky),
            ExpenseSlice(label: "Leases", amount: leaseCost, color: Theme.teal),
            ExpenseSlice(label: "Cabin & catering", amount: cabinCost, color: Theme.profit),
            ExpenseSlice(label: "Marketing", amount: marketingCost, color: Theme.loss),
            ExpenseSlice(label: "Overhead", amount: overheadCost, color: Theme.textSecondary),
        ]
        .filter { $0.amount > 0 }
        .sorted { $0.amount > $1.amount }
    }
}

struct ExpensePie: View {
    let slices: [ExpenseSlice]

    private var total: Double { slices.reduce(0) { $0 + $1.amount } }

    var body: some View {
        if total > 0 {
            HStack(spacing: 18) {
                donut
                    .frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(slices) { slice in
                        legendRow(slice)
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            Text("No spending recorded yet.")
                .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
        }
    }

    private var donut: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 7
            var start = Angle.degrees(-90)
            for slice in slices {
                let sweep = Angle.degrees(slice.amount / total * 360)
                var arc = Path()
                arc.addArc(center: center, radius: radius,
                           startAngle: start, endAngle: start + sweep,
                           clockwise: false)
                ctx.stroke(arc, with: .color(slice.color),
                           style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                start += sweep
            }
            // Gauge graduations: 12 cut lines across the ring (Flight Deck).
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi - .pi / 2
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cos(a) * (radius - 7),
                                      y: center.y + sin(a) * (radius - 7)))
                tick.addLine(to: CGPoint(x: center.x + cos(a) * (radius + 7),
                                         y: center.y + sin(a) * (radius + 7)))
                ctx.stroke(tick, with: .color(Theme.card), lineWidth: 1)
            }
        }
    }

    private func legendRow(_ slice: ExpenseSlice) -> some View {
        HStack(spacing: 6) {
            Circle().fill(slice.color).frame(width: 7, height: 7)
            Text(slice.label)
                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("\(Int((slice.amount / total * 100).rounded()))%")
                .font(.game(.caption2, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
    }
}
