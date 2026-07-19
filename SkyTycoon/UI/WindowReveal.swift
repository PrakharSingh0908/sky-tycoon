//
//  WindowReveal.swift
//  SkyTycoon — UI
//
//  The cabin-window moment (Resources/Art/window_welcome.png). Two uses:
//  the founding transition — the camera flies THROUGH the porthole into
//  the new airline — and the Grounded screen's backdrop.
//

import SwiftUI

/// Founding transition: the window fills the screen, holds a beat, then
/// the camera zooms through the porthole and fades into the game.
struct WindowRevealView: View {
    var onFinished: () -> Void
    @State private var zoomed = false

    var body: some View {
        ZStack {
            Color.black
            if let window = UIImage(named: "window_welcome") {
                Image(uiImage: window)
                    .resizable()
                    .scaledToFill()
            }
        }
        .ignoresSafeArea()
        // Anchor slightly above center: the zoom dives into the sky, not
        // the seatback below the window.
        .scaleEffect(zoomed ? 3.6 : 1.0, anchor: UnitPoint(x: 0.5, y: 0.42))
        .opacity(zoomed ? 0 : 1)
        .onAppear {
            withAnimation(.easeIn(duration: 1.4).delay(0.35)) { zoomed = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.9))
            onFinished()
        }
    }
}

#Preview("Window reveal") {
    WindowRevealView {}
}
