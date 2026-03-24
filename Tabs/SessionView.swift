//
//  SessionView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct SessionView: View {
    let table: PokerTable
    let session: GameSession

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var entries: [SessionEntry] = []
    @State private var players: [TablePlayer] = []
    @State private var showSettlement = false
    @State private var isClosing = false

    private var isAdmin: Bool { vm.isAdmin(of: table) }

    private var totalNet: Double { entries.reduce(0) { $0 + $1.netAmount } }

    private var submittedPlayerIds: Set<String> { Set(entries.map { $0.playerId }) }

    private var pendingPlayers: [TablePlayer] {
        players.filter { !submittedPlayerIds.contains($0.id) }
    }

    private var allSubmitted: Bool { pendingPlayers.isEmpty && !players.isEmpty }

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Session header
                    sessionHeader

                    // Balance check
                    balanceCard

                    // Submitted entries
                    if !entries.isEmpty {
                        submittedEntriesSection
                    }

                    // Pending players
                    if !pendingPlayers.isEmpty {
                        pendingSection
                    }

                    // Admin close button
                    if isAdmin {
                        adminControls
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Session \(session.sessionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            players = vm.players
            vm.startEntryListener(tableId: table.id, sessionId: session.id)
        }
        .onChange(of: vm.sessionEntries) { _, new in
            entries = new
        }
        .sheet(isPresented: $showSettlement) {
            SettlementView(
                table: table,
                session: session,
                entries: entries,
                totalNet: totalNet
            )
            .environmentObject(vm)
        }
        .overlay { if isClosing { LoadingOverlay() } }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.tabsGreen)
                        .frame(width: 8, height: 8)
                    Text("Session \(session.sessionNumber) — Active")
                        .font(.tabsBody(13, weight: .semibold))
                        .foregroundColor(.tabsGreen)
                }
                Text("Started " + session.startedAt.shortDisplay)
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entries.count)/\(players.count)")
                    .font(.tabsMono(22))
                    .foregroundColor(.tabsPrimary)
                Text("entries in")
                    .font(.tabsBody(12))
                    .foregroundColor(.tabsSecondary)
            }
        }
        .tabsCard()
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        let isBalanced = abs(totalNet) < 0.01

        return VStack(spacing: 10) {
            HStack {
                Text("Table Balance")
                    .font(.tabsBody(14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Spacer()
                if entries.isEmpty {
                    Text("Waiting for entries")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                } else if isBalanced {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.tabsGreen)
                        Text("Balanced")
                            .font(.tabsBody(13, weight: .semibold))
                            .foregroundColor(.tabsGreen)
                    }
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.tabsRed)
                        Text("Off by \(abs(totalNet).currencyString)")
                            .font(.tabsBody(13, weight: .semibold))
                            .foregroundColor(.tabsRed)
                    }
                }
            }

            // Visual balance bar
            if !entries.isEmpty {
                GeometryReader { geo in
                    let wins = entries.filter { $0.netAmount > 0 }.reduce(0) { $0 + $1.netAmount }
                    let losses = entries.filter { $0.netAmount < 0 }.reduce(0) { $0 + abs($1.netAmount) }
                    let total = wins + losses
                    let winFrac = total > 0 ? wins / total : 0.5

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.tabsRed.opacity(0.25))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.tabsGreen)
                            .frame(width: geo.size.width * winFrac, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .tabsCard()
    }

    // MARK: - Submitted Entries

    private var submittedEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUBMITTED")
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.5)

            LazyVStack(spacing: 8) {
                ForEach(entries) { entry in
                    SessionEntryCard(entry: entry)
                }
            }
        }
    }

    // MARK: - Pending Players

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WAITING FOR")
                .font(.tabsBody(11, weight: .semibold))
                .foregroundColor(.tabsSecondary)
                .tracking(1.5)

            LazyVStack(spacing: 8) {
                ForEach(pendingPlayers) { player in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.tabsPrimary.opacity(0.07))
                                .frame(width: 36, height: 36)
                            Text(String(player.name.prefix(1)))
                                .font(.tabsBody(14, weight: .semibold))
                                .foregroundColor(.tabsPrimary)
                        }
                        Text(player.name)
                            .font(.tabsBody(15))
                            .foregroundColor(.tabsPrimary)
                        Spacer()
                        Text("Pending")
                            .font(.tabsBody(12, weight: .medium))
                            .foregroundColor(.tabsSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.tabsCardSecondary)
                            .cornerRadius(.tabsPillRadius)
                    }
                    .padding(12)
                    .background(Color.tabsCard)
                    .cornerRadius(14)
                }
            }
        }
    }

    // MARK: - Admin Controls

    private var adminControls: some View {
        VStack(spacing: 12) {
            if allSubmitted {
                // All in — show settle button
                Button {
                    showSettlement = true
                } label: {
                    Label("Settle Session", systemImage: "checkmark.seal.fill")
                        .font(.tabsBody(16, weight: .semibold))
                }
                .buttonStyle(TabsPrimaryButtonStyle(color: .tabsGreen))
            } else {
                // Force close even if not all in
                Button {
                    showSettlement = true
                } label: {
                    Label("Close & Settle (\(pendingPlayers.count) missing)", systemImage: "xmark.seal")
                        .font(.tabsBody(15, weight: .semibold))
                }
                .buttonStyle(TabsSecondaryButtonStyle())
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Session Entry Card

struct SessionEntryCard: View {
    let entry: SessionEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(entry.netAmount >= 0
                          ? Color.tabsGreen.opacity(0.12)
                          : Color.tabsRed.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text(String(entry.playerName.prefix(1)))
                    .font(.tabsBody(14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.playerName)
                    .font(.tabsBody(14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                if !entry.isManualNet {
                    Text("Buy-in \(entry.buyIn.currencyString) · Out \(entry.finalAmount.currencyString)")
                        .font(.tabsBody(11))
                        .foregroundColor(.tabsSecondary)
                }
            }
            Spacer()
            Text(entry.netAmount.signedCurrencyString)
                .font(.tabsMono(16))
                .foregroundColor(entry.netAmount.earningsColor)
        }
        .padding(12)
        .background(Color.tabsCard)
        .cornerRadius(14)
    }
}

// MARK: - Settlement View

struct SettlementView: View {
    let table: PokerTable
    let session: GameSession
    let entries: [SessionEntry]
    let totalNet: Double

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedResolution: DisputeResolution = .disputeFund
    @State private var isSettling = false
    @State private var settled = false

    private var isBalanced: Bool { abs(totalNet) < 0.01 }
    private var disputeAmt: Double { abs(totalNet) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.tabsSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isBalanced ? "Session Balanced!" : "Session Settlement")
                            .font(.tabsTitle(28))
                            .foregroundColor(.tabsPrimary)
                        Text("Session \(session.sessionNumber) · \(table.name)")
                            .font(.tabsBody(14))
                            .foregroundColor(.tabsSecondary)
                    }

                    if settled {
                        settledState
                    } else if isBalanced {
                        balancedState
                    } else {
                        disputedState
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.tabsBackground)
        .presentationCornerRadius(.tabsSheetRadius)
        .overlay { if isSettling { LoadingOverlay() } }
    }

    // MARK: - Balanced State

    private var balancedState: some View {
        VStack(spacing: 20) {
            // Summary
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.tabsGreen)
                Text("All entries balance perfectly.")
                    .font(.tabsBody(15))
                    .foregroundColor(.tabsSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            entrySummaryList

            Button {
                Task { await settle() }
            } label: {
                Group {
                    if isSettling {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Label("Confirm & Complete Session", systemImage: "checkmark.circle.fill")
                    }
                }
            }
            .buttonStyle(TabsPrimaryButtonStyle(color: .tabsGreen))
        }
    }

    // MARK: - Disputed State

    private var disputedState: some View {
        VStack(spacing: 20) {
            // Dispute amount
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.tabsRed)
                Text("Amounts don't balance")
                    .font(.tabsBody(16, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Text("Dispute amount: \(disputeAmt.currencyString)")
                    .font(.tabsMono(24))
                    .foregroundColor(.tabsRed)
            }
            .frame(maxWidth: .infinity)

            entrySummaryList

            // Resolution picker
            VStack(alignment: .leading, spacing: 10) {
                Text("HOW TO HANDLE THE DISPUTE")
                    .font(.tabsBody(11, weight: .semibold))
                    .foregroundColor(.tabsSecondary)
                    .tracking(1.2)

                resolutionOption(
                    title: "Log to Dispute Fund",
                    subtitle: "Track \(disputeAmt.currencyString) as unresolved on the table",
                    icon: "archivebox",
                    value: .disputeFund
                )
                resolutionOption(
                    title: "Split Evenly",
                    subtitle: "Deduct \((disputeAmt / Double(max(entries.count, 1))).currencyString) from each player",
                    icon: "person.3",
                    value: .splitEvenly
                )
            }

            Button {
                Task { await settle() }
            } label: {
                Group {
                    if isSettling {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Confirm Settlement")
                    }
                }
            }
            .buttonStyle(TabsPrimaryButtonStyle(color: .tabsPrimary))
        }
    }

    // MARK: - Settled State

    private var settledState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.tabsGreen)
            Text("Session Complete!")
                .font(.tabsTitle(26))
                .foregroundColor(.tabsPrimary)
            Text("All stats have been updated.")
                .font(.tabsBody(14))
                .foregroundColor(.tabsSecondary)

            Button("Done") { dismiss() }
                .buttonStyle(TabsPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Entry Summary

    private var entrySummaryList: some View {
        VStack(spacing: 8) {
            ForEach(entries) { entry in
                HStack {
                    Text(entry.playerName)
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsPrimary)
                    Spacer()
                    Text(entry.netAmount.signedCurrencyString)
                        .font(.tabsMono(14))
                        .foregroundColor(entry.netAmount.earningsColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.tabsCard)
                .cornerRadius(12)
            }

            Divider()
                .padding(.horizontal, 4)

            HStack {
                Text("Net total")
                    .font(.tabsBody(14, weight: .semibold))
                    .foregroundColor(.tabsPrimary)
                Spacer()
                Text(totalNet.signedCurrencyString)
                    .font(.tabsMono(15))
                    .foregroundColor(isBalanced ? .tabsGreen : .tabsRed)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Resolution Option

    private func resolutionOption(
        title: String,
        subtitle: String,
        icon: String,
        value: DisputeResolution
    ) -> some View {
        Button {
            selectedResolution = value
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedResolution == value
                              ? Color.tabsPrimary
                              : Color.tabsCardSecondary)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(selectedResolution == value ? .white : .tabsSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.tabsBody(14, weight: .semibold))
                        .foregroundColor(.tabsPrimary)
                    Text(subtitle)
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(selectedResolution == value
                                      ? Color.tabsPrimary
                                      : Color.tabsSecondary.opacity(0.3),
                                      lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selectedResolution == value {
                        Circle()
                            .fill(Color.tabsPrimary)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.tabsCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                selectedResolution == value
                                    ? Color.tabsPrimary.opacity(0.3)
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settle Action

    private func settle() async {
        isSettling = true
        let dispAmount = isBalanced ? 0.0 : disputeAmt
        await vm.settleSession(
            session: session,
            entries: entries,
            resolution: selectedResolution,
            disputeAmount: dispAmount
        )
        isSettling = false
        withAnimation { settled = true }
    }
}
