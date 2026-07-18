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
    @State private var origin = "DEL"
    @State private var destination = "BOM"
    private let accent = Theme.teal

    var body: some View {
        NavigationStack {
            GameScreen(title: "Routes", accent: accent) {
                // The network at a glance: satellite globe, geodesic arcs.
                RouteMapView()
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 5)

                ForEach(engine.state.routes) { route in
                    BoardingPassCard(route: route,
                        originName: engine.city(route.originID)?.name ?? route.originID,
                        destName: engine.city(route.destinationID)?.name ?? route.destinationID,
                        accent: accent)
                }
                openRouteCard
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var openRouteCard: some View {
        GameCard {
            SectionHeader(title: "Open new route", icon: "plus.circle.fill", accent: accent)
            HStack(spacing: 10) {
                cityMenu("From", selection: $origin)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                cityMenu("To", selection: $destination)
            }
            let dist = Balance.distance(origin, destination)
            if origin != destination {
                Text("\(Int(dist)) km · \(engine.freeSlots(at: origin)) free slots at \(origin), \(engine.freeSlots(at: destination)) at \(destination)")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Button("Open route") {
                let fareLevel = Balance.countryProfiles[engine.state.country]!.fareLevel
                _ = engine.openRoute(from: origin, to: destination,
                    fare: dist * Balance.referenceFarePerKm * fareLevel,
                    frequency: 7)
            }
            .buttonStyle(GameButtonStyle(color: accent, prominent: true))
            .disabled(origin == destination)
            .opacity(origin == destination ? 0.4 : 1)
        }
    }

    private func cityMenu(_ label: String, selection: Binding<String>) -> some View {
        Menu {
            ForEach(engine.state.cities) { city in
                Button("\(city.name) (\(city.id))") { selection.wrappedValue = city.id }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue).font(.game(.headline, weight: .bold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.controlCorner))
            .foregroundStyle(accent)
        }
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

    private let stubHeight: CGFloat = 124

    var body: some View {
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

            // ── The stub ─────────────────────────────────────────────────
            VStack(spacing: 10) {
                MeterRow(label: "Load factor", value: route.lastLoadFactor,
                         color: Theme.health(route.lastLoadFactor))
                HStack {
                    Text("on-time \(Int(route.lastPunctuality * 100))% · sat \(Int(route.satisfaction))")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    TickerText(text: route.lastWeeklyProfit.money + "/wk",
                               font: .game(.subheadline, weight: .bold),
                               color: route.lastWeeklyProfit >= 0 ? Theme.profit : Theme.loss)
                }
                HStack(spacing: 10) {
                    NavigationLink {
                        RouteDetailView(routeID: route.id)
                    } label: {
                        Text("Set up route").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GameButtonStyle(color: accent, prominent: true))
                    Button("Cancel route", role: .destructive) {
                        confirmingCancel = true
                    }
                    .buttonStyle(GameButtonStyle(color: Theme.loss))
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .frame(height: stubHeight)
            .onChange(of: confirmingCancel) { _, showing in
                // Dialogs have no content lifecycle — hold the clock manually.
                if showing { engine.beginInteraction() } else { engine.endInteraction() }
            }
            .confirmationDialog(
                "Cancel \(route.originID) ⇄ \(route.destinationID)? Assigned aircraft go idle and the fares and schedule are lost.",
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
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
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
        let spec = Balance.specs[plane.type]!
        return HStack(spacing: 8) {
            Image(systemName: "airplane").font(.caption2).foregroundStyle(accent)
            Text(plane.nickname)
                .font(.game(.caption, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Text(spec.displayName)
                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            Spacer()
            if plane.groundedWeeksRemaining > 0 {
                StatusBadge(text: "In shop · \(plane.groundedWeeksRemaining) wk", color: Theme.warn)
            } else {
                TickerText(text: "LF \(Int(route.lastLoadFactor * 100))%",
                           font: .game(.caption2, weight: .semibold),
                           color: Theme.health(route.lastLoadFactor))
            }
        }
    }

    private func codeBlock(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
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
    private let accent = Theme.teal

    var body: some View {
        if let route = engine.state.routes.first(where: { $0.id == routeID }) {
            GameScreen(title: "\(route.originID) ⇄ \(route.destinationID)", accent: accent) {
                RouteMapView(focusRouteID: routeID)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                GameCard {
                    SectionHeader(title: "Load factor · 26 weeks", icon: "chart.xyaxis.line", accent: accent)
                    LoadFactorSparkline(history: route.loadFactorHistory)
                }
                GameCard {
                    SectionHeader(title: "Economics", icon: "slider.horizontal.3", accent: accent)
                    HStack(spacing: 20) {
                        StatTile(label: "Distance", value: "\(Int(route.distanceKm)) km")
                        StatTile(label: "Load factor", value: "\(Int(route.lastLoadFactor * 100))%",
                                 color: Theme.health(route.lastLoadFactor))
                        StatTile(label: "On-time", value: "\(Int(route.lastPunctuality * 100))%",
                                 color: Theme.health(route.lastPunctuality))
                    }
                    Divider().overlay(Theme.hairline)
                    PillStepper(label: "Fare", value: route.fare.money, accent: accent,
                        onDecrement: { engine.setFare(routeID: routeID, fare: route.fare - 5) },
                        onIncrement: { engine.setFare(routeID: routeID, fare: route.fare + 5) })
                    PillStepper(label: "Flights/week", value: "\(route.weeklyFrequency)", accent: accent,
                        onDecrement: { engine.setFrequency(routeID: routeID, frequency: route.weeklyFrequency - 1) },
                        onIncrement: { engine.setFrequency(routeID: routeID, frequency: route.weeklyFrequency + 1) })
                    if let econ = engine.routeEconomics(routeID: routeID) {
                        // The fare↔satisfaction link, live: cheap fares
                        // please passengers, gouging costs goodwill.
                        MeterRow(label: "Price fairness (feeds satisfaction)",
                                 value: econ.fairness,
                                 display: fairnessLabel(econ),
                                 color: Theme.health(econ.fairness))
                    }
                    MeterRow(label: "Passenger satisfaction", value: route.satisfaction / 100,
                             display: "\(Int(route.satisfaction))/100",
                             color: Theme.health(route.satisfaction / 100))
                }
                weeklyMoneyCard(route)
                assignCard(route)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgElevated, for: .navigationBar)
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

    private func assignCard(_ route: Route) -> some View {
        // Can anything in the fleet actually take this route?
        let hasCandidate = engine.state.fleet.contains {
            engine.canOperate(aircraftID: $0.id, routeID: route.id)
        }
        return GameCard {
            SectionHeader(title: "Assign aircraft", icon: "airplane.circle.fill", accent: accent)
            if !hasCandidate {
                Text(engine.state.fleet.isEmpty
                     ? "No aircraft in the fleet yet."
                     : "Nothing in the fleet can fly this route. Check range and runway class.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
            ForEach(engine.state.fleet) { plane in
                let assigned = route.assignedAircraftIDs.contains(plane.id)
                let spec = Balance.specs[plane.type]!
                // Busy elsewhere? Name the route so a reassignment is a
                // deliberate steal, not a surprise.
                let busyOn = plane.assignedRouteID.flatMap { otherID -> Route? in
                    otherID == routeID ? nil
                        : engine.state.routes.first { $0.id == otherID }
                }
                Button {
                    // Tapping an assigned plane takes it off the route.
                    if assigned {
                        engine.unassign(aircraftID: plane.id)
                    } else {
                        engine.assign(aircraftID: plane.id, to: routeID)
                    }
                } label: {
                    HStack {
                        Image(systemName: assigned ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(assigned ? Theme.profit : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(plane.nickname)
                                .font(.game(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(spec.displayName) · range \(Int(plane.effectiveRangeKm(spec: spec))) km")
                                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                            if let busyOn {
                                Text("Assigning here pulls it off \(busyOn.originID) ⇄ \(busyOn.destinationID)")
                                    .font(.game(.caption2)).foregroundStyle(Theme.warn)
                            }
                        }
                        Spacer()
                        if plane.effectiveRangeKm(spec: spec) < route.distanceKm {
                            StatusBadge(text: "Out of range", color: Theme.loss)
                        } else if plane.status == .onOrder {
                            StatusBadge(text: "On order", color: Theme.warn)
                        } else if plane.groundedWeeksRemaining > 0 {
                            StatusBadge(text: "In shop · \(plane.groundedWeeksRemaining) wk", color: Theme.warn)
                        } else if let busyOn {
                            StatusBadge(text: "On \(busyOn.originID) ⇄ \(busyOn.destinationID)", color: Theme.warn)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            // Always a path to more metal: route-aware showroom at the
            // bottom — prominent when nothing in the fleet fits.
            NavigationLink {
                ShowroomView(fittingRoute: route)
            } label: {
                Label(hasCandidate ? "Buy more aircraft" : "Get an aircraft for this route",
                      systemImage: "cart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: Theme.orange, prominent: !hasCandidate))
        }
    }
}
