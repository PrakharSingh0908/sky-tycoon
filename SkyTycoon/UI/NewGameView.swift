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
    let onStart: (String, Country) -> Void
    @State private var airlineName = ""
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

                Button {
                    onStart(airlineName.trimmingCharacters(in: .whitespaces), .india)
                } label: {
                    Text("Found the airline").frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: Theme.sky, prominent: true))
                .disabled(airlineName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(airlineName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .background(Theme.bg)
        .scrollIndicators(.hidden)
        .preferredColorScheme(.dark)
        .onAppear { nameFocused = true }
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
    NewGameView { _, _ in }
}
