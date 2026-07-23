//
//  RoutesView.swift
//  SkyTycoon — UI (teal accent)
//
//  Route cards with live load-factor meters and profit tickers; detail
//  screen with sparkline, pill-steppers, and assignment
//  (DESIGN_SYSTEM.md §4).
//

import SwiftUI

struct RoutesView: View {
    @Environment(GameEngine.self) private var engine
    @State private var planning = false
    private let accent = Theme.teal

    /// Airports your network touches (route endpoints, deduped).
    private var servedAirports: Int {
        Set(engine.state.routes.flatMap { [$0.originID, $0.destinationID] }).count
    }

    var body: some View {
        NavigationStack {
            GameScreen(title: "Routes", accent: accent) {
                // ── The network: eyebrow with live counts, then the globe ─
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionHeader(title: "Network", icon: "globe.asia.australia.fill",
                                      accent: accent)
                        Spacer()
                        Text("\(engine.state.routes.count) RTE · \(servedAirports) APT")
                            .font(.data(.caption2)).tracking(0.85)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    RouteMapView()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        .overlay(RoundedRectangle(cornerRadius: Theme.corner)
                            .strokeBorder(Theme.hairline, lineWidth: 1))
                }

                // The desk's one bright key, right where the map ends —
                // not buried below every pass.
                Button {
                    planning = true
                } label: {
                    Label("Plan a new route", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: accent, prominent: true))

                // ── The passes, under their own eyebrow ───────────────────
                if engine.state.routes.isEmpty {
                    Text("No routes yet. Every airline starts with one good pair.")
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                } else {
                    SectionHeader(title: "Boarding passes", icon: "ticket.fill",
                                  accent: accent)
                        .padding(.top, 6)
                    // Most-earning route first, so the money leaders lead.
                    ForEach(engine.state.routes.sorted { $0.lastWeeklyProfit > $1.lastWeeklyProfit }) { route in
                        BoardingPassCard(route: route,
                            originName: engine.city(route.originID)?.name ?? route.originID,
                            destName: engine.city(route.destinationID)?.name ?? route.destinationID,
                            accent: accent)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $planning) { NewRouteSheet() }
        }
    }
}

// ── The route desk: pick an origin, see every market ranked ──────────────
// Replaces two dropdowns with a prospectus: destinations sorted by
// estimated demand (the sim's own gravity formula), each row carrying
// distance, demand, runway class, and slots — decide, tap, flying.

struct NewRouteSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var origin = ""
    private let accent = Theme.teal

    /// Defaults to the country's first (largest) airport.
    private var effectiveOrigin: String {
        origin.isEmpty ? (engine.state.cities.first?.id ?? "") : origin
    }

    private struct Prospect: Identifiable {
        let city: City
        let distanceKm: Double
        let demand: Double
        var id: String { city.id }
    }

