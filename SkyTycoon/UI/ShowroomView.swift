//
//  ShowroomView.swift
//  SkyTycoon — UI (orange accent)
//
//  Three acquisition paths as chip-switched offer cards (GDD §4.1,
//  DESIGN_SYSTEM.md §4).
//

import SwiftUI

/// What just happened at the counter — feeds the confirmation sheet.
struct AcquisitionReceipt: Identifiable {
    enum Kind { case ordered, bought, leased }
    let id = UUID()
    let kind: Kind
    let type: AircraftType
    let nickname: String
    let amount: Double          // price paid, or weekly lease payment
    let deliveryWeeks: Int?     // .ordered only
}

struct ShowroomView: View {
    @Environment(GameEngine.self) private var engine
    /// When shopping for a specific route, every offer shows whether the
    /// airframe can actually fly it (payload-corrected range + runways).
    var fittingRoute: Route? = nil
    @State private var tab: Tab
    @State private var receipt: AcquisitionReceipt?
    private let accent = Theme.orange

    init(fittingRoute: Route? = nil, initialTab: Tab = .used) {
        self.fittingRoute = fittingRoute
        _tab = State(initialValue: initialTab)
    }

    /// Fit verdict for an archetype against the target route, using the
    /// standard cabin's payload-corrected range — the same rules as
    /// canOperate, evaluated before the plane exists.
    private func fitBadge(for type: AircraftType) -> (text: String, good: Bool)? {
        guard let route = fittingRoute,
              let origin = engine.city(route.originID),
              let dest = engine.city(route.destinationID) else { return nil }
        let spec = Balance.specs[type]!
        let effectiveRange = spec.rangeKm
            * CabinLayout.standard(abreast: spec.seatsAbreast).rangeFactor(spec: spec)
        if effectiveRange < route.distanceKm {
            return ("Beyond range for \(route.originID) ✈︎ \(route.destinationID)", false)
        }
        if origin.runwayClass < spec.requiredRunwayClass
            || dest.runwayClass < spec.requiredRunwayClass {
            return ("Runway too short at \(origin.runwayClass < spec.requiredRunwayClass ? route.originID : route.destinationID)", false)
        }
        return ("Fits \(route.originID) ✈︎ \(route.destinationID)", true)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case new = "New", used = "Used", lease = "Lease"
        var id: String { rawValue }
    }

