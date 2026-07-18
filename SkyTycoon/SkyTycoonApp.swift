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

    var body: some Scene {
        WindowGroup {
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
    }
}
