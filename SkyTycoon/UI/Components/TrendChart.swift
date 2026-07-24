//
//  TrendChart.swift
//  SkyTycoon — UI components
//
//  Reusable Swift Charts views for the sim's history buffers. The sim
//  collects plain [Double] ring buffers; these render them. Keeping the
//  chart code here (UI layer) preserves the no-SwiftUI rule in Simulation/.
//

import SwiftUI
import Charts

/// A major event's position on a trend chart, in the chart's own x units.
struct ChartEventMark: Identifiable {
    let id: UUID
    let offset: Double       // 0 = now, negative = past
    let negative: Bool
}

/// A line-plus-gradient-area trend chart over a weekly history buffer.
struct TrendChart: View {
    let values: [Double]
    var color: Color = .blue
    /// Fixed x-window: history shorter than this pads LEFT with the first
    /// value, so the line is honestly flat over weeks that never happened
    /// instead of stretching young data across the axis.
    var window: Int = 52
    /// X-axis unit suffix ("w" weeks, "mo" months, "q" quarters).
    var unit: String = "w"
    /// Major events, drawn as dashed vertical rules (GDD §4.7).
    var events: [ChartEventMark] = []
    /// Optional second series (e.g. debt under cash), drawn as a dashed
    /// line with no area — context, not the hero.
    var secondary: [Double] = []
    var secondaryColor: Color = Theme.loss
    /// Formats a y-axis value ("$1.2M", "4.1★", "82%").
    var format: (Double) -> String = { $0.money }

    private var padded: [Double] {
        guard let first = values.first, values.count < window else { return values }
        return Array(repeating: first, count: window - values.count) + values
    }

    private var paddedSecondary: [Double] {
        guard let first = secondary.first, secondary.count < window else { return secondary }
        return Array(repeating: first, count: window - secondary.count) + secondary
    }

