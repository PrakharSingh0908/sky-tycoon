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
    // Ambition-ladder win moments (GDD §26 Pillar 5).
    @State private var ambitionWin: AmbitionDef?
    @State private var seenAmbitions: Set<String>?
    // Rival-overtake moment (GDD §29).
    @State private var overtook: String?
    // Grand-honor ceremony + record-week brag (GDD §38).
    @State private var honorAward: HonorAward?
    @State private var recordProfit: Double?

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
            DashboardView(onOpenFleet: { tab = .fleet })
                .tabItem { Label("HQ", systemImage: "square.grid.2x2.fill") }
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
            // Only MAJOR events take the screen and pause the sim (GDD §25);
            // ambient cards live on the Dashboard. A grounded airline never
            // shows a card (edge case: one drawn the week bankruptcy landed).
            get: { engine.state.isBankrupt ? nil : engine.blockingEvent },
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
                topBanner(title: "Milestone: \(celebration.displayTitle(for: engine.state.country))",
                          subtitle: "Reward \(celebration.reward.money) banked",
                          accent: Theme.profit, icon: "flag.checkered",
                          dismiss: { withAnimation(.easeOut(duration: 0.2)) { self.celebration = nil } })
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
        // ── Ambition celebration: a bigger win, same treatment ────────────
        .overlay(alignment: .top) {
            if let ambitionWin {
                topBanner(title: "Ambition: \(ambitionWin.title)",
                          subtitle: "Reward \(ambitionWin.reward.money) banked",
                          accent: Theme.sky, icon: "trophy.fill",
                          dismiss: { withAnimation(.easeOut(duration: 0.2)) { self.ambitionWin = nil } })
            }
        }
        .onAppear { if seenAmbitions == nil { seenAmbitions = engine.state.completedAmbitions ?? [] } }
        .onChange(of: engine.state.completedAmbitions) { _, new in
            let newSet = new ?? []
            guard let seen = seenAmbitions else { seenAmbitions = newSet; return }
            if let fresh = Balance.ambitions.first(where: {
                newSet.contains($0.id) && !seen.contains($0.id)
            }) {
                withAnimation(.snappy) { ambitionWin = fresh }
            }
            seenAmbitions = newSet
        }
        .task(id: ambitionWin?.id) {
            guard ambitionWin != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.5)) { ambitionWin = nil }
        }
        // ── Rival overtake: the ladder-climb moment (GDD §29) ─────────────
        .overlay(alignment: .top) {
            if let overtook {
                topBanner(title: "You overtook \(overtook)",
                          subtitle: "Another rival now sits below you on the ladder",
                          accent: Theme.cornflower, icon: "arrow.up.forward.circle.fill",
                          dismiss: { withAnimation(.easeOut(duration: 0.2)) { self.overtook = nil } })
            }
        }
        .onChange(of: engine.state.lastOvertakenRival) { _, new in
            guard let name = new else { return }
            withAnimation(.snappy) { overtook = name }
        }
        .task(id: overtook) {
            guard overtook != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.5)) { overtook = nil }
        }
        // ── Record week: a genuine career-best, bragged (GDD §38) ─────────
        .overlay(alignment: .top) {
            if let recordProfit {
                topBanner(title: "Best week ever",
                          subtitle: "\(recordProfit.money) banked — a new record",
                          accent: Theme.profit, icon: "chart.line.uptrend.xyaxis",
                          dismiss: { withAnimation(.easeOut(duration: 0.2)) { self.recordProfit = nil } })
            }
        }
        .onChange(of: engine.state.lastRecordProfit) { _, new in
            guard let profit = new else { return }
            withAnimation(.snappy) { recordProfit = profit }
        }
        .task(id: recordProfit) {
            guard recordProfit != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.5)) { recordProfit = nil }
        }
        // ── Grand-honor ceremony: #1, flag carrier (GDD §38) ──────────────
        .onChange(of: engine.state.lastHonor) { _, new in
            guard let id = new else { return }
            honorAward = makeHonorAward(for: id)
        }
        .sheet(item: $honorAward) { HonorCeremonyView(award: $0) }
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

    /// A top celebration toast, flick-up-dismissible. Extracted so `body`
    /// stays inside the type-checker's budget.
    @ViewBuilder
    private func topBanner(title: String, subtitle: String, accent: Color,
                           icon: String, dismiss: @escaping () -> Void) -> some View {
        CelebrationBanner(title: title, subtitle: subtitle, accent: accent,
                          icon: icon, onDismiss: dismiss)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Builds the ceremony copy for a grand honor (GDD §38).
    private func makeHonorAward(for id: String) -> HonorAward {
        let airline = engine.state.airlineName
        let country = engine.state.country.displayName
        switch id {
        case "rank1":
            return HonorAward(id: id, title: "Top of the Table",
                              subtitle: "\(airline) is the number-one carrier in \(country). No one flies above you.")
        default:
            return HonorAward(id: id, title: "Flag Carrier",
                              subtitle: "\(airline) now serves every city in \(country).")
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
