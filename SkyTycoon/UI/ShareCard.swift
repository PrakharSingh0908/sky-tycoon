//
//  ShareCard.swift
//  SkyTycoon — the collectible airline card (GDD §30)
//
//  The one artifact meant to leave the app. Built entirely from the
//  Blueprint design system — Gazette foil + Didot masthead, polished-silver
//  crest, the player's own livery as a cheatline, instrument-well stats —
//  and rendered to an image you'd actually want to show a friend.
//

import SwiftUI

/// Everything the card needs, precomputed so it renders standalone (no
/// environment) — the same value drives the live preview and the export.
struct AirlineCardData {
    let airlineName: String
    let monogram: String
    let adjective: String        // "Indian"
    let year: Int
    let rank: Int
    let total: Int
    let rating: Double
    let fleetCount: Int
    let routeCount: Int
    let netWorth: String
    let marketCap: String
    let bestWeek: String
    let fuselage: Color
    let stripe: Color
    let tail: Color

    var rankLine: String {
        rank <= 1
            ? "The #1 carrier in \(adjective) skies"
            : "Ranked No. \(rank) of \(total) in \(adjective) aviation"
    }
}

/// The card itself. Fixed width so it renders identically live and exported.
struct AirlineCardView: View {
    let data: AirlineCardData
    var width: CGFloat = 320

    // Gazette palette — reused so the card feels of a piece with the paper.
    private static let ink = Color(red: 0.93, green: 0.91, blue: 0.85)
    private static let inkSoft = Color(red: 0.68, green: 0.66, blue: 0.61)
    private static let foil = LinearGradient(
        colors: [Color(red: 1.0, green: 0.98, blue: 0.93),
                 Color(red: 0.80, green: 0.75, blue: 0.66)],
        startPoint: .top, endPoint: .bottom)
    private static func didot(_ size: CGFloat) -> Font { .custom("Didot-Bold", size: size) }

    private func rule(_ opacity: Double = 0.4) -> some View {
        Rectangle().fill(Self.inkSoft.opacity(opacity)).frame(height: 1)
    }