    var body: some View {
        let values = padded
        if values.count < 2 {
            Text("Charts appear after a couple of weeks of play.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Week", index - values.count + 1),
                        y: .value("Value", value),
                        series: .value("Series", "primary")
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                    AreaMark(
                        x: .value("Week", index - values.count + 1),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [color.opacity(0.22), color.opacity(0.01)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                }
                // The companion line rides the same axis, quietly dashed.
                ForEach(Array(paddedSecondary.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Week", index - paddedSecondary.count + 1),
                        y: .value("Value", value),
                        series: .value("Series", "secondary")
                    )
                    .foregroundStyle(secondaryColor.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .interpolationMethod(.monotone)
                }
                // Major events: dashed rules where history turned.
                ForEach(events.filter { $0.offset > Double(1 - values.count) }) { mark in
                    RuleMark(x: .value("Week", mark.offset))
                        .foregroundStyle((mark.negative ? Theme.loss : Theme.profit)
                            .opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                // The "now" marker: where the line meets the present.
                if let last = values.last {
                    PointMark(x: .value("Week", 0), y: .value("Value", last))
                        .foregroundStyle(color)
                        .symbolSize(28)
                }
            }
            // Pin the plot to the data span: Charts otherwise rounds the
            // axis outward (-51 → -60w), leaving a gap and a cliff at the
            // left edge of the area.
            .chartXScale(domain: (1 - values.count)...0)
            .chartYAxis {
                AxisMarks(position: .trailing) { axisValue in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = axisValue.as(Double.self) {
                            Text(format(v))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { axisValue in
                    AxisValueLabel {
                        if let v = axisValue.as(Int.self) {
                            Text(v == 0 ? "now" : "\(v)\(unit)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
    }
}

/// Daily profit bars (green/red) with a revenue line — the P&L's shape at a
/// glance, from the last ~13 weeks of DAILY figures (GDD §23). Days before
/// the airline had history pad LEFT at ZERO and the x-domain is pinned, so
/// the line runs the full width instead of starting mid-air.
struct ProfitChart: View {
    let dailyProfit: [Double]
    let dailyRevenue: [Double]
    var window: Int = 91

    var body: some View {
        if dailyProfit.count < 2 {
            Text("Charts appear after a few days of play.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            let pPad = Array(repeating: 0.0, count: max(0, window - dailyProfit.count))
            let rPad = Array(repeating: 0.0, count: max(0, window - dailyRevenue.count))
            let profits = pPad + dailyProfit.suffix(window)
            let revenues = rPad + dailyRevenue.suffix(window)
            Chart {
                ForEach(Array(profits.enumerated()), id: \.offset) { index, profit in
                    BarMark(
                        x: .value("Day", index - profits.count + 1),
                        y: .value("Profit", profit)
                    )
                    .foregroundStyle(profit >= 0 ? Color.green : Color.red)
                }
                ForEach(Array(revenues.enumerated()), id: \.offset) { index, revenue in
                    LineMark(
                        x: .value("Day", index - revenues.count + 1),
                        y: .value("Revenue", revenue)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                }
            }
            .chartXScale(domain: (1 - profits.count)...0)
            .chartYAxis {
                AxisMarks(position: .trailing) { axisValue in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = axisValue.as(Double.self) {
                            Text(v.money).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
    }
}

/// Compact 0–100% sparkline for a route's recent load factors (daily, GDD §23).
struct LoadFactorSparkline: View {
    let history: [Double]
    var window: Int = 91

    /// Flat-padded like TrendChart: no invented slope before the route existed.
    private var padded: [Double] {
        guard let first = history.first, history.count < window else { return history }
        return Array(repeating: first, count: window - history.count) + history
    }

    var body: some View {
        let history = padded
        if history.count < 2 {
            Text("Fly this route a few days to see its load-factor trend.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Chart(Array(history.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Week", index - history.count + 1),
                    y: .value("Load factor", value)
                )
                .foregroundStyle(.teal)
                .interpolationMethod(.monotone)
                AreaMark(
                    x: .value("Week", index - history.count + 1),
                    y: .value("Load factor", value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.teal.opacity(0.3), .teal.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
            }
            .chartXScale(domain: (1 - history.count)...0)
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 0.5, 1.0]) { axisValue in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = axisValue.as(Double.self) {
                            Text("\(Int(v * 100))%").font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 100)
        }
    }
}

// ── FareCurveChart — the pricing what-if (deepen the fare knob) ──────────

/// Turns fare from a guess into a strategic read: revenue as a function of
/// fare (the hero curve), the player's current fare and the revenue peak
/// marked, with load factor traced as a dashed line so the yield-vs-fill
/// tradeoff is visible. The sim's own economics generate every point.
struct FareCurveChart: View {
    let points: [GameEngine.FarePoint]
    let currentFare: Double
    var accent: Color = Theme.orange
    var height: CGFloat = 120

    var body: some View {
        if points.count >= 2,
           let maxRev = points.map(\.revenue).max(), maxRev > 0,
           let best = points.max(by: { $0.revenue < $1.revenue }) {
            curve(maxRev: maxRev, best: best)
        } else {
            Text("Assign an aircraft and set a schedule to see the pricing curve.")
                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        }
    }

    private func curve(maxRev: Double, best: GameEngine.FarePoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("Fare", p.fare), y: .value("Revenue", p.revenue))
                        .foregroundStyle(.linearGradient(
                            colors: [accent.opacity(0.28), accent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Fare", p.fare), y: .value("Revenue", p.revenue))
                        .foregroundStyle(accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                // Load factor, scaled onto the revenue axis (shape only): it
                // slides down as fare climbs — the fill you trade for yield.
                ForEach(points) { p in
                    LineMark(x: .value("Fare", p.fare),
                             y: .value("Load", p.loadFactor * maxRev),
                             series: .value("Series", "load"))
                        .foregroundStyle(Theme.warn)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .interpolationMethod(.catmullRom)
                }
                RuleMark(x: .value("Fare", currentFare))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .annotation(position: .top, alignment: .center, spacing: 1) {
                        Text("Now").font(.game(.caption2, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                PointMark(x: .value("Fare", best.fare), y: .value("Revenue", best.revenue))
                    .foregroundStyle(Theme.profit)
                    .symbolSize(70)
                    .annotation(position: .top, spacing: 1) {
                        Text("Peak").font(.game(.caption2, weight: .semibold))
                            .foregroundStyle(Theme.profit)
                    }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { v in
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(d.money).font(.game(.caption2))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .frame(height: height)
            // Legend — which line is which.
            HStack(spacing: 14) {
                legendDot(accent, "Revenue")
                legendDot(Theme.warn, "Load factor", dashed: true)
                Spacer()
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: dashed ? 12 : 8, height: 2.5)
                .opacity(dashed ? 0.8 : 1)
            Text(label).font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview("Fare curve") {
    let engine = GameEngine.previewGame()
    let route = engine.openRoute(from: "DEL", to: "GOI", fare: 90, frequency: 7)!
    if let plane = engine.state.fleet.first(where: { $0.status != .onOrder }) {
        engine.assign(aircraftID: plane.id, to: route.id)
    }
    return FareCurveChart(points: engine.fareCurve(routeID: route.id),
                          currentFare: engine.state.routes.first!.fare)
        .padding(20)
        .background(Theme.card)
        .preferredColorScheme(.dark)
}
