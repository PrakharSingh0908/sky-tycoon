//
//  SaveSlotsView.swift
//  SkyTycoon — UI
//
//  Three save slots: load, start new games, delete. The active slot is
//  the one the autosave writes; switching parks the current game first.
//

import SwiftUI

struct SaveSlotsView: View {
    @Environment(GameSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var deletingSlot: Int? = nil
    @State private var refresh = 0   // re-reads slot files after mutations

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved games")
                    .font(.display(.title2)).tracking(-0.5)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 20)
                Text("Three slots. The active game autosaves every week.")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)

                ForEach(1...GameEngine.slotCount, id: \.self) { slot in
                    slotCard(slot)
                }
                .id(refresh)

                Button("Done") { dismiss() }
                    .buttonStyle(GameButtonStyle(color: Theme.sky))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.bgElevated)
        .presentationDetents([.large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.light)
        .holdsSimClock()
        .confirmationDialog("Delete this saved game? There is no undo.",
                            isPresented: Binding(get: { deletingSlot != nil },
                                                 set: { if !$0 { deletingSlot = nil } }),
                            titleVisibility: .visible) {
            Button("Delete save", role: .destructive) {
                if let slot = deletingSlot {
                    GameEngine.deleteSave(slot: slot)
                    refresh += 1
                }
                deletingSlot = nil
            }
            Button("Keep it", role: .cancel) { deletingSlot = nil }
        }
    }

    @ViewBuilder private func slotCard(_ slot: Int) -> some View {
        let isActive = slot == GameEngine.activeSlot && session.engine != nil
        GameCard(highlight: isActive ? Theme.cornflower : nil) {
            HStack {
                Text("SLOT \(slot)")
                    .font(.data(.caption2)).tracking(0.85)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if isActive { StatusBadge(text: "Playing", color: Theme.cornflower) }
            }
            if let state = GameEngine.slotState(slot) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.airlineName)
                            .font(.game(.headline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(state.country.displayName) · \(state.date.description) · \((state.difficulty ?? .standard).displayName)")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        TickerText(text: state.cash.money,
                                   font: .game(.subheadline, weight: .semibold),
                                   color: state.cash >= 0 ? Theme.profit : Theme.loss)
                        Text("Cash").font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                }
                HStack(spacing: 8) {
                    if !isActive {
                        Button("Load") {
                            session.activate(slot: slot)
                            dismiss()
                        }
                        .buttonStyle(GameButtonStyle(color: Theme.sky, prominent: true))
                    }
                    Button("New game") {
                        session.beginNewGame(inSlot: slot)
                        dismiss()
                    }
                    .buttonStyle(GameButtonStyle(color: Theme.sky))
                    Spacer()
                    if !isActive {
                        Button("Delete") { deletingSlot = slot }
                            .buttonStyle(GameButtonStyle(color: Theme.loss))
                    }
                }
            } else {
                Text("Empty slot")
                    .font(.game(.subheadline)).foregroundStyle(Theme.textTertiary)
                Button("New game") {
                    session.beginNewGame(inSlot: slot)
                    dismiss()
                }
                .buttonStyle(GameButtonStyle(color: Theme.sky, prominent: true))
            }
        }
    }
}

#Preview {
    SaveSlotsView()
        .environment(GameSession())
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.light)
}
