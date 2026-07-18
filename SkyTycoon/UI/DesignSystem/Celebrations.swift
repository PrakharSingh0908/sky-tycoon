//
//  Celebrations.swift
//  SkyTycoon — Design system (DESIGN_SYSTEM.md §2.6, v2.1 "Game Feel")
//
//  The loop's wins, made visible: a sliding banner for milestone
//  completions and a quarter-close report card. Pure UI over existing
//  sim state — no engine changes, no perpetual motion.
//

import SwiftUI

// ── CelebrationBanner — a win, announced ─────────────────────────────────

struct CelebrationBanner: View {
    let title: String
    let subtitle: String
    var accent: Color = Theme.warn
    var icon: String = "checkmark.seal.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(Theme.sienna)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.game(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.sienna)
                Text(subtitle)
                    .font(.game(.caption2)).foregroundStyle(Theme.sienna.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.peach, in: RoundedRectangle(cornerRadius: Theme.corner))
        .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
        .padding(.horizontal, Theme.gutter)
    }
}

// ── QuarterReportCard — the quarter close as a moment ────────────────────

struct QuarterReportCard: View {
    @Environment(\.dismiss) private var dismiss
    let letter: QuarterlyLetter
    let quarterProfit: Double
    let streak: Int
    let reputation: Double

    private var grade: (mark: String, color: Color) {
        switch (quarterProfit > 0, streak) {
        case (true, 4...): ("A+", Theme.profit)
        case (true, 3): ("A", Theme.profit)
        case (true, 2): ("B+", Theme.profit)
        case (true, _): ("B", Theme.teal)
        case (false, _): (quarterProfit > -50_000 ? "C" : "D", Theme.warn)
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Quarter closed")
                .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                .padding(.top, 20)

            ZStack {
                Circle().fill(grade.color.opacity(0.12)).frame(width: 92, height: 92)
                Circle()
                    .strokeBorder(Theme.accentGradient(grade.color), lineWidth: 1.5)
                    .frame(width: 92, height: 92)
                Text(grade.mark)
                    .font(.data(.largeTitle, weight: .bold))
                    .foregroundStyle(grade.color)
            }

            VStack(spacing: 10) {
                reportRow("Quarter profit", quarterProfit.money,
                          color: quarterProfit >= 0 ? Theme.profit : Theme.loss)
                reportRow("Profitable streak", "\(streak)/4 quarters",
                          color: streak > 0 ? Theme.profit : Theme.textSecondary)
                HStack {
                    Text("Reputation").font(.game(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    StarRating(rating: reputation, size: 11)
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))

            VStack(alignment: .leading, spacing: 4) {
                Text("From Aunt Meera · \(letter.date.description)")
                    .font(.game(.caption2, weight: .medium)).tracking(1)
                    .foregroundStyle(Theme.sienna)
                Text(letter.body)
                    .font(.system(.caption, design: .serif)).italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .lineLimit(3)
                Text("Full letter on the Money tab")
                    .font(.game(.caption2)).foregroundStyle(Theme.sienna)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.peach.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.corner))

            Button {
                dismiss()
            } label: {
                Text("Back to the airline").frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: grade.color, prominent: true))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bgElevated)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.light)
        .holdsSimClock()
    }

    private func reportRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            TickerText(text: value, font: .game(.subheadline, weight: .bold), color: color)
        }
    }
}

#Preview("Banner") {
    VStack {
        CelebrationBanner(title: "Milestone: Post a profitable week",
                          subtitle: "Reward +$20.0K banked", accent: Theme.profit)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