    var body: some View {
        GameScreen(title: "Showroom", accent: accent) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases) { t in
                    Button(t.rawValue) { tab = t }
                        .buttonStyle(GameButtonStyle(color: accent, prominent: tab == t))
                }
                Spacer()
            }
            switch tab {
            case .new: newCards
            case .used: usedCards
            case .lease: leaseCards
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bgElevated, for: .navigationBar)
        .sheet(item: $receipt) { AcquisitionReceiptView(receipt: $0) }
        .sensoryFeedback(.success, trigger: receipt?.id) { _, new in new != nil }
    }

    /// The §22 lock: the metal is visible (aspiration), the buy path is
    /// not. Swallows taps and names the requirement.
    @ViewBuilder private func lockPlate(for type: AircraftType) -> some View {
        let tier = Balance.fleetTier(of: type)
        RoundedRectangle(cornerRadius: Theme.corner)
            .fill(Theme.bg.opacity(0.74))
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textSecondary)
                    Text(Balance.fleetTierNames[tier])
                        .font(.game(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Unlocks at \(Balance.fleetTierThresholds[tier].money) market cap")
                        .font(.data(.caption2)).tracking(0.85)
                        .foregroundStyle(Theme.textSecondary)
                }
            )
    }

    // ── New: full price, delivery wait ───────────────────────────────────

    @ViewBuilder private var newCards: some View {
        Text("Cash up front, delivered in 8 to 24 weeks.")
            .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
        ForEach(AircraftType.allCases) { type in
            let spec = Balance.specs[type]!
            let discount = engine.loyaltyDiscount(seller: spec.seller)
            let price = engine.discountedPrice(for: type)
            let locked = !engine.isUnlocked(type)
            GameCard {
                offerHeader(type: type, specs: [
                    ("Seats", "\(spec.maxSeats)"),
                    ("Range", "\(Int(spec.rangeKm)) km"),
                    ("Cruise", "\(Int(spec.cruiseKmh)) km/h"),
                    ("Delivery", "\(Balance.deliveryWeeks[type]!) wk"),
                ])
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        TickerText(text: price.money,
                                   font: .game(.title3, weight: .semibold))
                        HStack(spacing: 6) {
                            if discount > 0 {
                                Text(spec.purchasePrice.money)
                                    .font(.game(.caption2)).strikethrough()
                                    .foregroundStyle(Theme.textTertiary)
                                Text("loyalty −\(Int(discount * 100))%")
                                    .font(.game(.caption2)).foregroundStyle(Theme.profit)
                            } else {
                                Text("Cash up front")
                                    .font(.game(.caption2)).foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    Spacer()
                    Button("Order") {
                        let nickname = nextNickname()
                        if engine.orderNewAircraft(type: type, nickname: nickname,
                                                   forRoute: fittingRoute?.id) {
                            receipt = AcquisitionReceipt(kind: .ordered, type: type,
                                nickname: nickname, amount: price,
                                deliveryWeeks: Balance.deliveryWeeks[type]!)
                        }
                    }
                    .buttonStyle(GameButtonStyle(color: accent, prominent: true))
                    .disabled(engine.state.cash < price)
                    .opacity(engine.state.cash < price ? 0.4 : 1)
                }
            }
            .overlay { if locked { lockPlate(for: type) } }
        }
    }

    // ── Used: rotating seeded listings ───────────────────────────────────

    @ViewBuilder private var usedCards: some View {
        Text("Instant delivery, condition as listed. Market refreshes in \(engine.state.weeksUntilMarketRefresh) wk.")
            .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
        if engine.state.usedMarket.isEmpty {
            GameCard {
                Text("Nothing on the market this week.")
                    .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            }
        }
        ForEach(engine.state.usedMarket) { listing in
            let spec = Balance.specs[listing.type]!
            let locked = !engine.isUnlocked(listing.type)
            GameCard {
                offerHeader(type: listing.type, specs: [
                    ("Seats", "\(spec.maxSeats)"),
                    ("Range", "\(Int(spec.rangeKm)) km"),
                    ("Age", String(format: "%.1fy", listing.ageYears)),
                    ("Delivery", "Now"),
                ])
                MeterRow(label: "Condition", value: listing.condition / 100,
                         display: "\(Int(listing.condition))/100",
                         color: Theme.health(listing.condition / 100))
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        TickerText(text: listing.price.money,
                                   font: .game(.title3, weight: .semibold))
                        Text("As-is, where-is")
                            .font(.game(.caption2)).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Button("Buy") {
                        let nickname = nextNickname()
                        if engine.buyUsedAircraft(listingID: listing.id, nickname: nickname,
                                                  forRoute: fittingRoute?.id) {
                            receipt = AcquisitionReceipt(kind: .bought, type: listing.type,
                                nickname: nickname, amount: listing.price, deliveryWeeks: nil)
                        }
                    }
                    .buttonStyle(GameButtonStyle(color: accent, prominent: true))
                    .disabled(engine.state.cash < listing.price)
                    .opacity(engine.state.cash < listing.price ? 0.4 : 1)
                }
            }
            .overlay { if locked { lockPlate(for: listing.type) } }
        }
    }

    // ── Lease: instant, no capital, forever ──────────────────────────────

    @ViewBuilder private var leaseCards: some View {
        Text("Instant delivery, no capital outlay.")
            .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
        ForEach(AircraftType.allCases) { type in
            let spec = Balance.specs[type]!
            let weekly = spec.purchasePrice * Balance.leaseRatePerWeek
            let locked = !engine.isUnlocked(type)
            GameCard {
                offerHeader(type: type, specs: [
                    ("Seats", "\(spec.maxSeats)"),
                    ("Range", "\(Int(spec.rangeKm)) km"),
                    ("Return fee", (weekly * Balance.leaseTerminationWeeks).money),
                    ("Delivery", "Now"),
                ])
                TickerText(text: "\(weekly.money)/wk",
                           font: .game(.title3, weight: .semibold))
                SlideKey(label: "Slide to lease") {
                    let nickname = nextNickname()
                    if engine.leaseAircraft(type: type, nickname: nickname,
                                            forRoute: fittingRoute?.id) {
                        receipt = AcquisitionReceipt(kind: .leased, type: type,
                            nickname: nickname, amount: weekly, deliveryWeeks: nil)
                    }
                }
            }
            .overlay { if locked { lockPlate(for: type) } }
        }
    }

    /// Spec-sheet header: photo hero, name + fit verdict, then a mono
    /// spec strip — the numbers a buyer compares, not a sentence.
    private func offerHeader(type: AircraftType, specs: [(String, String)]) -> some View {
        let spec = Balance.specs[type]!
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.displayName)
                        .font(.game(.headline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("SOLD BY \(spec.seller.uppercased())")
                        .font(.data(.caption2)).tracking(0.85)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if let fit = fitBadge(for: type) {
                    StatusBadge(text: fit.text, color: fit.good ? Theme.profit : Theme.loss)
                }
            }
            // Showroom planes wear factory paint — yours get the livery
            // once they join the fleet.
            AircraftPhotoView(type: type)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                ForEach(specs, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        TickerText(text: item.1,
                                   font: .game(.subheadline, weight: .medium))
                        Text(item.0)
                            .font(.game(.caption2)).foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Divider().overlay(Theme.hairline)
        }
    }

    /// Registration-style nicknames from the airline's initials:
    /// "Blue Dart" → BD-A, BD-B, …
    private func nextNickname() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let n = engine.state.fleet.count
        let letter = letters[letters.index(letters.startIndex, offsetBy: n % 26)]
        return "\(engine.fleetPrefix)-\(letter)\(n / 26 == 0 ? "" : String(n / 26))"
    }
}

