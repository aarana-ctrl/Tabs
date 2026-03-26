//
//  LeaderboardView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct LeaderboardView: View {
    let table: PokerTable
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    /// Persisted per-device so each player's preference survives app restarts.
    @AppStorage("leaderboard_mode") private var modeRaw: String = LeaderboardMode.cycle.rawValue

    private var mode: LeaderboardMode {
        LeaderboardMode(rawValue: modeRaw) ?? .cycle
    }

    enum LeaderboardMode: String, CaseIterable {
        case cycle   = "This Cycle"
        case allTime = "All-Time"

        func earnings(for player: TablePlayer) -> Double {
            switch self {
            case .cycle:   return player.totalEarnings
            case .allTime: return player.lifetimeEarnings + player.totalEarnings
            }
        }
    }

    private var sorted: [TablePlayer] {
        vm.players.sorted { mode.earnings(for: $0) > mode.earnings(for: $1) }
    }

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leaderboard")
                            .font(.tabsTitle(28))
                            .foregroundColor(.tabsPrimary)
                        Text(table.name)
                            .font(.tabsBody(14))
                            .foregroundColor(.tabsSecondary)
                    }
                    Spacer()
                    DismissButton()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 14)

                // Mode toggle
                HStack(spacing: 0) {
                    ForEach(LeaderboardMode.allCases, id: \.self) { m in
                        Button {
                            withAnimation(.tabsSnap) { modeRaw = m.rawValue }
                        } label: {
                            Text(m.rawValue)
                                .font(.tabsBody(13, weight: .semibold))
                                .foregroundColor(mode == m ? .white : .tabsSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(mode == m ? Color.tabsPrimary : Color.clear)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(4)
                .background(Color.tabsCard)
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Podium (top 3)
                if sorted.count >= 3 {
                    podiumView
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }

                // Full list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, player in
                            LeaderboardRow(
                                player: player,
                                rank: idx + 1,
                                displayEarnings: mode.earnings(for: player)
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .presentationCornerRadius(.tabsSheetRadius)
    }

    // MARK: - Podium

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PodiumBlock(player: sorted[1], rank: 2, height: 90,  displayEarnings: mode.earnings(for: sorted[1]))
            PodiumBlock(player: sorted[0], rank: 1, height: 120, displayEarnings: mode.earnings(for: sorted[0]))
            if sorted.count >= 3 {
                PodiumBlock(player: sorted[2], rank: 3, height: 70, displayEarnings: mode.earnings(for: sorted[2]))
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Podium Block

struct PodiumBlock: View {
    let player: TablePlayer
    let rank: Int
    let height: CGFloat
    var displayEarnings: Double

    private var medalColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.76, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .tabsSecondary
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.2))
                    .frame(width: rank == 1 ? 58 : 46, height: rank == 1 ? 58 : 46)
                Text(String(player.name.prefix(1)))
                    .font(.tabsBody(rank == 1 ? 22 : 18, weight: .bold))
                    .foregroundColor(.tabsPrimary)
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(medalColor)
                        .frame(width: 20, height: 20)
                    Text("\(rank)")
                        .font(.tabsBody(11, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 2, y: 2)
            }

            Text(player.name.components(separatedBy: " ").first ?? player.name)
                .font(.tabsBody(12, weight: .semibold))
                .foregroundColor(.tabsPrimary)
                .lineLimit(1)

            Text(displayEarnings.signedCurrencyString)
                .font(.tabsMono(13))
                .foregroundColor(displayEarnings.earningsColor)

            // Podium base
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(medalColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(medalColor.opacity(0.3), lineWidth: 1.5)
                )
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let player: TablePlayer
    let rank: Int
    var displayEarnings: Double

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.76, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .tabsSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank
            Text("\(rank)")
                .font(.tabsMono(15))
                .foregroundColor(rank <= 3 ? rankColor : .tabsSecondary)
                .frame(width: 28)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color.tabsPrimary.opacity(0.08))
                    .frame(width: 38, height: 38)
                Text(String(player.name.prefix(1)))
                    .font(.tabsBody(15, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
            }

            Text(player.name)
                .font(.tabsBody(15, weight: .semibold))
                .foregroundColor(.tabsPrimary)

            Spacer()

            Text(displayEarnings.signedCurrencyString)
                .font(.tabsMono(15))
                .foregroundColor(displayEarnings.earningsColor)
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(16)
    }
}
