//
//  TableSettlementView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/25/26.
//
//  Shown when an admin starts a table-level settlement.  Lets the admin mark
//  each player as paid (losers) or received (winners), then either close the
//  settlement (resets all P/L to 0) or cancel it (no data changed).
//
//  All settlement state is persisted in Firestore so the view is safe to dismiss
//  and reopen across days without losing progress.
//

import SwiftUI

struct TableSettlementView: View {
    let table: PokerTable

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isClosing = false
    @State private var isCancelling = false
    @State private var showCloseConfirm = false
    @State private var showCancelConfirm = false
    @State private var closed = false

    // Always read the live table so the UI reflects real-time Firestore updates.
    private var currentTable: PokerTable {
        vm.tables.first(where: { $0.id == table.id }) ?? table
    }

    private var isAdmin: Bool { vm.isAdmin(of: currentTable) }

    // Players who actually have a non-zero balance (zero-balance players are
    // already settled by definition and don't need manual action).
    private var activePlayers: [TablePlayer] {
        vm.players.filter { abs($0.totalEarnings) > 0.001 }
            .sorted { abs($0.totalEarnings) > abs($1.totalEarnings) }
    }

    private var settledCount: Int {
        activePlayers.filter { currentTable.settledPlayerIds.contains($0.id) }.count
    }

    private var totalCount: Int { activePlayers.count }

    private var allSettled: Bool { settledCount == totalCount && totalCount > 0 }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.tabsSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Table Settlement")
                        .font(.tabsTitle(24))
                        .foregroundColor(.tabsPrimary)
                    Text(currentTable.name)
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
                Spacer()
                DismissButton()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if closed {
                closedState
            } else {
                mainContent
            }
        }
        .background(Color.tabsBackground)
        .presentationCornerRadius(.tabsSheetRadius)
        .overlay { if isClosing || isCancelling { LoadingOverlay() } }
        // Close confirmation
        .confirmationDialog("Close Settlement?", isPresented: $showCloseConfirm, titleVisibility: .visible) {
            Button("Close & Reset All P/L to Zero", role: .destructive) {
                Task { await handleClose() }
            }
            Button("Keep Open", role: .cancel) {}
        } message: {
            Text("All player earnings will be archived to their lifetime total and reset to $0. This cannot be undone.")
        }
        // Cancel confirmation
        .confirmationDialog("Cancel Settlement?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel Settlement", role: .destructive) {
                Task { await handleCancel() }
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("No earnings will change. Settlement progress will be lost and the table returns to normal.")
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Progress header
            progressCard
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().padding(.horizontal, 24)

            // Player list
            if activePlayers.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "All balanced",
                    subtitle: "No player has a non-zero balance to settle"
                )
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Awaiting section
                        let pending = activePlayers.filter { !currentTable.settledPlayerIds.contains($0.id) }
                        if !pending.isEmpty {
                            sectionHeader("AWAITING SETTLEMENT")
                            LazyVStack(spacing: 8) {
                                ForEach(pending) { player in
                                    SettlementPlayerRow(
                                        player: player,
                                        isSettled: false,
                                        isAdmin: isAdmin
                                    ) {
                                        Task { await vm.setPlayerSettled(playerId: player.id, table: currentTable, isSettled: true) }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }

                        // Settled section
                        let settled = activePlayers.filter { currentTable.settledPlayerIds.contains($0.id) }
                        if !settled.isEmpty {
                            sectionHeader("SETTLED")
                            LazyVStack(spacing: 8) {
                                ForEach(settled) { player in
                                    SettlementPlayerRow(
                                        player: player,
                                        isSettled: true,
                                        isAdmin: isAdmin
                                    ) {
                                        Task { await vm.setPlayerSettled(playerId: player.id, table: currentTable, isSettled: false) }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 16)
                }
            }

            // Bottom actions (admin only)
            if isAdmin {
                adminActions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Progress")
                    .font(.tabsBody(13))
                    .foregroundColor(.tabsSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(settledCount)")
                        .font(.tabsMono(26))
                        .foregroundColor(.tabsPrimary)
                        .contentTransition(.numericText())
                    Text("of \(totalCount) settled")
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
            }
            Spacer()
            // Radial progress ring
            ZStack {
                Circle()
                    .stroke(Color.tabsCardSecondary, lineWidth: 6)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: totalCount > 0 ? CGFloat(settledCount) / CGFloat(totalCount) : 0)
                    .stroke(allSettled ? Color.tabsGreen : Color.tabsPrimary,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.tabsSpring, value: settledCount)
                Image(systemName: allSettled ? "checkmark" : "person.2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(allSettled ? .tabsGreen : .tabsPrimary)
            }
        }
        .padding(16)
        .background(Color.tabsCard)
        .cornerRadius(.tabsCardRadius)
    }

    // MARK: - Admin Actions

    private var adminActions: some View {
        VStack(spacing: 10) {
            Button {
                showCloseConfirm = true
            } label: {
                Group {
                    if isClosing {
                        ProgressView().tint(.white)
                    } else {
                        Label(
                            allSettled ? "Close Settlement" : "Close Settlement (incomplete)",
                            systemImage: "checkmark.seal.fill"
                        )
                    }
                }
            }
            .buttonStyle(TabsPrimaryButtonStyle(color: allSettled ? .tabsGreen : .tabsPrimary))
            .disabled(isClosing)

            Button {
                showCancelConfirm = true
            } label: {
                Text("Cancel Settlement")
            }
            .buttonStyle(TabsSecondaryButtonStyle())
            .disabled(isCancelling)
        }
    }

    // MARK: - Closed State

    private var closedState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.tabsGreen)
            Text("Settlement Complete!")
                .font(.tabsTitle(26))
                .foregroundColor(.tabsPrimary)
            Text("All player balances have been reset to $0.\nLifetime earnings have been updated.")
                .font(.tabsBody(14))
                .foregroundColor(.tabsSecondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(TabsPrimaryButtonStyle())
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.tabsBody(11, weight: .semibold))
            .foregroundColor(.tabsSecondary)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
    }

    private func handleClose() async {
        isClosing = true
        let success = await vm.closeTableSettlement(table: currentTable)
        isClosing = false
        if success {
            withAnimation(.tabsFluid) { closed = true }
        }
    }

    private func handleCancel() async {
        isCancelling = true
        await vm.cancelTableSettlement(table: currentTable)
        isCancelling = false
        dismiss()
    }
}

