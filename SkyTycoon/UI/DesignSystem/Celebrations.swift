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
    /// When set, the banner can be flicked up to dismiss it early.
    var onDismiss: (() -> Void)? = nil
    @State private var dragY: CGFloat = 0

    var body: some View {
        // Machined like the notable cards (MetalPanel): a dark metal face
        // with a white rim highlight — no colored stroke. The icon carries
        // the accent as a polished-silver instrument.
        MetalPanel {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3).polishedSilver()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.game(.subheadline, weight: .medium))
                        .foregroundStyle(Color.white)
                    Text(subtitle)
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .offset(y: dragY)
        .gesture(onDismiss.map { dismiss in
            DragGesture(minimumDistance: 8)
                .onChanged { v in dragY = min(0, v.translation.height) }
                .onEnded { v in
                    if v.translation.height < -24 {
                        withAnimation(.easeOut(duration: 0.2)) { dragY = -160 }
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragY = 0 }
                    }
                }
        })
    }
}

// ── HonorCeremony — the rare, game-defining wins (GDD §38) ───────────────

/// A grand honor to celebrate full-screen: reaching #1, becoming flag carrier.
struct HonorAward: Identifiable {
    let id: String          // "rank1" | "flagCarrier"
    let title: String
    let subtitle: String
    var icon: String { id == "rank1" ? "crown.fill" : "flag.checkered" }
}

/// A full-screen ceremony with a gold medallion that pops in — reserved for
/// the handful of moments that define a whole campaign.
struct HonorCeremonyView: View {
    @Environment(\.dismiss) private var dismiss
    let award: HonorAward
    @State private var appear = false

    private let gold = Color(red: 0.85, green: 0.68, blue: 0.30)

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(gold.opacity(0.14)).frame(width: 168, height: 168)
                    .blur(radius: 12)
                Circle()
                    .fill(LinearGradient(colors: [gold.opacity(0.95),
                                                  gold.opacity(0.45)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 120)
                Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                Image(systemName: award.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
            .scaleEffect(appear ? 1 : 0.55)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 8) {
                Text(award.title)
                    .font(.display(.largeTitle)).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(award.subtitle)
                    .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }
            .opacity(appear ? 1 : 0)

            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Take a bow").frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: gold, prominent: true))
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgElevated)
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
        }
    }
}

// ── QuarterReportCard — the quarter close as a moment ────────────────────

struct QuarterReportCard: View {
    @Environment(\.dismiss) private var dismiss
    let letter: QuarterlyLetter
    let quarterProfit: Double
    let streak: Int
    let reputation: Double
    var auntName: String = "Meera"

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
                Text("From Aunt \(auntName) · \(letter.date.description)")
                    .font(.data(.caption2)).tracking(0.85)
                    .foregroundStyle(Theme.textSecondary)
                Text(letter.body)
                    .font(.system(.caption, design: .serif)).italic()
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .lineLimit(3)
                HStack(alignment: .lastTextBaseline) {
                    Text("Full letter on the Money tab")
                        .font(.game(.caption2)).foregroundStyle(Theme.cornflower)
                    Spacer()
                    // She signs it while you watch.
                    HandwrittenSignature(name: "Aunt \(auntName)", size: 24,
                                         color: Theme.textPrimary.opacity(0.85))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.corner))

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
        .preferredColorScheme(.dark)
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

#Preview("Honor ceremony") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            HonorCeremonyView(award: HonorAward(
                id: "rank1", title: "Top of the Table",
                subtitle: "Aunt Air is the number-one carrier in India. No one flies above you."))
                .environment(GameEngine.previewGame())
        }
        .preferredColorScheme(.dark)
}

#Preview("Banner") {
    VStack {
        CelebrationBanner(title: "Milestone: Post a profitable week",
                          subtitle: "Reward +$20.0K banked", accent: Theme.profit)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
