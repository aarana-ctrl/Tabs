//
//  DisputeFundView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/24/26.
//
//  Sheet showing the full dispute fund history for a table, with an
//  admin-only "Settle Dispute" button at the bottom.
//

import SwiftUI

struct DisputeFundView: View {
    let table: PokerTable

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var disputedSessions: [GameSession] = []
    @State private var isLoading = true
    @State private var showSettleOptions = false
    @State private var isSettling = false

    private var currentTable: PokerTable {
        vm.tables.first(where: { $0.id == table.id }) ?? table
    }

    private var isAdmin: Bool { vm.isAdmin(of: currentTable) }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.tabsSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header row
            HStack {
                Text("Dispute Fund")
                    .font(.tabsTitle(24))
                    .foregroundColor(.tabsPrimary)
                Spacer()
                DismissButton()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Current balance
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT BALANCE")
                        .font(.tabsBody(11, weight: .semibold))
                        .foregroundColor(.tabsSecondary)
                        .tracking(1.5)
                    Text(currentTable.disputedAmount.signedCurrencyString)
                        .font(.tabsMono(30))
                        .foregroundColor(currentTable.disputedAmount.earningsColor)
                        .contentTransition(.numericText())
                        .animation(.tabsSnap, value: currentTable.disputedAmount)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 24)

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading history…")
                    .foregroundColor(.tabsSecondary)
                Spacer()
            } else if disputedSessions.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No disputes recorded",
                    subtitle: "Settled sessions with a dispute amount will appear here"
                )
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DISPUTE HISTORY")
                            .font(.tabsBody(11, weight: .semibold))
                            .foregroundColor(.tabsSecondary)
                            .tracking(1.5)
                            .padding(.top, 16)

                        LazyVStack(spacing: 8) {
                            ForEach(disputedSessions) { session in
                                DisputeSessionRow(session: session)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            // Bottom settle area
            VStack(spacing: 8) {
                if !isAdmin {
                    Text("Only admins can settle the dispute fund")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    if isAdmin { showSettleOptions = true }
                } label: {
                    Group {
                        if isSettling {
                            ProgressView()
                                .tint(isAdmin ? .white : .tabsSecondary)
                        } else {
                            Text("Settle Dispute")
                                .font(.tabsBody(17, weight: .semibold))
                                .foregroundColor(isAdmin ? .white : .tabsSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isAdmin ? Color.tabsPrimary : Color.tabsCardSecondary)
                    .cornerRadius(20)
                }
                .disabled(!isAdmin || isSettling)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .padding(.top, 12)
        }
        .background(Color.tabsBackground)
        .presentationCornerRadius(.tabsSheetRadius)
        // Admin action sheet
        .confirmationDialog("How would you like to settle?", isPresented: $showSettleOptions, titleVisibility: .visible) {
            Button("Split Evenly Among All Players") {
                Task { await handleSettle(.split) }
            }
            Button("Reset to Zero (Write Off)", role: .destructive) {
                Task { await handleSettle(.reset) }
            }
            Button("Leave As Is", role: .cancel) {}
        } message: {
            Text("Fund balance: \(currentTable.disputedAmount.signedCurrencyString)")
        }
        .task {
            disputedSessions = await vm.fetchDisputedSessions(tableId: table.id)
            isLoading = false
        }
    }

    // MARK: - Settle Handler

    private func handleSettle(_ mode: SettleMode) async {
        isSettling = true
        let success: Bool
        switch mode {
        case .split:
            success = await vm.settleDisputeSplit(table: currentTable)
        case .reset:
            success = await vm.resetDisputeFund(tableId: currentTable.id)
        }
        isSettling = false
        if success { dismiss() }
    }

    private enum SettleMode { case split, reset }
}

// MARK: - Dispute Session Row

struct DisputeSessionRow: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.tabsRed.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.tabsRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Session \(session.sessionNumber)")
                    .font(.tabsBody(15, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Text(session.endedAt?.shortDisplay ?? session.startedAt.shortDisplay)
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsSecondary)
            }

            Spacer()

            Text(session.disputedAmount.signedCurrencyString)
                .font(.tabsMono(15))
                .foregroundColor(session.disputedAmount.earningsColor)
        }
        .padding(14)
        .background(Color.tabsCard)
        .cornerRadius(16)
    }
}
