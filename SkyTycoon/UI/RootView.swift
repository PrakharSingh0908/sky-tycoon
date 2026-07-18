//
//  RootView.swift
//  SkyTycoon — UI shell
//
//  Ops-center dark, persistent HUD above the five tabs (DESIGN_SYSTEM.md),
//  plus the event-card sheet that pauses the sim until answered.
//

import SwiftUI

struct RootView: View {
    @Environment(GameEngine.self) private var engine
    // Dev/test affordance: `simctl launch ... -openTab routes` starts on a
    // given tab (dashboard/fleet/routes/people/money).
    @State private var tab: GameTab = {
        switch UserDefaults.standard.string(forKey: "openTab") {
        case "fleet": .fleet
        case "routes": .routes
        case "people": .people
        case "money": .money
        default: .dashboard
        }
    }()

    enum GameTab: Hashable {
        case dashboard, fleet, routes, people, money
        var accent: Color {
            switch self {
            case .dashboard: Theme.sky
            case .fleet: Theme.orange
            case .routes: Theme.teal
            case .people: Theme.violet
            case .money: Theme.mint
            }
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge") }
                .tag(GameTab.dashboard)
            FleetView()
                .tabItem { Label("Fleet", systemImage: "airplane") }
                .tag(GameTab.fleet)
            RoutesView()
                .tabItem { Label("Routes", systemImage: "map") }
                .tag(GameTab.routes)
            PeopleView()
                .tabItem { Label("People", systemImage: "person.3") }
                .tag(GameTab.people)
            MoneyView()
                .tabItem { Label("Money", systemImage: "banknote") }
                .tag(GameTab.money)
        }
        .tint(tab.accent)
        // The floating sim clock — above the tab bar, on every tab
        // (DESIGN_SYSTEM.md v1.1).
        .overlay(alignment: .bottomTrailing) {
            SimClockPill()
                .padding(.trailing, Theme.gutter)
                .padding(.bottom, 56)
        }
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .sheet(item: Binding(
            get: { engine.state.pendingEvent },
            set: { _ in }   // dismissal only via choosing an option
        )) { event in
            EventCardView(event: event).interactiveDismissDisabled()
        }
    }
}

#Preview {
    RootView().environment(GameEngine.previewGame())
}
