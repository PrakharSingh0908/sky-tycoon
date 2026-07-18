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
    /// Formats a y-axis value ("$1.2M", "4.1★", "82%").
    var format: (Double) -> String = { $0.money }

    var body: some View {
        if values.count < 2 {
            Text("Charts appear after a couple of weeks of play.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Week", index - values.count + 1),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
                AreaMark(
                    x: .value("Week", index - values.count + 1),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.3), color.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { axisValue in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = axisValue.as(Double.self) {
                            Text(format(v)).font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { axisValue in
                    AxisValueLabel {
                        if let v = axisValue.as(Int.self) {
                            Text(v == 0 ? "now" : "\(v)w").font(.caption2)
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

    var body: some View {
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