    var body: some View {
        VStack(spacing: 16) {
            masthead
            crest
            nameBlock
            liveryCheatline
            statRow
            recordLine
            footer
        }
        .padding(22)
        .frame(width: width)
        .background(cardFace)
        .overlay(cardBorder)
        .overlay(cornerTicks)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // ── The machined, faintly-lit face the card is printed on ────────────
    private var cardFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(
                LinearGradient(colors: [Color(white: 0.11), Color(white: 0.035)],
                               startPoint: .top, endPoint: .bottom))
            // A soft overhead light, top-center.
            RoundedRectangle(cornerRadius: 20).fill(
                RadialGradient(colors: [data.tail.opacity(0.16), .clear],
                               center: .top, startRadius: 4, endRadius: width * 0.9))
            // A faint diagonal sweep, the way a real card catches light.
            RoundedRectangle(cornerRadius: 20).fill(LinearGradient(
                stops: [.init(color: .white.opacity(0.06), location: 0),
                        .init(color: .clear, location: 0.4)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    // Double border: a foil-warm outer rim and a hairline inner frame.
    private var cardBorder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(colors: [Color(red: 0.86, green: 0.80, blue: 0.66).opacity(0.55),
                                        .black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom), lineWidth: 1)
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                .padding(6)
        }
    }

    // Registration ticks in the airline's tail color — instrument corners.
    private var cornerTicks: some View {
        let inset: CGFloat = 12, len: CGFloat = 12
        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                Tick(len: len)
                    .stroke(data.tail.opacity(0.8), lineWidth: 1.5)
                    .frame(width: len, height: len)
                    .rotationEffect(.degrees(Double(i) * 90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: [.topLeading, .topTrailing, .bottomTrailing, .bottomLeading][i])
                    .padding(inset)
            }
        }
    }
    private struct Tick: Shape {
        let len: CGFloat
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY + len))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + len, y: r.minY))
            return p
        }
    }

    // ── Sections ─────────────────────────────────────────────────────────
    private var masthead: some View {
        HStack(spacing: 8) {
            rule()
            Text("SKYTYCOON").font(Self.didot(12)).tracking(1.6)
                .foregroundStyle(Self.ink).fixedSize()
            rule()
        }
    }

    private var crest: some View {
        Text(data.monogram)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.55)],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: .white.opacity(0.5), radius: 5)
            .frame(width: 82, height: 82)
            .background(Circle().fill(LinearGradient(
                colors: [Color(white: 0.24), Color(white: 0.08)],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(LinearGradient(
                colors: [data.tail.opacity(0.9), data.tail.opacity(0.2)],
                startPoint: .top, endPoint: .bottom), lineWidth: 2))
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1).padding(3))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }

    private var nameBlock: some View {
        VStack(spacing: 6) {
            Text(data.airlineName)
                .font(Self.didot(34))
                .foregroundStyle(Self.foil)
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text(data.rankLine)
                .font(.system(size: 13, design: .serif)).italic()
                .foregroundStyle(Self.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
    }

    // The airline's paint, as a slim three-band cheatline down the card.
    private var liveryCheatline: some View {
        HStack(spacing: 3) {
            Capsule().fill(data.fuselage).frame(height: 4)
            Capsule().fill(data.stripe).frame(width: 40, height: 4)
            Capsule().fill(data.tail).frame(width: 22, height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private var statRow: some View {
        HStack(spacing: 8) {
            stat("FLEET", "\(data.fleetCount)")
            stat("ROUTES", "\(data.routeCount)")
            stat("RATING", String(format: "%.1f★", data.rating))
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                .foregroundStyle(Self.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }

    private var recordLine: some View {
        HStack {
            valueTile("NET WORTH", data.netWorth)
            valueTile("MARKET CAP", data.marketCap)
        }
    }

    private func valueTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                .foregroundStyle(Self.inkSoft)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(Self.foil)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(data.tail.opacity(0.35), lineWidth: 1))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            rule(0.3)
            Text(data.airlineName)
                .font(.handwriting(24))
                .foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("Founded Y\(data.year) · best week \(data.bestWeek)")
                .font(.system(size: 10, design: .serif)).italic()
                .foregroundStyle(Self.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

// ── Presentation: preview the card, then share it ────────────────────────

struct ShareCardSheet: View {
    let data: AirlineCardData
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any]?
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("YOUR AIRLINE").font(.data(.caption2)).tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.game(.subheadline)).foregroundStyle(Theme.cornflower)
            }
            Spacer(minLength: 0)
            AirlineCardView(data: data)
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            Spacer(minLength: 0)
            Button {
                shareCard()
            } label: {
                Label("Share card", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: Theme.cornflower, prominent: true))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgElevated)
        .presentationDetents([.large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
        .sheet(isPresented: $showShare) {
            if let shareItems { ActivityView(items: shareItems) }
        }
    }

    @MainActor private func shareCard() {
        let renderer = ImageRenderer(content: AirlineCardView(data: data).padding(16)
            .background(Theme.bg))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        let caption = "\(data.airlineName): \(data.rankLine). Built in SkyTycoon. ✈︎"
        shareItems = [image, caption]
        showShare = true
    }
}

/// Thin bridge to the system share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview("Airline card") {
    AirlineCardView(data: AirlineCardData(
        airlineName: "Cirrus Air", monogram: "CA", adjective: "Indian",
        year: 6, rank: 7, total: 55, rating: 4.3, fleetCount: 14, routeCount: 9,
        netWorth: "$18.4M", marketCap: "$96.2M", bestWeek: "$1.2M",
        fuselage: Color(red: 0.93, green: 0.94, blue: 0.96),
        stripe: Color(red: 0.10, green: 0.18, blue: 0.32),
        tail: Color(red: 0.25, green: 0.84, blue: 0.79)))
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
}
