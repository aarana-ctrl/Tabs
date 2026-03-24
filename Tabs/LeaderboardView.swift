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

    private var sorted: [TablePlayer] {
        vm.players.sorted { $0.totalEarnings > $1.totalEarnings }
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
                .padding(24)

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
                            LeaderboardRow(player: player, rank: idx + 1)
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
            // 2nd place
            PodiumBlock(player: sorted[1], rank: 2, height: 90)

            // 1st place
            PodiumBlock(player: sorted[0], rank: 1, height: 120)

            // 3rd place (if exists)
            if sorted.count >= 3 {
                PodiumBlock(player: sorted[2], rank: 3, height: 70)
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

            Text(player.totalEarnings.signedCurrencyString)
                .font(.tabsMono(13))
                .foregroundColor(player.totalEarnings.earningsColor)

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

            // Bar visualization (relative to max)
            Text(player.totalEarnings.signedCurrencyString)
                .font(.tabsMono(15))
                .foregroundColor(player.totalEarnings.earningsColor)
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(16)
    }
}