    private var prospects: [Prospect] {
        engine.state.cities
            .filter { $0.id != effectiveOrigin }
            .map { city in
                let dist = Balance.distance(effectiveOrigin, city.id)
                guard let from = engine.city(effectiveOrigin) else {
                    return Prospect(city: city, distanceKm: dist, demand: 0)
                }
                // The sim's gravity term (computeEconomics uses the same
                // form), so ranking here matches what the route will earn.
                let level = Balance.countryProfiles[engine.state.country]!.demandLevel
                let demand = Balance.demandK * level
                    * pow(from.population * city.population, 0.55)
                    / pow(max(dist, 100), 0.35)
                return Prospect(city: city, distanceKm: dist, demand: demand)
            }
            .sorted { $0.demand > $1.demand }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("New route")
                        .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.07), in: Circle())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)

                // Origin: one tap per airport, slots shown for the pick.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(engine.state.cities) { city in
                            Button(city.id) { origin = city.id }
                                .buttonStyle(GameButtonStyle(color: accent,
                                                             prominent: effectiveOrigin == city.id))
                        }
                    }
                }
                .fadeEdge(.trailing, length: 16, color: Theme.bgElevated)
                Text("From \(engine.city(effectiveOrigin)?.name ?? effectiveOrigin) · \(engine.freeSlots(at: effectiveOrigin)) free slots")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)

                VStack(spacing: 8) {
                    ForEach(prospects) { prospect in
                        prospectRow(prospect)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.bgElevated)
        .presentationDetents([.large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
    }

    @ViewBuilder private func prospectRow(_ prospect: Prospect) -> some View {
        let existing = engine.state.routes.contains {
            ($0.originID == effectiveOrigin && $0.destinationID == prospect.city.id) ||
            ($0.destinationID == effectiveOrigin && $0.originID == prospect.city.id)
        }
        let hasSlots = engine.freeSlots(at: effectiveOrigin) > 0
            && engine.freeSlots(at: prospect.city.id) > 0
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(prospect.city.id)
                        .font(.game(.headline, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text(prospect.city.name)
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
                let rivals = engine.city(effectiveOrigin).map {
                    Balance.competitorCount($0, prospect.city)
                } ?? 0
                Text("\(Int(prospect.distanceKm)) km · ~\(Int(prospect.demand)) pax/wk · \(rivals == 0 ? "no rivals" : "\(rivals) rival\(rivals == 1 ? "" : "s")") · class \(prospect.city.runwayClass)")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            if existing {
                StatusBadge(text: "Flying", color: Theme.profit)
            } else if !hasSlots {
                StatusBadge(text: "No slots", color: Theme.warn)
            } else {
                Button("Open") {
                    let dist = prospect.distanceKm
                    let fareLevel = Balance.countryProfiles[engine.state.country]!.fareLevel
                    _ = engine.openRoute(from: effectiveOrigin, to: prospect.city.id,
                        fare: dist * Balance.referenceFarePerKm * fareLevel,
                        frequency: 7)
                    // The drawer's one job is done — get out of the way so the
                    // player lands back on the map with the new route drawn.
                    dismiss()
                }
                .buttonStyle(GameButtonStyle(color: accent, prominent: true))
            }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }
}

#Preview("Assign, busy elsewhere") {
    let engine = GameEngine.previewGame()
    return NavigationStack {
        // Route 1 (BOM–BLR) is unassigned; VT-A is busy on DEL–BOM.
        RouteDetailView(routeID: engine.state.routes[1].id)
    }
    .environment(engine)
    .preferredColorScheme(.dark)
}

#Preview("Assign, empty fleet") {
    let engine = GameEngine.newGame(airlineName: "Preview Air", country: .india, seed: 9)
    let route = engine.openRoute(from: "DEL", to: "GOI", fare: 90, frequency: 7)!
    return NavigationStack {
        RouteDetailView(routeID: route.id)
    }
    .environment(engine)
    .preferredColorScheme(.dark)
}

#Preview {
    RoutesView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
#Preview("Route detail") {
    let engine = GameEngine.previewGame()
    return NavigationStack {
        RouteDetailView(routeID: engine.state.routes[0].id)
    }
    .environment(engine)
    .preferredColorScheme(.dark)
}

/// A route rendered as a flight ticket (DESIGN_SYSTEM.md v1.1): big airport
/// codes, a plane on a dotted path, punched perforation, and a stub with
/// the numbers that matter.
private struct BoardingPassCard: View {
    @Environment(GameEngine.self) private var engine
    let route: Route
    let originName: String
    let destName: String
    let accent: Color
    @State private var confirmingCancel = false
    @State private var showingAircraft = false
    @State private var clockToken = UUID()

    private let stubHeight: CGFloat = 124

