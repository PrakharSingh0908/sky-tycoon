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
            .background(accent.opacity(0.14), in: Capsule())
            .foregroundStyle(accent)
        }
    }
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

    private let stubHeight: CGFloat = 102

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

            PerforationLine().padding(.horizontal, 16)

            // ── The stub ─────────────────────────────────────────────────
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    MeterRow(label: "Load factor", value: route.lastLoadFactor,
                             color: Theme.health(route.lastLoadFactor))
                    VStack(alignment: .trailing, spacing: 2) {
                        TickerText(text: route.lastWeeklyProfit.money + "/wk",
                                   font: .game(.subheadline, weight: .bold),
                                   color: route.lastWeeklyProfit >= 0 ? Theme.profit : Theme.loss)
                        Text("on-time \(Int(route.lastPunctuality * 100))% · sat \(Int(route.satisfaction))")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
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
    @State private var explanation: Explanation?
    private let accent = Theme.teal

    var body: some View {
        if let route = engine.state.routes.first(where: { $0.id == routeID }) {
            GameScreen(title: "\(route.originID) ⇄ \(route.destinationID)", accent: accent) {
                GameCard {
                    SectionHeader(title: "Load factor — 26 weeks", icon: "chart.xyaxis.line", accent: accent)
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
                if let econ = engine.routeEconomics(routeID: routeID) {
                    unitEconomicsCard(route, econ)
                }
                assignCard(route)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgElevated, for: .navigationBar)
            .sheet(item: $explanation) { FormulaSheet(explanation: $0) }
        }
    }

    private func fairnessLabel(_ econ: RouteEconomics) -> String {
        let pct = Int((econ.priceRatio - 1) * 100)
        return pct == 0 ? "at market" : (pct > 0 ? "\(pct)% over market" : "\(-pct)% under market")
    }

    // ── Unit economics (M7): what one week of this route really earns ────

    private func unitEconomicsCard(_ route: Route, _ econ: RouteEconomics) -> some View {
        let flights = max(1, route.weeklyFrequency * 2)
        let margin = route.lastWeeklyRevenue - route.lastWeeklyFuel
        return GameCard {
            HStack {
                SectionHeader(title: "Unit economics", icon: "function", accent: accent)
                Spacer()
                Button {
                    explanation = demandExplanation(route, econ)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "questionmark.circle").font(.caption2)
                        Text("Why these numbers?").font(.game(.caption, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 20) {
                StatTile(label: "Revenue /wk", value: route.lastWeeklyRevenue.money,
                         color: Theme.profit, font: .game(.subheadline, weight: .bold))
                StatTile(label: "Fuel /wk", value: route.lastWeeklyFuel.money,
                         font: .game(.subheadline, weight: .bold))
                StatTile(label: "Margin /wk", value: margin.money,
                         color: margin >= 0 ? Theme.profit : Theme.loss,
                         font: .game(.subheadline, weight: .bold))
            }
            Divider().overlay(Theme.hairline)
            HStack(spacing: 20) {
                StatTile(label: "Margin /flight", value: (margin / Double(flights)).money,
                         color: margin >= 0 ? Theme.profit : Theme.loss,
                         font: .game(.subheadline, weight: .bold))
                StatTile(label: "Seats /wk", value: "\(econ.seatsOffered)",
                         font: .game(.subheadline, weight: .bold))
                StatTile(label: "Demand /wk", value: "\(Int(econ.demand))",
                         font: .game(.subheadline, weight: .bold))
            }
            // Breakeven vs actual: the gap IS the business.
            MeterRow(label: "Breakeven load factor (fuel only)",
                     value: econ.breakevenLoadFactor,
                     display: "\(Int(econ.breakevenLoadFactor * 100))% vs \(Int(route.lastLoadFactor * 100))% flown",
                     color: route.lastLoadFactor > econ.breakevenLoadFactor ? Theme.profit : Theme.loss)
        }
    }

    private func demandExplanation(_ route: Route, _ econ: RouteEconomics) -> Explanation {
        Explanation(
            title: "\(route.originID) ⇄ \(route.destinationID) demand",
            subtitle: "Every factor in this week's \(Int(econ.demand)) passengers",
            rows: [
                ("Gravity (city sizes ÷ distance)", String(format: "%.0f", econ.gravity)),
                ("Market growth", String(format: "×%.2f", econ.growth)),
                ("Season", String(format: "×%.2f", econ.season)),
                ("Brand (reputation × awareness)", String(format: "×%.2f", econ.brand)),
                ("Price response (fare \(fairnessLabel(econ)))", String(format: "×%.2f", econ.priceResponse)),
                ("Events", String(format: "×%.2f", econ.eventDemand)),
                ("= Demand", String(format: "%.0f pax", econ.demand)),
                ("Seats offered", "\(econ.seatsOffered)"),
                ("Passengers flown", String(format: "%.0f", econ.pax)),
            ],
            formula: "demand = k×(popA×popB)^0.55 / dist^0.35\n × growth × season × brand × fare^−elasticity\npax = min(demand, seats)")
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
                     : "Nothing in the fleet can fly this route — check range and runway class.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                NavigationLink {
                    ShowroomView(fittingRoute: route)
                } label: {
                    Label("Get an aircraft for this route", systemImage: "cart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: Theme.orange, prominent: true))
            }
            ForEach(engine.state.fleet) { plane in
                let assigned = route.assignedAircraftIDs.contains(plane.id)
                let spec = Balance.specs[plane.type]!
                Button {
                    engine.assign(aircraftID: plane.id, to: routeID)
                } label: {
                    HStack {
                        Image(systemName: assigned ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(assigned ? Theme.profit : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(plane.nickname)
                                .font(.game(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(spec.displayName) · range \(Int(spec.rangeKm)) km")
                                .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if spec.rangeKm < route.distanceKm {
                            StatusBadge(text: "Out of range", color: Theme.loss)
                        } else if plane.status == .onOrder {
                            StatusBadge(text: "On order", color: Theme.warn)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
