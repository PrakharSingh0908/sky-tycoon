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

    // v2.1 win moments: diffed from state, so the sim stays untouched.
    @State private var celebration: MilestoneDef?
    @State private var seenMilestones: Set<String>?
    @State private var quarterReport: QuarterlyLetter?

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
            RoutesView()
                .tabItem { Label("Routes", systemImage: "map") }
                .tag(GameTab.routes)
            FleetView()
                .tabItem { Label("Fleet", systemImage: "airplane") }
                .tag(GameTab.fleet)
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
            // A grounded airline never shows an event card (edge case: an
            // event drawn the same week bankruptcy landed).
            get: { engine.state.isBankrupt ? nil : engine.state.pendingEvent },
            set: { _ in }   // dismissal only via choosing an option
        )) { event in
            EventCardView(event: event).interactiveDismissDisabled()
        }
        // The hard fail state (GDD §3.2): full-screen, no way around it.
        .overlay {
            if engine.state.isBankrupt { bankruptcyOverlay }
        }
        // ── Milestone celebration: a win, announced, then gone ────────────
        .overlay(alignment: .top) {
            if let celebration {
                CelebrationBanner(title: "Milestone: \(celebration.displayTitle(for: engine.state.country))",
                                  subtitle: "Reward \(celebration.reward.money) banked",
                                  accent: Theme.profit, icon: "flag.checkered")
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { seenMilestones = engine.state.completedMilestones }
        .onChange(of: engine.state.completedMilestones) { _, new in
            guard let seen = seenMilestones else { seenMilestones = new; return }
            if let fresh = Balance.milestones.first(where: {
                new.contains($0.id) && !seen.contains($0.id)
            }) {
                withAnimation(.snappy) { celebration = fresh }
            }
            seenMilestones = new
        }
        .task(id: celebration?.id) {
            guard celebration != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.5)) { celebration = nil }
        }
        // ── Quarter close: the report card moment ─────────────────────────
        .onChange(of: engine.state.letters.count) { old, new in
            guard new > old, let latest = engine.state.letters.last else { return }
            quarterReport = latest
        }
        .sheet(item: $quarterReport) { letter in
            QuarterReportCard(letter: letter,
                              quarterProfit: letter.quarterProfit,
                              streak: engine.state.consecutiveProfitableQuarters,
                              reputation: engine.state.reputation,
                              auntName: engine.state.country.auntName)
        }
    }

    // The last look out the window, with the run's numbers below.
    private var bankruptcyOverlay: some View {
        VStack(spacing: 0) {
            if let window = UIImage(named: "window_welcome") {
                Image(uiImage: window)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 320)
                    .padding(.top, 24)
            }
            Text("Grounded")
                .font(.display(.largeTitle)).foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)
            Text("Eight weeks insolvent with nothing left to sell. \(engine.state.airlineName) has flown its last sector. The banks have called time.")
                .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 10)
            Spacer(minLength: 16)
            HStack(alignment: .top, spacing: 8) {
                runStat("Survived", engine.state.date.description)
                runStat("Fleet", "\(engine.state.fleet.count)")
                runStat("Routes", "\(engine.state.routes.count)")
                runStat("Rating", String(format: "%.1f★", engine.state.reputation))
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.gutter)
            Button {
                engine.restart()
            } label: {
                Text("Start a new airline").frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: Theme.sky, prominent: true))
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    /// A board tile for the final ledger (mono caps value, engraved label).
    private func runStat(_ label: String, _ value: String) -> some View {
        InstrumentWell {
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.data(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(label.uppercased())
                    .font(.data(.caption2)).tracking(0.85)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .shadow(color: .black.opacity(0.8), radius: 0, y: 1)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }
}

#Preview("Grounded") {
    RootView().environment({ () -> GameEngine in
        var state = GameEngine.previewGame().state
        state.isBankrupt = true
        return GameEngine(state: state)
    }())
}

#Preview {
    RootView().environment(GameEngine.previewGame())
}