    var body: some View {
        NavigationLink {
            RouteDetailView(routeID: route.id)
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
    }

    /// The whole ticket is the tap target (opens the route detail); the
    /// inner controls — cancel, the aircraft disclosure — capture their own
    /// taps, so nothing dead-ends.
    private var cardBody: some View {
        VStack(spacing: 0) {
            // ── The flight ───────────────────────────────────────────────
            HStack(alignment: .center, spacing: 12) {
                codeBlock(code: route.originID, city: originName, alignment: .leading)
                flightPath
                codeBlock(code: route.destinationID, city: destName, alignment: .trailing)
            }
            .padding(Theme.cardPadding)
            .padding(.vertical, 2)

            // ── Who's flying it: lives ABOVE the perforation because the
            // stub is fixed-height (the ticket notches depend on it).
            aircraftDropdown

            PerforationLine().padding(.horizontal, 13)   // meets the punches

            // ── The stub: LIVE projection from current settings ──────────
            // (Immediacy rule: touch a lever anywhere and these move NOW;
            // money still settles weekly.)
            VStack(spacing: 10) {
                let econ = engine.routeEconomics(routeID: route.id)
                let projLF = econ?.loadFactor ?? route.lastLoadFactor
                let projMargin = econ.map { $0.revenue - $0.fuel } ?? route.lastWeeklyProfit
                MeterRow(label: "Load factor", value: projLF,
                         color: Theme.health(projLF))
                HStack {
                    Text("on-time \(Int(route.lastPunctuality * 100))%")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    TickerText(text: projMargin.money + "/wk",
                               font: .game(.subheadline, weight: .bold),
                               color: projMargin >= 0 ? Theme.profit : Theme.loss)
                }
                Button(role: .destructive) {
                    confirmingCancel = true
                } label: {
                    Text("Cancel route").frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(finish: .obsidian))
            }
            .padding(.horizontal, Theme.cardPadding)
            .frame(height: stubHeight)
            .onChange(of: confirmingCancel) { _, showing in
                // Dialogs have no content lifecycle — hold the clock manually
                // via a stable token (idempotent, cannot leak).
                if showing { engine.beginInteraction(clockToken) }
                else { engine.endInteraction(clockToken) }
            }
            .confirmationDialog(
                "Cancel \(route.originID) ✈︎ \(route.destinationID)? Assigned aircraft go idle and the fares and schedule are lost.",
                isPresented: $confirmingCancel, titleVisibility: .visible
            ) {
                Button("Cancel route", role: .destructive) {
                    engine.closeRoute(routeID: route.id)
                }
                Button("Keep flying", role: .cancel) {}
            }
        }
        .background(
            TicketShape(notchFromBottom: stubHeight)
                .fill(Theme.card, style: FillStyle(eoFill: true))
        )
        .overlay(
            TicketShape(notchFromBottom: stubHeight)
                .stroke(Theme.hairline, style: StrokeStyle(lineWidth: 1))
        )
        // The card's own shadow bleeds through the punched holes as a dark
        // ring; cap each punch with a clean screen-background disc.
        .overlay {
            GeometryReader { geo in
                let y = geo.size.height - stubHeight
                Circle().fill(Theme.bg).frame(width: 20, height: 20)
                    .position(x: 0, y: y)
                Circle().fill(Theme.bg).frame(width: 20, height: 20)
                    .position(x: geo.size.width, y: y)
            }
            .allowsHitTesting(false)
        }
    }

    /// The aircraft actively serving this route, collapsible.
    @ViewBuilder private var aircraftDropdown: some View {
        let assigned = engine.state.fleet.filter { $0.assignedRouteID == route.id }
        if !assigned.isEmpty {
            DisclosureGroup(isExpanded: $showingAircraft) {
                VStack(spacing: 6) {
                    ForEach(assigned) { plane in
                        aircraftRow(plane)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Aircraft on this route (\(assigned.count))", systemImage: "airplane")
                    .font(.game(.caption, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .tint(Theme.textSecondary)
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 10)
        }
    }

    private func aircraftRow(_ plane: Aircraft) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane").font(.caption2).foregroundStyle(accent)
            Text(plane.nickname)
                .font(.game(.caption, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            // The onboard rating for this aircraft (GDD §40).
            StarRating(rating: plane.serviceRating, size: 8)
            Spacer()
            if plane.groundedWeeksRemaining > 0 {
                StatusBadge(text: "In shop · \(plane.groundedWeeksRemaining) wk", color: Theme.warn)
            } else {
                let lf = engine.routeEconomics(routeID: route.id)?.loadFactor
                    ?? route.lastLoadFactor
                TickerText(text: "LF \(Int(lf * 100))%",
                           font: .game(.caption2, weight: .semibold),
                           color: Theme.health(lf))
            }
        }
    }

    private func codeBlock(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-1.0)
                .foregroundStyle(Theme.textPrimary)
            Text(city)
                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
    }

    private var flightPath: some View {
        VStack(spacing: 3) {
            ZStack {
                PerforationLine()
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 5)
                    .background(Theme.card)
            }
            Text("\(Int(route.distanceKm)) km · \(route.weeklyFrequency)×/wk")
                .font(.game(.caption2, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RouteDetailView: View {
    @Environment(GameEngine.self) private var engine
    let routeID: UUID
    /// The quick-add drawer: a route-aware showroom; buys land on this route.
    @State private var shoppingForRoute: Route?
    /// The poaching pool stays folded until someone goes looking.
    @State private var showOtherRoutes = false
    /// A tapped aircraft opens an action drawer: assign / move / take off,
    /// plus send it for a check (service a worn one right here).
    @State private var servicing: Aircraft?
    @State private var clockToken = UUID()
    private let accent = Theme.teal

    var body: some View {
        if let route = engine.state.routes.first(where: { $0.id == routeID }) {
            GameScreen(title: "\(route.originID) ✈︎ \(route.destinationID)", accent: accent) {
                RouteMapView(focusRouteID: routeID)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                GameCard {
                    SectionHeader(title: "Load factor · 13 weeks", icon: "chart.xyaxis.line", accent: accent)
                    LoadFactorSparkline(history: route.loadFactorHistory)
                }
                assignCard(route)
                GameCard {
                    SectionHeader(title: "Economics", icon: "slider.horizontal.3", accent: accent)
                    // Fare and schedule lead the card (the levers you reach
                    // for most); the read-outs follow below.
                    PillStepper(label: "Fare", value: route.fare.money, accent: accent,
                        onDecrement: { engine.setFare(routeID: routeID, fare: route.fare - 5) },
                        onIncrement: { engine.setFare(routeID: routeID, fare: route.fare + 5) })
                    PillStepper(label: "Flights/week", value: "\(route.weeklyFrequency)", accent: accent,
                        onDecrement: { engine.setFrequency(routeID: routeID, frequency: route.weeklyFrequency - 1) },
                        onIncrement: { engine.setFrequency(routeID: routeID, frequency: route.weeklyFrequency + 1) })
                    Divider().overlay(Theme.hairline)
                    // Projected LF: moves the instant fare/frequency/
                    // assignment change (immediacy rule).
                    let projLF = engine.routeEconomics(routeID: routeID)?.loadFactor
                        ?? route.lastLoadFactor
                    HStack(spacing: 20) {
                        StatTile(label: "Distance", value: "\(Int(route.distanceKm)) km")
                        StatTile(label: "Proj. load factor", value: "\(Int(projLF * 100))%",
                                 color: Theme.health(projLF))
                        StatTile(label: "On-time", value: "\(Int(route.lastPunctuality * 100))%",
                                 color: Theme.health(route.lastPunctuality))
                    }
                    // The pair's market (GDD §21): who's flying it, who the
                    // passengers are, and how much of the pie you hold.
                    if let econ = engine.routeEconomics(routeID: routeID) {
                        Divider().overlay(Theme.hairline)
                        HStack(spacing: 20) {
                            StatTile(label: "Demand",
                                     value: "~\(Int(econ.demand)) pax")
                            StatTile(label: "Rivals",
                                     value: econ.competitors == 0
                                        ? "None" : "\(econ.competitors)",
                                     color: econ.competitors == 0
                                        ? Theme.profit : Theme.textPrimary)
                            StatTile(label: "Your share",
                                     value: "\(Int(econ.captureShare * 100))%",
                                     color: Theme.health(econ.captureShare))
                        }
                        if econ.competitors > 0 && econ.captureShare < 0.4 {
                            Text("Passengers are choosing your rivals. Comfort, fair fares, and satisfaction win them back.")
                                .font(.game(.caption2)).foregroundStyle(Theme.warn)
                        }
                        // Market maturity & over-supply (GDD §26 Pillar 2).
                        if econ.maturity < 0.99 {
                            Text("New route: the market is still building, near \(Int(econ.maturity * 100))% of full demand. It fills in over the first \(Balance.routeRampWeeks) weeks.")
                                .font(.game(.caption2)).foregroundStyle(accent)
                        }
                        if econ.oversupplyYield < 0.995 {
                            Text("Over-supplied: too many seats for the demand, so fares dilute about \(Int((1 - econ.oversupplyYield) * 100))%. Trim frequency or fly a smaller aircraft.")
                                .font(.game(.caption2)).foregroundStyle(Theme.warn)
                        }
                    }
                    if let econ = engine.routeEconomics(routeID: routeID) {
                        // The fare↔satisfaction link, live: cheap fares
                        // please passengers, gouging costs goodwill.
                        MeterRow(label: "Price fairness",
                                 value: econ.fairness,
                                 display: fairnessLabel(econ),
                                 color: Theme.health(econ.fairness))
                    }
                    MeterRow(label: "Passenger satisfaction", value: route.satisfaction / 100,
                             display: "\(Int(route.satisfaction))/100",
                             color: Theme.health(route.satisfaction / 100))
                    // The onboard rating passengers get on this pair (GDD §40):
                    // the average across the aircraft serving it.
                    if let rating = engine.routeServiceRating(routeID: routeID) {
                        HStack {
                            Text("Flight rating").font(.game(.subheadline))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            StarRating(rating: rating, size: 11)
                            Text(String(format: "%.1f", rating))
                                .font(.game(.caption, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    cateringRow(route)
                }
                weeklyMoneyCard(route)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgElevated, for: .navigationBar)
            .sheet(item: $shoppingForRoute) { route in
                NavigationStack { ShowroomView(fittingRoute: route) }
            }
            .onChange(of: servicing?.id) { _, open in
                // Dialogs have no content lifecycle — hold via a stable token.
                if open != nil { engine.beginInteraction(clockToken) }
                else { engine.endInteraction(clockToken) }
            }
            .confirmationDialog(
                serviceTitle(),
                isPresented: Binding(get: { servicing != nil },
                                     set: { if !$0 { servicing = nil } }),
                titleVisibility: .visible,
                presenting: servicing
            ) { plane in
                let onThisRoute = plane.assignedRouteID == routeID
                    || route.assignedAircraftIDs.contains(plane.id)
                let elsewhere = plane.assignedRouteID != nil && !onThisRoute
                if onThisRoute {
                    Button("Take off route") { engine.unassign(aircraftID: plane.id) }
                } else if elsewhere {
                    Button("Move to this route") { engine.assign(aircraftID: plane.id, to: routeID) }
                } else {
                    Button("Assign to this route") { engine.assign(aircraftID: plane.id, to: routeID) }
                }
                // Service it right here. Only offered when it isn't already in
                // the shop and the cash is there, so no key ever dead-ends.
                if plane.groundedWeeksRemaining == 0 {
                    if engine.state.cash >= 30_000 {
                        Button("Line check · $30K") { engine.orderCheck(aircraftID: plane.id, heavy: false) }
                    }
                    if engine.state.cash >= 250_000 {
                        Button("Heavy check · $250K") { engine.orderCheck(aircraftID: plane.id, heavy: true) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { plane in
                Text("\(Balance.specs[plane.type]!.displayName) · \(Int(plane.wear))% wear · condition \(Int(plane.condition)). A line check sheds wear (1 week in the shop); a heavy check restores it (2 weeks).")
            }
        }
    }

    /// Title for the aircraft action drawer: the tail and where it's flying.
    private func serviceTitle() -> String {
        guard let plane = servicing else { return "Aircraft" }
        if plane.wear >= Balance.wearGroundingLimit {
            return "\(plane.nickname) · grounded at 100% wear"
        }
        return plane.nickname
    }

    // ── Catering (GDD §18): choose the service, mind the hardware ────────

    // The tray picker mirrors the cabin architect's seat tiles: the art IS
    // the swatch, evenly distributed, accent stroke on the chosen one.
    @ViewBuilder private func cateringRow(_ route: Route) -> some View {
        let level = route.catering ?? .none
        let planes = engine.state.fleet.filter { route.assignedAircraftIDs.contains($0.id) }
        let ovens = planes.filter { $0.hasGalleyOven ?? false }.count
        VStack(alignment: .leading, spacing: 8) {
            Text("Catering")
                .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(CateringLevel.allCases) { option in
                    Button {
                        engine.setCatering(routeID: route.id, level: option)
                    } label: {
                        VStack(spacing: 5) {
                            Group {
                                if let name = option.assetName,
                                   let tray = UIImage(named: name) {
                                    Image(uiImage: tray).resizable().scaledToFit()
                                } else {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.corner - 2)
                                    .fill(level == option
                                          ? accent.opacity(0.18) : Color.white.opacity(0.04))
                            )
                            .overlay(RoundedRectangle(cornerRadius: Theme.corner - 2)
                                .strokeBorder(level == option ? accent : .clear,
                                              lineWidth: 1.5))
                            Text(trayShortName(option))
                                .font(.game(.caption2,
                                            weight: level == option ? .bold : .regular))
                                .foregroundStyle(level == option ? accent : Theme.textSecondary)
                                .lineLimit(1)
                            Text(option == .none ? " " : "\(option.costPerPax.money)/pax")
                                .font(.data(.caption2)).foregroundStyle(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: level)
                }
            }
            if level.requiresOven && ovens < planes.count {
                Text("\(planes.count - ovens) of \(planes.count) aircraft here have no galley oven. \(level == .asianBento ? "Bento mains" : "Sandwiches") board cold and customers get frustrated. Fit ovens via Fleet → Service.")
                    .font(.game(.caption2)).foregroundStyle(Theme.loss)
            }
        }
    }

    /// Tile-width names; the art carries the identity.
    private func trayShortName(_ level: CateringLevel) -> String {
        switch level {
        case .none: "None"
        case .sandwichBox: "Sandwich"
        case .fruitPlatter: "Fruit"
        case .asianBento: "Bento"
        }
    }

    private func fairnessLabel(_ econ: RouteEconomics) -> String {
        let pct = Int((econ.priceRatio - 1) * 100)
        return pct == 0 ? "at market" : (pct > 0 ? "\(pct)% over market" : "\(-pct)% under market")
    }

    // ── What one week of this route really earns: three numbers, no math ─

    private func weeklyMoneyCard(_ route: Route) -> some View {
        let margin = route.lastWeeklyRevenue - route.lastWeeklyFuel
        return GameCard {
            SectionHeader(title: "Last week", icon: "chart.bar.fill", accent: accent)
            HStack(spacing: 20) {
                StatTile(label: "Revenue", value: route.lastWeeklyRevenue.money,
                         color: Theme.profit, font: .game(.subheadline, weight: .bold))
                StatTile(label: "Cost", value: route.lastWeeklyFuel.money,
                         font: .game(.subheadline, weight: .bold))
                StatTile(label: "Margin", value: margin.money,
                         color: margin >= 0 ? Theme.profit : Theme.loss,
                         font: .game(.subheadline, weight: .bold))
            }
        }
    }

    /// Which shelf a plane sits on at this route's assignment desk.
    private enum AssignRowKind { case onRoute, free, busy }

    private func assignCard(_ route: Route) -> some View {
        // Physics fit: range and runways. Status is a badge, not a filter,
        // and planes that can never fly the pair are not listed at all.
        func fits(_ plane: Aircraft) -> Bool {
            let spec = Balance.specs[plane.type]!
            guard let origin = engine.city(route.originID),
                  let dest = engine.city(route.destinationID) else { return false }
            return plane.effectiveRangeKm(spec: spec) >= route.distanceKm
                && origin.runwayClass >= spec.requiredRunwayClass
                && dest.runwayClass >= spec.requiredRunwayClass
        }
        let fleet = engine.state.fleet
        // On the route now, plus on-order planes posted here for delivery.
        let onRoute = fleet.filter {
            route.assignedAircraftIDs.contains($0.id) || $0.assignedRouteID == route.id
        }
        let free = fleet.filter { plane in
            !onRoute.contains(where: { $0.id == plane.id })
                && plane.assignedRouteID == nil && fits(plane)
        }
        let busy = fleet.filter { plane in
            !onRoute.contains(where: { $0.id == plane.id })
                && plane.assignedRouteID != nil && fits(plane)
        }
        let hasCandidate = !(onRoute.isEmpty && free.isEmpty && busy.isEmpty)
        return GameCard {
            SectionHeader(title: "Aircraft on this route", icon: "airplane.circle.fill", accent: accent)
            if !hasCandidate {
                Text(fleet.isEmpty
                     ? "No aircraft in the fleet yet."
                     : "Nothing in the fleet can fly this route. Check range and runway class.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
            ForEach(onRoute) { assignRow($0, route: route, kind: .onRoute) }
            if !free.isEmpty {
                if !onRoute.isEmpty { Divider().overlay(Theme.hairline) }
                ForEach(free) { assignRow($0, route: route, kind: .free) }
            }
            // Poaching pool, folded away: the badge names the route a tap
            // would pull each plane from.
            if !busy.isEmpty {
                DisclosureGroup(isExpanded: $showOtherRoutes) {
                    VStack(spacing: 10) {
                        ForEach(busy) { assignRow($0, route: route, kind: .busy) }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("On other routes (\(busy.count))", systemImage: "airplane")
                        .font(.game(.caption, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .tint(Theme.textSecondary)
            }
            // Always a path to more metal: the route-aware showroom pops
            // up as a drawer, and anything acquired there joins THIS route
            // automatically — prominent when nothing in the fleet fits.
            Button {
                shoppingForRoute = route
            } label: {
                Label(hasCandidate ? "Add planes to this route" : "Get an aircraft for this route",
                      systemImage: "cart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: Theme.orange, prominent: !hasCandidate))
        }
    }

    /// One plane at the assignment desk: name, type and reach on a single
    /// line, status as a stamped badge. Tap adds, removes, or poaches.
    private func assignRow(_ plane: Aircraft, route: Route, kind: AssignRowKind) -> some View {
        let spec = Balance.specs[plane.type]!
        return Button {
            // Every delivered plane opens the action drawer: assign / move /
            // take off route, and service it right here (GDD §39). On-order
            // planes have nothing to do yet.
            if plane.status != .onOrder { servicing = plane }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind == .onRoute ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(kind == .onRoute ? Theme.profit : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(plane.nickname)
                            .font(.game(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        // Onboard flight rating beside the aircraft (GDD §40).
                        if plane.status != .onOrder {
                            StarRating(rating: plane.serviceRating, size: 8)
                        }
                    }
                    Text("\(spec.displayName) · \(Int(plane.effectiveRangeKm(spec: spec))) km")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if plane.status == .onOrder {
                    StatusBadge(text: "Delivers · \(plane.deliveryWeeksRemaining) wk",
                                color: Theme.warn)
                } else if plane.groundedWeeksRemaining > 0 {
                    StatusBadge(text: "In shop · \(plane.groundedWeeksRemaining) wk",
                                color: Theme.warn)
                } else if kind == .busy,
                          let other = engine.state.routes.first(where: { $0.id == plane.assignedRouteID }) {
                    StatusBadge(text: "\(other.originID) ✈︎ \(other.destinationID)",
                                color: Theme.warn)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("New route desk") {
    NewRouteSheet()
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
