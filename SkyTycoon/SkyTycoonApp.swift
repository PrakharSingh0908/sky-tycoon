//
//  SkyTycoonApp.swift
//  SkyTycoon
//
//  App entry. The engine is created once (loaded from save, or a fresh
//  new game) and injected into the environment. Views are dumb renderers
//  of engine state.
//

import SwiftUI

@main
struct SkyTycoonApp: App {
    /// nil until a save exists or the player founds an airline (M8).
    @State private var engine: GameEngine? = GameEngine.load()

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
                if let engine {
                    RootView()
                        .environment(engine)
                        .onAppear { engine.startClock() }
                } else {
                    NewGameView { name, country in
                        let newEngine = GameEngine.newGame(airlineName: name, country: country)
                        newEngine.save()
                        engine = newEngine
                    }
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
