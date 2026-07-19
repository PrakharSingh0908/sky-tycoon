//
//  FleetView.swift
//  SkyTycoon — UI (orange accent)
//
//  One card per aircraft: acquisition badge, wear/condition meters,
//  delivery progress, and actions (DESIGN_SYSTEM.md §4).
//

import SwiftUI

struct FleetView: View {
    @Environment(GameEngine.self) private var engine
    @State private var architectingPlane: Aircraft?
    private let accent = Theme.orange

    var body: some View {
        NavigationStack {
            GameScreen(title: "Fleet", accent: accent) {
                if engine.state.fleet.isEmpty { emptyCard }
                // Worst wear first: the plane that needs you leads the list.
                ForEach(engine.state.fleet.sorted { $0.wear > $1.wear }) { plane in
                    AircraftCard(plane: plane, accent: accent,
                                 onArchitect: { architectingPlane = $0 })
                        // Deliveries arrive, sales depart (v2.1 win moments).
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                showroomCard
            }
            .animation(.snappy(duration: 0.35), value: engine.state.fleet.count)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $architectingPlane) { plane in
            CabinArchitectView(aircraftID: plane.id, current: plane.cabin)
        }
    }

    private var emptyCard: some View {
        GameCard {
            HStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 40)).polishedSilver()
                VStack(alignment: .leading, spacing: 3) {
                    Text("No aircraft yet").font(.game(.headline, weight: .bold))
                    Text("Buy, lease, or order your first plane in the showroom below.")
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var showroomCard: some View {
        NavigationLink {
            ShowroomView()
        } label: {
            GameCard {
                HStack {
                    Image(systemName: "cart.fill").font(.title3).polishedSilver()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Showroom").font(.game(.headline, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("New orders · used market · leasing")
                            .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FleetView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

// Empty-state pin: silver instruments on the no-aircraft console.
#Preview("Empty fleet") {
    FleetView().environment(GameEngine.newGame(airlineName: "Foundation Air",
                                               country: .us, seed: 7))
        .preferredColorScheme(.dark)
}

private struct AircraftCard: View {
    @Environment(GameEngine.self) private var engine
    let plane: Aircraft
    let accent: Color
    let onArchitect: (Aircraft) -> Void

    var body: some View {
        let spec = Balance.specs[plane.type]!
        GameCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plane.nickname).font(.game(.headline, weight: .bold))
                    Text("\(spec.displayName) · \(plane.seats(spec: spec)) seats · \(Int(plane.effectiveRangeKm(spec: spec))) km range · \(String(format: "%.1f", plane.ageYears))y")
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                acquisitionBadge
            }

            // The airplane itself — undelivered planes stay in natural
            // factory paint until they arrive.
            AircraftPhotoView(type: plane.type,
                              livery: plane.status == .onOrder ? nil : engine.state.livery)
                .frame(height: 86)
                .frame(maxWidth: .infinity)
                .animation(.snappy, value: engine.state.livery)

            if plane.status == .onOrder {
                deliveryProgress(spec: spec)
            } else {
                HStack(spacing: 14) {
                    MeterRow(label: "Wear", value: plane.wear / 100,
                             display: "\(Int(plane.wear))",
                             color: Theme.health(1 - plane.wear / 100))
                    MeterRow(label: "Condition", value: plane.condition / 100,
                             display: "\(Int(plane.condition))",
                             color: Theme.health(plane.condition / 100))
                }
                // The quiet-but-mortal warning (GDD §17): past the danger
                // line, a flying airframe can be LOST. Not a popup — a
                // line on the card the player either heeds or answers for.
                if plane.status != .onOrder,
                   plane.wear >= Balance.wearDangerThreshold {
                    Label(plane.assignedRouteID != nil
                          ? "Airworthiness critical: \(Int(plane.wear))% wear on an active route. Ground it for service. Worn airframes go down."
                          : "Airworthiness critical: \(Int(plane.wear))% wear. Service before it flies again.",
                          systemImage: "exclamationmark.octagon.fill")
                        .font(.game(.caption, weight: .medium))
                        .foregroundStyle(Theme.loss)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.loss.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 10))
                }
                statusLine
                actions
            }
        }
    }

    private var acquisitionBadge: some View {
        switch plane.acquisition {
        case .ownedNew: StatusBadge(text: "New", color: accent)
        case .ownedUsed: StatusBadge(text: "Used", color: Theme.teal)
        case .leased: StatusBadge(text: "Leased", color: Theme.violet)
        }
    }

    private func deliveryProgress(spec: AircraftSpec) -> some View {
        let total = Double(Balance.deliveryWeeks[plane.type] ?? 1)
        return MeterRow(label: "On order · arrives in \(plane.deliveryWeeksRemaining) wk",
                        value: 1 - Double(plane.deliveryWeeksRemaining) / max(total, 1),
                        display: "\(plane.deliveryWeeksRemaining) wk",
                        color: accent)
    }

    private var currentRoute: Route? {
        guard let id = plane.assignedRouteID else { return nil }
        return engine.state.routes.first { $0.id == id }
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            if plane.groundedWeeksRemaining > 0 {
                StatusBadge(text: "In shop · \(plane.groundedWeeksRemaining) wk", color: Theme.warn)
            } else if let route = currentRoute {
                StatusBadge(text: "\(route.originID) ✈︎ \(route.destinationID)", color: Theme.profit)
            } else {
                StatusBadge(text: "Idle", color: Theme.textSecondary)
            }
            Spacer()
            if plane.acquisition == .leased {
                Text("\(plane.weeklyLeaseCost.money)/wk lease")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var actions: some View {
        // Same materials as the route card's action pair: bronze leads,
        // obsidian for the rest of the bank.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                routeMenu
                Button("Cabin") { onArchitect(plane) }
                    .buttonStyle(GameButtonStyle(finish: .obsidian))
                serviceMenu
            }
            // Room for the keys' metalwork: the extruded base lip and drop
            // shadow extend below the face and were clipped by the scroll
            // bounds + fade mask.
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
        .fadeEdge(.trailing, length: 16)
        .disabled(plane.groundedWeeksRemaining > 0)
        .opacity(plane.groundedWeeksRemaining > 0 ? 0.4 : 1)
    }

    /// Checks plus the exit door: Sell/Return live here now, one level
    /// down, so the card isn't shouting a red button all day (v2.1).
    private var serviceMenu: some View {
        Menu {
            Button("Line check · $30K · 1 wk") {
                engine.orderCheck(aircraftID: plane.id, heavy: false)
            }
            Button("Heavy check · $250K · 2 wk") {
                engine.orderCheck(aircraftID: plane.id, heavy: true)
            }
            if !(plane.hasGalleyOven ?? false) {
                Button("Fit galley oven · \(Balance.galleyOvenCost.money)") {
                    engine.installGalleyOven(aircraftID: plane.id)
                }
            }
            Divider()
            if plane.acquisition == .leased {
                Button("Return to lessor", role: .destructive) {
                    engine.returnLeasedAircraft(aircraftID: plane.id)
                }
            } else {
                Button("Sell · \(Balance.resaleValue(type: plane.type, ageYears: plane.ageYears, condition: plane.condition).money)",
                       role: .destructive) {
                    engine.sellAircraft(aircraftID: plane.id)
                }
            }
        } label: {
            menuChip("Service", icon: "wrench.and.screwdriver.fill", finish: .obsidian)
        }
    }

    /// Assign straight from the fleet: every route listed, flyable ones
    /// tappable, the rest disabled with the reason (range or runway).
    private var routeMenu: some View {
        let spec = Balance.specs[plane.type]!
        return Menu {
            if engine.state.routes.isEmpty {
                Text("No routes yet. Open one on the Routes tab.")
            }
            ForEach(engine.state.routes) { route in
                let flyable = engine.canOperate(aircraftID: plane.id, routeID: route.id)
                Button {
                    engine.assign(aircraftID: plane.id, to: route.id)
                } label: {
                    if route.id == plane.assignedRouteID {
                        Label(routeLabel(route, spec: spec), systemImage: "checkmark")
                    } else {
                        Text(routeLabel(route, spec: spec))
                    }
                }
                .disabled(!flyable || route.id == plane.assignedRouteID)
            }
            if plane.assignedRouteID != nil {
                Divider()
                Button("Unassign", role: .destructive) {
                    engine.unassign(aircraftID: plane.id)
                }
            }
        } label: {
            menuChip("Route", icon: "point.topleft.down.to.point.bottomright.curvepath",
                     finish: .bronze)
        }
    }

    /// Menu chips wear the same machined key surface as real buttons, so
    /// the action row reads as one bank of console keys.
    private func menuChip(_ title: String, icon: String, finish: MetalFinish) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2.weight(.medium))
            Text(title)
        }
        .foregroundStyle(finish.ink)
        .font(.game(.subheadline, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(minHeight: 36)
        .metalKey(finish, pressed: false)
    }

    private func routeLabel(_ route: Route, spec: AircraftSpec) -> String {
        let base = "\(route.originID) ✈︎ \(route.destinationID) · \(Int(route.distanceKm)) km"
        if plane.effectiveRangeKm(spec: spec) < route.distanceKm {
            // A lighter cabin might stretch it — tell the player.
            return spec.rangeKm * 1.10 >= route.distanceKm
                ? base + " · beyond range (an airier cabin could reach)"
                : base + " · beyond range"
        }
        if !engine.canOperate(aircraftID: plane.id, routeID: route.id),
           plane.status != .onOrder {
            return base + " · runway too short"
        }
        return base
    }
}
