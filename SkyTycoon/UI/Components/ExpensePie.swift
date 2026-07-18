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
            ExpenseSlice(label: "Fuel", amount: fuelCost, color: Theme.chartPalette[0]),
            ExpenseSlice(label: "Wages", amount: wageCost, color: Theme.chartPalette[1]),
            ExpenseSlice(label: "Maintenance", amount: maintenanceCost, color: Theme.chartPalette[2]),
            ExpenseSlice(label: "Loans", amount: loanCost, color: Theme.chartPalette[3]),
            ExpenseSlice(label: "Leases", amount: leaseCost, color: Theme.chartPalette[5]),
            ExpenseSlice(label: "Cabin & catering", amount: cabinCost, color: Theme.chartPalette[6]),
            ExpenseSlice(label: "Marketing", amount: marketingCost, color: Theme.chartPalette[7]),
            ExpenseSlice(label: "Overhead", amount: overheadCost, color: Theme.chartPalette[8]),
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

    /// The share ring drawn as a turbofan face: 24 swept blades around a
    /// spinner hub inside a nacelle ring. Each blade takes the color of the
    /// category owning its angular position, so blade count per category
    /// still reads share (the legend carries exact percentages).
    private var donut: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) / 2 - 1.5
            let rOuter = R - 4.5
            let rInner = R * 0.44
            let blades = 24

            // Cumulative share boundaries → color at any angular fraction.
            var bounds: [(end: Double, color: Color)] = []
            var cum = 0.0
            for slice in slices {
                cum += slice.amount / total
                bounds.append((cum, slice.color))
            }
            func color(at fraction: Double) -> Color {
                bounds.first { fraction <= $0.end }?.color ?? bounds[bounds.count - 1].color
            }
            func pt(_ r: Double, _ a: Double) -> CGPoint {
                CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            }

            let slot = 2 * Double.pi / Double(blades)
            let sweep = slot * 0.74            // blade width; the rest is gap
            let twist = slot * 1.15            // tip leads root: the fan sweep
            for i in 0..<blades {
                let root = Double(i) * slot - .pi / 2
                var blade = Path()
                blade.addArc(center: center, radius: rInner,
                             startAngle: .radians(root),
                             endAngle: .radians(root + sweep), clockwise: false)
                blade.addLine(to: pt(rOuter, root + sweep + twist))
                blade.addArc(center: center, radius: rOuter,
                             startAngle: .radians(root + sweep + twist),
                             endAngle: .radians(root + twist), clockwise: true)
                blade.closeSubpath()
                let c = color(at: (Double(i) + 0.5) / Double(blades))
                // Root-to-tip shading gives the blade its curvature.
                ctx.fill(blade, with: .linearGradient(
                    Gradient(colors: [c.opacity(0.55), c]),
                    startPoint: pt(rInner, root + sweep / 2),
                    endPoint: pt(rOuter, root + sweep / 2 + twist)))
            }

            // Nacelle ring.
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - R, y: center.y - R,
                                              width: R * 2, height: R * 2)),
                       with: .color(Color.white.opacity(0.16)), lineWidth: 1.5)
            // Spinner hub.
            let rHub = rInner - 3
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - rHub, y: center.y - rHub,
                                            width: rHub * 2, height: rHub * 2)),
                     with: .color(Color.white.opacity(0.06)))
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - rHub, y: center.y - rHub,
                                              width: rHub * 2, height: rHub * 2)),
                       with: .color(Color.white.opacity(0.12)), lineWidth: 1)
            let rDot: Double = 2.5
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - rDot, y: center.y - rDot,
                                            width: rDot * 2, height: rDot * 2)),
                     with: .color(Color.white.opacity(0.30)))
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

#Preview {
    GameCard {
        ExpensePie(slices: [
            ExpenseSlice(label: "Fuel", amount: 42_000, color: Theme.orange),
            ExpenseSlice(label: "Wages", amount: 31_000, color: Theme.violet),
            ExpenseSlice(label: "Maintenance", amount: 18_000, color: Theme.warn),
            ExpenseSlice(label: "Leases", amount: 12_000, color: Theme.teal),
            ExpenseSlice(label: "Overhead", amount: 8_000, color: Theme.textSecondary),
        ])
    }
    .padding()
    .frame(maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
