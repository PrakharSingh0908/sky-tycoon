//
//  NewGameView.swift
//  SkyTycoon — UI
//
//  The first screen (M8): name your airline, pick your country. India is
//  the MVP; the other four show their fantasy and wait for v1.0 — the
//  shape of the bigger game is visible from day one.
//

import SwiftUI

struct NewGameView: View {
    let onStart: (String, Country, Difficulty) -> Void
    @State private var airlineName = ""
    @State private var difficulty: Difficulty = .standard
    @FocusState private var nameFocused: Bool

    private static let fantasies: [Country: (flag: String, blurb: String)] = [
        .india: ("🇮🇳", "The volume game: 1.4B people, cheap fares, ferocious growth."),
        .us: ("🇺🇸", "The efficiency game: strong majors, union power."),
        .uk: ("🇬🇧", "The premium hub game: slots are the real currency."),
        .china: ("🇨🇳", "The patience game: licenses, guanxi, long horizons."),
        .australia: ("🇦🇺", "The optimization game: long thin routes, right plane or bust."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SkyTycoon")
                        .font(.game(.largeTitle, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("Your aunt left you $2.4M and one condition: make it fly.")
                        .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 24)

                AircraftPhotoView(type: .propeller30)
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)

                GameCard {
                    SectionHeader(title: "Your airline", icon: "airplane.circle.fill", accent: Theme.sky)
                    TextField("Airline name", text: $airlineName)
                        .font(.game(.title3, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .keyboardType(.asciiCapable)
                        // Case bugs here are keyboard-language issues, not
                        // field config: Hinglish (hi_Latn) is ASCII QWERTY,
                        // so asciiCapable can't exclude it, and it flattens
                        // capitals. Needs an English keyboard active.
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }

                GameCard {
                    SectionHeader(title: "Home country", icon: "globe.asia.australia.fill", accent: Theme.teal)
                    ForEach(Country.allCases) { country in
                        countryRow(country)
                    }
                }

                GameCard {
                    SectionHeader(title: "Difficulty", icon: "dial.medium.fill", accent: Theme.violet)
                    ForEach(Difficulty.allCases) { level in
                        difficultyRow(level)
                    }
                }

            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 16)
        }
        .background(Theme.bg)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { foundButton }
        .preferredColorScheme(.dark)
        .onAppear { nameFocused = true }
    }

    private var canFound: Bool {
        !airlineName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Docked above the safe area (and the keyboard) in a solid box.
    /// Disabled state stays at full opacity — neutral colors plus a hint
    /// line, so the label never drops below readable contrast.
    private var foundButton: some View {
        VStack(spacing: 8) {
            Button {
                onStart(airlineName.trimmingCharacters(in: .whitespaces), .india, difficulty)
            } label: {
                Text("Found the airline").frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(color: canFound ? Theme.sky : Theme.textSecondary,
                                         prominent: canFound))
            .disabled(!canFound)
            if !canFound {
                Text("Enter an airline name to take off.")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            Theme.bgElevated
                .overlay(alignment: .top) { Theme.hairline.frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func difficultyRow(_ level: Difficulty) -> some View {
        Button {
            difficulty = level
        } label: {
            HStack(spacing: 10) {
                Image(systemName: difficulty == level ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(difficulty == level ? Theme.violet : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.game(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(level.blurb)
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .fill(difficulty == level ? Theme.violet.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: difficulty)
    }

    private func countryRow(_ country: Country) -> some View {
        let fantasy = Self.fantasies[country]!
        let available = country == .india
        return HStack(spacing: 10) {
            Text(fantasy.flag).font(.title2)
                .saturation(available ? 1 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(country.displayName)
                    .font(.game(.subheadline, weight: .semibold))
                    .foregroundStyle(available ? Theme.textPrimary : Theme.textSecondary)
                Text(fantasy.blurb)
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if available {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.teal)
            } else {
                StatusBadge(text: "Coming soon", color: Theme.textSecondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(available ? Theme.teal.opacity(0.08) : .clear)
        )
        .opacity(available ? 1 : 0.6)
    }
}

#Preview {
    NewGameView { _, _, _ in }
}