// MARK: - Settlement Player Row

struct SettlementPlayerRow: View {
    let player: TablePlayer
    let isSettled: Bool
    let isAdmin: Bool
    let onToggle: () -> Void

    private var amountOwed: Double { player.totalEarnings }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isSettled
                          ? Color.tabsGreen.opacity(0.12)
                          : amountOwed >= 0
                            ? Color.tabsGreen.opacity(0.08)
                            : Color.tabsRed.opacity(0.08))
                    .frame(width: 42, height: 42)
                Text(String(player.name.prefix(1)))
                    .font(.tabsBody(15, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
            }

            // Name + amount
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.tabsBody(15, weight: .semibold))
                    .foregroundColor(.tabsPrimary)

                if isSettled {
                    Text(amountOwed >= 0 ? "Has been paid" : "Has received payment")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsGreen)
                } else {
                    HStack(spacing: 4) {
                        Text(amountOwed >= 0 ? "Receives" : "Owes")
                            .font(.tabsBody(12))
                            .foregroundColor(.tabsSecondary)
                        Text(abs(amountOwed).currencyString)
                            .font(.tabsMono(12))
                            .foregroundColor(amountOwed >= 0 ? .tabsGreen : .tabsRed)
                    }
                }
            }

            Spacer()

            // Action button (admin) or settled badge (non-admin)
            if isSettled {
                if isAdmin {
                    // Admin can undo
                    Button(action: onToggle) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.tabsGreen)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.tabsGreen)
                }
            } else {
                if isAdmin {
                    Button(action: onToggle) {
                        Text(amountOwed >= 0 ? "Mark Paid" : "Mark Received")
                            .font(.tabsBody(12, weight: .semibold))
                            .foregroundColor(amountOwed >= 0 ? .tabsGreen : .tabsRed)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                (amountOwed >= 0 ? Color.tabsGreen : Color.tabsRed).opacity(0.1)
                            )
                            .cornerRadius(.tabsPillRadius)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Non-admin just sees the amount
                    Text(amountOwed.signedCurrencyString)
                        .font(.tabsMono(15))
                        .foregroundColor(amountOwed.earningsColor)
                }
            }
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(16)
        .animation(.tabsSnap, value: isSettled)
    }
}