// ── The delivery receipt — confirmation after any acquisition ────────────

private struct AcquisitionReceiptView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let receipt: AcquisitionReceipt
    /// Measured content height → the sheet's detent, so the sheet fits the
    /// receipt exactly: nothing cropped, nothing to scroll. The ScrollView
    /// stays purely as a safety net for very small screens / huge type.
    @State private var contentHeight: CGFloat = 620

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.profit.opacity(0.15)).frame(width: 64, height: 64)
                // Fit, don't font-size: wide glyphs like "signature" overflow
                // the disc when sized by point size.
                Image(systemName: icon)
                    .resizable().scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Theme.profit)
            }
            .padding(.top, 12)

            VStack(spacing: 4) {
                Text(title).font(.display(.title2))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Balance.specs[receipt.type]!.displayName) · registered \(receipt.nickname)")
                    .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            }

            // Ordered planes show factory paint until delivery day.
            AircraftPhotoView(type: receipt.type,
                              livery: receipt.kind == .ordered ? nil : engine.state.livery)
                .frame(height: 96)

            VStack(spacing: 8) {
                receiptRow(amountLabel, receipt.amount.money + (receipt.kind == .leased ? "/wk" : ""))
                receiptRow("Arrival", arrivalText)
                if receipt.kind == .leased {
                    let fee = receipt.amount * Balance.leaseTerminationWeeks
                    receiptRow("Return anytime", "fee \(fee.money)")
                }
                Divider().overlay(Theme.hairline)
                HStack {
                    Text("Cash remaining").font(.game(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    TickerText(text: engine.state.cash.money,
                               font: .game(.subheadline, weight: .bold),
                               color: engine.state.cash >= 0 ? Theme.profit : Theme.loss)
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            Button("Done") { dismiss() }
                .buttonStyle(GameButtonStyle(color: Theme.orange, prominent: true))
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
        .modifier(ReceiptScroll())
        .background(Theme.bgElevated)
        // The sheet fits the measured receipt (+ home-indicator inset); the
        // system clamps to screen height if it can't, then ScrollView takes
        // over. Nothing crops in either case.
        .presentationDetents([.height(contentHeight + 34)])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
    }

    /// Hosts the receipt in a top-anchored scroll view; bounce only when
    /// content actually exceeds the detent.
    private struct ReceiptScroll: ViewModifier {
        func body(content: Content) -> some View {
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private var title: String {
        switch receipt.kind {
        case .ordered: "Order placed"
        case .bought: "Welcome to the fleet"
        case .leased: "Lease signed"
        }
    }

    private var icon: String {
        switch receipt.kind {
        case .ordered: "clock.badge.checkmark.fill"
        case .bought: "checkmark.seal.fill"
        case .leased: "signature"
        }
    }

    private var amountLabel: String {
        switch receipt.kind {
        case .ordered, .bought: "Paid"
        case .leased: "Weekly lease"
        }
    }

    private var arrivalText: String {
        if let weeks = receipt.deliveryWeeks {
            return "arrives in \(weeks) weeks"
        }
        return "in your hangar now"
    }

    private func receiptRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.game(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

#Preview("Fit badges") {
    let engine = GameEngine.newGame(airlineName: "Preview Air", country: .india, seed: 9)
    let route = engine.openRoute(from: "DEL", to: "GOI", fare: 90, frequency: 7)!
    return NavigationStack {
        ShowroomView(fittingRoute: route)
    }
    .environment(engine)
    .preferredColorScheme(.dark)
}

#Preview("Receipt") {
    // Leased: the "signature" glyph is the widest icon — the crop stress case.
    AcquisitionReceiptView(receipt: AcquisitionReceipt(
        kind: .leased, type: .propeller28, nickname: "VT-C",
        amount: Balance.specs[.propeller28]!.purchasePrice * Balance.leaseRatePerWeek,
        deliveryWeeks: nil))
        .environment(GameEngine.previewGame())
}

#Preview("Receipt in sheet") {
    // The detent stress case: the receipt presented as a real sheet, the
    // way players see it — regressions crop here, not in the flat preview.
    Theme.bg.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            AcquisitionReceiptView(receipt: AcquisitionReceipt(
                kind: .leased, type: .turboprop12, nickname: "VT-D",
                amount: Balance.specs[.turboprop12]!.purchasePrice * Balance.leaseRatePerWeek,
                deliveryWeeks: nil))
        }
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

// Slide-to-commit pin: the lease deal signs with a throw, not a tap.
#Preview("Lease tab") {
    NavigationStack {
        ShowroomView(initialTab: .lease)
            .environment(GameEngine.newGame(airlineName: "Foundation Air",
                                            country: .us, seed: 7))
    }
    .preferredColorScheme(.dark)
}

// §22 regression pin: tier 0 sees the metal but not the buy path.
#Preview("Locked showroom") {
    NavigationStack {
        ShowroomView()
            .environment(GameEngine.newGame(airlineName: "Foundation Air",
                                            country: .us, seed: 7))
    }
    .preferredColorScheme(.dark)
}
