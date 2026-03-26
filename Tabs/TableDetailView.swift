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
    @State private var showDeleteTableConfirm = false
    @State private var showResetSessionConfirm = false
    @State private var activeSession: GameSession? = nil
    @State private var isLoadingSession = false
    // Captured at tap-time so sheet closures always have valid values even if
    // the underlying state transitions while the sheet is open.
    @State private var sessionForSheet: GameSession? = nil
    @State private var logEntryPlayer: TablePlayer? = nil
    @State private var showDisputeFund = false
    @State private var showSettlement = false

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

                    // Settlement banner (shown while table settlement is active)
                    if currentTable.isInSettlement {
                        Button { showSettlement = true } label: { settlementBanner }
                            .buttonStyle(ScaleButtonStyle())
                    }

                    // Dispute banner (if any)
                    if abs(currentTable.disputedAmount) > 0.001 {
                        Button { showDisputeFund = true } label: { disputeBanner }
                            .buttonStyle(ScaleButtonStyle())
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
                HStack(spacing: 8) {
                    // Leaderboard button
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

                    // Admin menu — only visible to admin
                    if isAdmin {
                        Menu {
                            if activeSession != nil {
                                Button(role: .destructive) {
                                    showResetSessionConfirm = true
                                } label: {
                                    Label("Reset Current Session", systemImage: "arrow.counterclockwise")
                                }
                            }
                            // Settle Table — only when no active game session
                            if activeSession == nil {
                                if currentTable.isInSettlement {
                                    Button {
                                        showSettlement = true
                                    } label: {
                                        Label("View Settlement", systemImage: "dollarsign.circle")
                                    }
                                } else {
                                    Button {
                                        Task { await vm.startTableSettlement(table: currentTable) }
                                    } label: {
                                        Label("Settle Table", systemImage: "dollarsign.circle")
                                    }
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                showDeleteTableConfirm = true
                            } label: {
                                Label("Delete Table", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.tabsPrimary)
                                .padding(10)
                                .background(Color.tabsCard)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .onAppear {
            vm.selectTable(currentTable)
            Task { await loadSession() }
        }
        .onChange(of: vm.selectedTable?.activeSessionId) { _, newId in
            if newId != activeSession?.id {
                Task { await loadSession() }
            }
        }
        .onDisappear { vm.stopListeners() }
        .sheet(isPresented: $showSettlement) {
            TableSettlementView(table: currentTable)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showDisputeFund) {
            DisputeFundView(table: currentTable)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(table: currentTable)
                .environmentObject(vm)
        }
        .sheet(isPresented: $showSession, onDismiss: { Task { await loadSession() } }) {
            // Use sessionForSheet (captured at tap time) so the sheet keeps its
            // content even after closeSession() sets activeSession → nil.
            if let session = sessionForSheet {
                NavigationStack {
                    SessionView(table: currentTable, session: session)
                        .environmentObject(vm)
                }
            }
        }
        .sheet(isPresented: $showLogEntry) {
            // Use the player captured at tap time so this closure always has
            // a valid value — re-evaluating vm.currentPlayer here can return
            // nil during a listener transition and produce a blank sheet.
            if let session = activeSession,
               let player = logEntryPlayer ?? vm.currentPlayer(for: currentTable.id) {
                LogEntryView(table: currentTable, session: session, player: player)
                    .environmentObject(vm)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(.tabsSheetRadius)
            }
        }
        .navigationDestination(item: $selectedPlayer) { player in
            PlayerDetailView(player: player, table: currentTable)
                .environmentObject(vm)
        }
        // Start new session confirmation
        .alert("Start New Session?", isPresented: $showStartSessionConfirm) {
            Button("Start") { Task { await startSession() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will open a new session for all players in \(currentTable.name).")
        }
        // Reset session confirmation
        .alert("Reset Current Session?", isPresented: $showResetSessionConfirm) {
            Button("Reset", role: .destructive) {
                Task {
                    if let session = activeSession {
                        await vm.resetSession(session)
                        await loadSession()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All submitted entries for this session will be deleted and the session will restart. This cannot be undone.")
        }
        // Delete table confirmation
        .alert("Delete \"\(currentTable.name)\"?", isPresented: $showDeleteTableConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteTable(currentTable)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the table and all its data. This cannot be undone.")
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

    // MARK: - Settlement Banner

    private var settlementBanner: some View {
        let settled = currentTable.settledPlayerIds.count
        let total   = vm.players.filter { abs($0.totalEarnings) > 0.001 }.count
        return HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(.tabsGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Table Settlement Active")
                    .font(.tabsBody(13, weight: .semibold))
                    .foregroundColor(.tabsGreen)
                Text("\(settled) of \(total) players settled")
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsGreen.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tabsGreen.opacity(0.5))
        }
        .padding(16)
        .background(Color.tabsGreen.opacity(0.08))
        .cornerRadius(.tabsCardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .tabsCardRadius)
                .strokeBorder(Color.tabsGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Dispute Banner

    private var disputeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.tabsRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dispute Fund")
                    .font(.tabsBody(13, weight: .semibold))
                    .foregroundColor(.tabsRed)
                Text(currentTable.disputedAmount.signedCurrencyString + " in unresolved disputes")
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsRed.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tabsRed.opacity(0.5))
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
                    // Capture now so the sheet still has a valid session
                    // even after closeSession() sets activeSession to nil.
                    sessionForSheet = session
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
                                .shadow(color: Color.tabsGreen.opacity(0.6), radius: 4)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session \(session.sessionNumber) — Live")
                                .font(.tabsBody(15, weight: .semibold))
                                .foregroundColor(.tabsPrimary)
                            // Live entry count — updates as players submit
                            let submitted = vm.sessionEntries.count
                            let total = currentTable.memberIds.count
                            Text("\(submitted)/\(total) entries · Started \(session.startedAt.shortDisplay)")
                                .font(.tabsBody(12))
                                .foregroundColor(submitted == total ? .tabsGreen : .tabsSecondary)
                                .contentTransition(.numericText())
                                .animation(.tabsSnap, value: submitted)
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
                        // Capture the player NOW at tap time, not lazily in
                        // the sheet closure — prevents blank sheet if
                        // vm.players transitions during a listener update.
                        logEntryPlayer = vm.currentPlayer(for: currentTable.id)
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
                .buttonStyle(TabsPrimaryButtonStyle(color: .tabsGreen))
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
                // Use enumerated so rank = index + 1 (O(N)) instead of
                // calling firstIndex per player which is O(N²).
                LazyVStack(spacing: 8) {
                    ForEach(Array(vm.players.enumerated()), id: \.element.id) { index, player in
                        Button {
                            selectedPlayer = player
                        } label: {
                            PlayerRowCard(
                                player: player,
                                rank: index + 1,
                                adminBadge: player.userId == currentTable.adminId ? .admin
                                          : currentTable.coAdminIds.contains(player.userId) ? .coAdmin
                                          : nil,
                                settlementTag: currentTable.isInSettlement
                                    ? (currentTable.settledPlayerIds.contains(player.id) ? .settled
                                       : player.totalEarnings > 0.001 ? .receives(player.totalEarnings)
                                       : player.totalEarnings < -0.001 ? .owes(abs(player.totalEarnings))
                                       : nil)
                                    : nil
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .animation(.tabsSpring, value: vm.players.count)
            }
        }
    }

    // MARK: - Actions

    private func loadSession() async {
        isLoadingSession = true
        activeSession = await vm.fetchActiveSession(tableId: currentTable.id)
        // Start the entry listener here too so the session card shows live counts
        // even when SessionView is not open.
        if let session = activeSession {
            vm.startEntryListener(tableId: currentTable.id, sessionId: session.id)
        } else {
            vm.clearEntryListener()
        }
        isLoadingSession = false
    }

    private func startSession() async {
        await vm.startSession(for: currentTable)
        await loadSession()
    }
}

// MARK: - Settlement Tag

enum SettlementTag {
    case owes(Double)      // this player needs to pay
    case receives(Double)  // this player will be paid
    case settled           // admin has marked this player done
}

// MARK: - Admin Badge Role

enum AdminBadgeRole {
    case admin    // table creator — labelled "Admin"
    case coAdmin  // promoted member — labelled "Co-Admin"

    var label: String {
        switch self {
        case .admin:   return "Admin"
        case .coAdmin: return "Co-Admin"
        }
    }
}

// MARK: - Player Row Card

struct PlayerRowCard: View {
    let player: TablePlayer
    let rank: Int
    /// Pass nil for regular members; .admin for the creator; .coAdmin for promoted members.
    var adminBadge: AdminBadgeRole? = nil
    /// Non-nil only during an active table settlement.
    var settlementTag: SettlementTag? = nil

    private static let gold = Color(red: 1.0, green: 0.76, blue: 0.0)

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

            // Admin / Co-Admin gold badge
            if let badge = adminBadge {
                Text(badge.label)
                    .font(.tabsBody(10, weight: .semibold))
                    .foregroundColor(Self.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Self.gold.opacity(0.12))
                    .cornerRadius(8)
            }

            // Settlement tag replaces earnings during active settlement
            if let tag = settlementTag {
                settlementTagView(tag)
            } else {
                Text(player.totalEarnings.signedCurrencyString)
                    .font(.tabsMono(15))
                    .foregroundColor(player.totalEarnings.earningsColor)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tabsSecondary.opacity(0.4))
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(18)
    }

    @ViewBuilder
    private func settlementTagView(_ tag: SettlementTag) -> some View {
        switch tag {
        case .settled:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.tabsGreen)
        case .owes(let amt):
            Text("–\(amt.currencyString)")
                .font(.tabsMono(13))
                .foregroundColor(.tabsRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.tabsRed.opacity(0.08))
                .cornerRadius(8)
        case .receives(let amt):
            Text("+\(amt.currencyString)")
                .font(.tabsMono(13))
                .foregroundColor(.tabsGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.tabsGreen.opacity(0.08))
                .cornerRadius(8)
        }
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
