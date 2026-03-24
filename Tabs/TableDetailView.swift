//
//  TableDetailView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct TableDetailView: View {
    let table: PokerTable

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showLeaderboard = false
    @State private var showSession = false
    @State private var showLogEntry = false
    @State private var selectedPlayer: TablePlayer? = nil
    @State private var showStartSessionConfirm = false
    @State private var activeSession: GameSession? = nil
    @State private var isLoadingSession = false

    private var currentTable: PokerTable {
        vm.tables.first(where: { $0.id == table.id }) ?? table
    }

    private var isAdmin: Bool { vm.isAdmin(of: currentTable) }

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Top summary card
                    summaryCard

                    // Dispute banner (if any)
                    if currentTable.disputedAmount > 0 {
                        disputeBanner
                    }

                    // Session action area
                    sessionSection

                    // Players list
                    playersSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(currentTable.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showLeaderboard = true
                } label: {
                    Label("Leaderboard", systemImage: "trophy.fill")
                        .font(.tabsBody(13, weight: .semibold))
                        .foregroundColor(.tabsPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.tabsCard)
                        .cornerRadius(.tabsPillRadius)
                }
            }
        }
        .onAppear {
            vm.selectTable(currentTable)
            Task { await loadSession() }
        }
        .onDisappear { vm.stopListeners() }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(table: currentTable)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showSession, onDismiss: { Task { await loadSession() } }) {
            if let session = activeSession {
                SessionView(table: currentTable, session: session)
                    .environmentObject(vm)
            }
        }
        .sheet(isPresented: $showLogEntry) {
            if let player = vm.currentPlayer(for: currentTable.id) {
                LogEntryView(table: currentTable, player: player)
                    .environmentObject(vm)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(.tabsSheetRadius)
            }
        }
        .navigationDestination(item: $selectedPlayer) { player in
            PlayerDetailView(player: player, table: currentTable)
                .environmentObject(vm)
        }
        .alert("Start New Session?", isPresented: $showStartSessionConfirm) {
            Button("Start") { Task { await startSession() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will open a new session for all players in \(currentTable.name).")
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reference Code")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                    Text(currentTable.referenceCode)
                        .font(.tabsMono(22))
                        .foregroundColor(.tabsPrimary)
                        .tracking(4)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Players")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                    Text("\(currentTable.memberIds.count)")
                        .font(.tabsMono(22))
                        .foregroundColor(.tabsPrimary)
                }
            }
        }
        .tabsCard()
    }

    // MARK: - Dispute Banner

    private var disputeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.tabsRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("Disputed Amount")
                    .font(.tabsBody(13, weight: .semibold))
                    .foregroundColor(.tabsRed)
                Text(currentTable.disputedAmount.currencyString + " in unresolved disputes")
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsRed.opacity(0.8))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.tabsRed.opacity(0.08))
        .cornerRadius(.tabsCardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .tabsCardRadius)
                .strokeBorder(Color.tabsRed.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Session Section

    private var sessionSection: some View {
        VStack(spacing: 10) {
            if let session = activeSession {
                // Active session card
                Button {
                    showSession = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.tabsGreen.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Circle()
                                .fill(Color.tabsGreen)
                                .frame(width: 12, height: 12)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session \(session.sessionNumber) — Live")
                                .font(.tabsBody(15, weight: .semibold))
                                .foregroundColor(.tabsPrimary)
                            Text("Started \(session.startedAt.shortDisplay)")
                                .font(.tabsBody(12))
                                .foregroundColor(.tabsSecondary)
                        }
                        Spacer()
                        Text("View")
                            .font(.tabsBody(13, weight: .semibold))
                            .foregroundColor(.tabsGreen)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.tabsGreen.opacity(0.1))
                            .cornerRadius(.tabsPillRadius)
                    }
                    .tabsCard()
                }
                .buttonStyle(.plain)

                // Log entry button for current player
                if vm.currentPlayer(for: currentTable.id) != nil {
                    Button {
                        showLogEntry = true
                    } label: {
                        Label("Log My Entry", systemImage: "pencil.and.list.clipboard")
                            .font(.tabsBody(15, weight: .semibold))
                    }
                    .buttonStyle(TabsSecondaryButtonStyle())
                }

            } else if isAdmin {
                // Start session button (admin only)
                Button {
                    showStartSessionConfirm = true
                } label: {
                    Label("Start New Session", systemImage: "play.fill")
                        .font(.tabsBody(15, weight: .semibold))
                }
                .buttonStyle(TabsPrimaryButtonStyle(color: .tabsPrimary))
            } else {
                // No session, not admin
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundColor(.tabsSecondary)
                    Text("Waiting for admin to start a session")
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Players Section

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLAYERS")
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.5)

            if vm.players.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(vm.players) { player in
                        Button {
                            selectedPlayer = player
                        } label: {
                            PlayerRowCard(player: player, rank: rankOf(player))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func rankOf(_ player: TablePlayer) -> Int {
        (vm.players.firstIndex(where: { $0.id == player.id }) ?? 0) + 1
    }

    // MARK: - Actions

    private func loadSession() async {
        isLoadingSession = true
        activeSession = await vm.fetchActiveSession(tableId: currentTable.id)
        isLoadingSession = false
    }

    private func startSession() async {
        await vm.startSession(for: currentTable)
        await loadSession()
    }
}

// MARK: - Player Row Card

struct PlayerRowCard: View {
    let player: TablePlayer
    let rank: Int

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("\(rank)")
                    .font(.tabsBody(14, weight: .bold))
                    .foregroundColor(rankColor)
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(Color.tabsPrimary.opacity(0.08))
                    .frame(width: 40, height: 40)
                Text(String(player.name.prefix(1)))
                    .font(.tabsBody(16, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.tabsBody(15, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Text("All-time")
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsSecondary)
            }

            Spacer()

            Text(player.totalEarnings.signedCurrencyString)
                .font(.tabsMono(16))
                .foregroundColor(player.totalEarnings.earningsColor)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tabsSecondary.opacity(0.4))
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(18)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.76, blue: 0.0)   // gold
        case 2: return Color(red: 0.63, green: 0.63, blue: 0.68) // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
        default: return .tabsSecondary
        }
    }
}
