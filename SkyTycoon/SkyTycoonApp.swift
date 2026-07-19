//
//  SkyTycoonApp.swift
//  SkyTycoon
//
//  App entry. A GameSession owns the active engine (one of three save
//  slots); views are dumb renderers of engine state. Swapping engines
//  (load/new/delete via the slots screen) happens here and only here.
//

import SwiftUI

/// The one object allowed to swap the running engine between save slots.
@Observable
final class GameSession {
    var engine: GameEngine?
    /// Set when the player chose "New game" for a specific slot — the
    /// founding screen commits into it.
    var newGameSlot: Int? = nil
    /// One-shot: plays the cabin-window reveal over the fresh game.
    var showFoundingReveal = false

    init() {
        GameEngine.migrateLegacySave()
        engine = GameEngine.load()   // active slot, if it has a save
    }

    /// Park the current game safely before any slot operation.
    func parkCurrentGame() {
        engine?.stopClock()
        engine?.save()
    }

    func activate(slot: Int) {
        parkCurrentGame()
        GameEngine.activeSlot = slot
        engine = GameEngine.load(slot: slot)
        engine?.startClock()
    }

    func beginNewGame(inSlot slot: Int) {
        parkCurrentGame()
        newGameSlot = slot
        engine = nil
    }

    func found(airlineName: String, country: Country, difficulty: Difficulty) {
        let slot = newGameSlot ?? GameEngine.activeSlot
        GameEngine.activeSlot = slot
        let newEngine = GameEngine.newGame(airlineName: airlineName, country: country,
                                           difficulty: difficulty)
        newEngine.save()
        newEngine.startClock()
        engine = newEngine
        newGameSlot = nil
        showFoundingReveal = true
    }
}

@main
struct SkyTycoonApp: App {
    @State private var session = GameSession()

    init() {
        #if DEBUG
        // Hot reload: if the InjectionIII app is running, this bundle watches
        // the project and swaps recompiled code into the live simulator app.
        // No-op (nil bundle) on device builds or when InjectionIII is absent.
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let engine = session.engine {
                    RootView()
                        .environment(engine)
                        .onAppear { engine.startClock() }
                } else {
                    NewGameView { name, country, difficulty in
                        session.found(airlineName: name, country: country,
                                      difficulty: difficulty)
                    }
                }
            }
            .environment(session)
            // The founding moment: fly through the cabin window into the
            // brand-new airline.
            .overlay {
                if session.showFoundingReveal {
                    WindowRevealView { session.showFoundingReveal = false }
                }
            }
            #if DEBUG
            .modifier(InjectionReloader())
            #endif
        }
    }
}

#if DEBUG
/// Re-renders the whole hierarchy when InjectionIII injects new code, so
/// edited SwiftUI bodies appear without relaunching. Sim state lives in
/// GameEngine, so the redraw loses nothing.
private struct InjectionReloader: ViewModifier {
    @State private var generation = 0

    func body(content: Content) -> some View {
        content
            .id(generation)
            .task {
                let injections = NotificationCenter.default.notifications(
                    named: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
                for await _ in injections {
                    generation += 1
                }
            }
    }
}
#endif
