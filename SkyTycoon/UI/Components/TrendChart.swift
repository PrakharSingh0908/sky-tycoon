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
    /// Formats a y-axis value ("$1.2M", "4.1★", "82%").
    var format: (Double) -> String = { $0.money }

    private var padded: [Double] {
        guard let first = values.first, values.count < window else { return values }
        return Array(repeating: first, count: window - values.count) + values
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
                        y: .value("Value", value)
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

/// Weekly profit bars (green/red) with a revenue line — the P&L's shape
/// at a glance, from the last 52 weekly reports.
struct ProfitChart: View {
    let reports: [WeeklyReport]

    var body: some View {
        if reports.count < 2 {
            Text("Charts appear after a couple of weeks of play.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart(Array(reports.enumerated()), id: \.offset) { index, report in
                BarMark(
                    x: .value("Week", index - reports.count + 1),
                    y: .value("Profit", report.profit)
                )
                .foregroundStyle(report.profit >= 0 ? Color.green : Color.red)
                LineMark(
                    x: .value("Week", index - reports.count + 1),
                    y: .value("Revenue", report.revenue)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
            }
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

/// Compact 0–100% sparkline for a route's recent load factors.
struct LoadFactorSparkline: View {
    let history: [Double]
    var window: Int = 26

    /// Flat-padded like TrendChart: no invented slope before the route existed.
    private var padded: [Double] {
        guard let first = history.first, history.count < window else { return history }
        return Array(repeating: first, count: window - history.count) + history
    }

    var body: some View {
        let history = padded
        if history.count < 2 {
            Text("Fly this route a few weeks to see its load-factor trend.")
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
