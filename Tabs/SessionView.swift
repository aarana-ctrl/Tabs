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
    @State private var editingEntry: SessionEntry? = nil

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

                    // Submitted entries — animate in as each new entry arrives
                    if !entries.isEmpty {
                        submittedEntriesSection
                            .transition(.push(from: .top).combined(with: .opacity))
                            .animation(.tabsSpring, value: entries.count)
                    }

                    // Pending players
                    if !pendingPlayers.isEmpty {
                        pendingSection
                            .animation(.tabsSpring, value: pendingPlayers.count)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Back")
                            .font(.tabsBody(16))
                    }
                    .foregroundColor(.tabsPrimary)
                }
            }
        }
        .onAppear {
            players = vm.players
            // Seed from current state immediately — onChange only fires on
            // *changes*, so if vm.sessionEntries already has entries when this
            // view appears, it would stay empty without this line.
            entries = vm.sessionEntries
            vm.startEntryListener(tableId: table.id, sessionId: session.id)
        }
        .onChange(of: vm.sessionEntries) { _, new in
            withAnimation(.tabsSpring) { entries = new }
        }
        .sheet(isPresented: $showSettlement) {
            SettlementView(
                table: table,
                session: session,
                entries: entries,
                totalNet: totalNet
            )
            .environmentObject(vm)
            .interactiveDismissDisabled(false)
        }
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry)
                .environmentObject(vm)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(.tabsSheetRadius)
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
            HStack {
                Text("SUBMITTED")
                    .font(.tabsBody(11, weight: .semibold))
                    .foregroundColor(.tabsSecondary)
                    .tracking(1.5)
                if isAdmin {
                    Spacer()
                    Text("Tap to edit")
                        .font(.tabsBody(11))
                        .foregroundColor(.tabsSecondary)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(entries) { entry in
                    if isAdmin {
                        Button { editingEntry = entry } label: {
                            SessionEntryCard(entry: entry, showEditChevron: true)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    } else {
                        SessionEntryCard(entry: entry)
                            .transition(.asymmetric(
                                insertion: .push(from: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
            }
            .animation(.tabsSpring, value: entries.count)
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
    var showEditChevron: Bool = false

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
            if showEditChevron {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.tabsSecondary.opacity(0.5))
                    .padding(.leading, 2)
            }
        }
        .padding(12)
        .background(Color.tabsCard)
        .cornerRadius(14)
    }
}

// MARK: - Edit Entry Sheet (Admin)
// Allows any admin or co-admin to correct a submitted entry during an active
// session.  Pre-fills from the existing entry so the admin only needs to change
// what's wrong.

struct EditEntrySheet: View {
    let entry: SessionEntry

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var entryMode: EntryMode
    @State private var buyInText: String
    @State private var cashOutText: String
    @State private var netText: String
    @State private var isSaving = false
    @State private var saved = false
    @State private var saveFailed = false

    enum EntryMode: String, CaseIterable {
        case buyInOut = "Buy-in / Final"
        case netOnly  = "Net Amount"
    }

    init(entry: SessionEntry) {
        self.entry = entry
        _entryMode  = State(initialValue: entry.isManualNet ? .netOnly : .buyInOut)
        _buyInText  = State(initialValue: entry.isManualNet ? "" : Self.fmt(entry.buyIn))
        _cashOutText = State(initialValue: entry.isManualNet ? "" : Self.fmt(entry.finalAmount))
        _netText    = State(initialValue: entry.isManualNet ? Self.fmt(entry.netAmount) : "")
    }

    private static func fmt(_ v: Double) -> String {
        v == 0 ? "" : String(format: "%g", v)
    }

    private var computedNet: Double? {
        switch entryMode {
        case .buyInOut:
            guard let b = Double(buyInText), let o = Double(cashOutText) else { return nil }
            return o - b
        case .netOnly:
            return Double(netText)
        }
    }

    private var canSave: Bool { computedNet != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Edit Entry")
                        .font(.tabsTitle(26))
                        .foregroundColor(.tabsPrimary)
                    Text(entry.playerName)
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
                Spacer()
                DismissButton()
            }

            if saved {
                savedState
            } else {
                editForm
            }

            Spacer()
        }
        .padding(24)
        .background(Color.tabsBackground)
    }

    // MARK: - Edit Form

    private var editForm: some View {
        VStack(spacing: 20) {
            // Mode toggle
            HStack(spacing: 0) {
                ForEach(EntryMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.tabsSnap) { entryMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.tabsBody(13, weight: .semibold))
                            .foregroundColor(entryMode == mode ? .white : .tabsSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(entryMode == mode ? Color.tabsPrimary : Color.clear)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(4)
            .background(Color.tabsCard)
            .cornerRadius(16)

            if entryMode == .buyInOut {
                VStack(spacing: 12) {
                    CurrencyField(label: "Total Buy-in", text: $buyInText)
                    CurrencyField(label: "Final Amount (chips out)", text: $cashOutText)
                    if let net = computedNet {
                        HStack {
                            Text("Net result:")
                                .font(.tabsBody(14))
                                .foregroundColor(.tabsSecondary)
                            Spacer()
                            Text(net.signedCurrencyString)
                                .font(.tabsMono(18))
                                .foregroundColor(net.earningsColor)
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(net >= 0 ? Color.tabsGreen.opacity(0.08) : Color.tabsRed.opacity(0.08))
                        .cornerRadius(.tabsButtonRadius)
                        .animation(.tabsSnap, value: net)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    CurrencyField(label: "Net amount (– for a loss)", text: $netText, allowNegative: true)
                    Text("Positive = win (e.g. 120) · Negative = loss (e.g. –45)")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                        .padding(.horizontal, 4)
                }
            }

            Button {
                Task { await saveEdit() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Label("Save Changes", systemImage: "checkmark")
                    }
                }
            }
            .buttonStyle(TabsPrimaryButtonStyle(color: .tabsPrimary))
            .disabled(!canSave || isSaving)
            .opacity(canSave ? 1 : 0.45)

            if saveFailed {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.tabsRed)
                    Text(vm.errorMessage ?? "Save failed — please try again.")
                        .font(.tabsBody(13))
                        .foregroundColor(.tabsRed)
                }
                .padding(14)
                .background(Color.tabsRed.opacity(0.08))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Saved State

    private var savedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.tabsGreen)
            Text("Entry Updated")
                .font(.tabsTitle(26))
                .foregroundColor(.tabsPrimary)
            if let net = computedNet {
                Text(net.signedCurrencyString)
                    .font(.tabsMono(32))
                    .foregroundColor(net.earningsColor)
            }
            Button("Done") { dismiss() }
                .buttonStyle(TabsPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Save

    @MainActor
    private func saveEdit() async {
        guard let net = computedNet else { return }
        isSaving = true
        saveFailed = false

        let buyIn: Double
        let cashOut: Double
        let isManual: Bool
        switch entryMode {
        case .buyInOut:
            buyIn   = Double(buyInText) ?? 0
            cashOut = Double(cashOutText) ?? 0
            isManual = false
        case .netOnly:
            buyIn   = 0
            cashOut = 0
            isManual = true
        }

        // Preserve the existing entry's ID and metadata so the listener update
        // lands on the same document rather than creating a duplicate.
        let updated = SessionEntry(
            id: entry.id,
            sessionId: entry.sessionId,
            tableId: entry.tableId,
            playerId: entry.playerId,
            playerName: entry.playerName,
            buyIn: buyIn,
            finalAmount: cashOut,
            netAmount: net,
            submittedAt: entry.submittedAt,
            isManualNet: isManual
        )

        let success = await vm.updateEntry(updated)
        isSaving = false
        if success {
            withAnimation(.tabsSpring) { saved = true }
        } else {
            withAnimation { saveFailed = true }
        }
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
    // Keep the sign so +$5 and -$5 across sessions cancel out in the fund.
    private var disputeAmt: Double { totalNet }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar: drag handle + dismiss button
            HStack {
                // Dismiss button (top-left)
                DismissButton()

                Spacer()

                // Drag indicator (centred)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.tabsSecondary.opacity(0.3))
                    .frame(width: 36, height: 5)

                Spacer()

                // Invisible spacer to balance the dismiss button width
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, 16)
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
        // LoadingOverlay only shown while settling; it doesn't disable swipe
        // because interactiveDismissDisabled(false) is set on the sheet itself.
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
            .disabled(isSettling)
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
                Text("Imbalance: \(disputeAmt.signedCurrencyString)")
                    .font(.tabsMono(24))
                    .foregroundColor(disputeAmt >= 0 ? .tabsGreen : .tabsRed)
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
                    subtitle: "Add \(disputeAmt.signedCurrencyString) to the table's dispute fund",
                    icon: "archivebox",
                    value: .disputeFund
                )
                resolutionOption(
                    title: "Split Evenly",
                    subtitle: "\((disputeAmt / Double(max(entries.count, 1))).signedCurrencyString) applied to each player",
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
            .disabled(isSettling)
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
                        .foregroundColor(selectedResolution == value ? .tabsOnPrimary : .tabsSecondary)
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
    // @MainActor ensures all @State mutations happen on the main thread,
    // preventing the infinite-loading bug caused by off-thread state writes.

    @MainActor
    private func settle() async {
        guard !isSettling else { return }
        isSettling = true
        let dispAmount = isBalanced ? 0.0 : disputeAmt
        let success = await vm.settleSession(
            session: session,
            entries: entries,
            resolution: selectedResolution,
            disputeAmount: dispAmount
        )
        isSettling = false
        if success {
            withAnimation(.tabsFluid) { settled = true }
        }
        // On failure, vm.errorMessage is set; the LoadingOverlay dismisses
        // automatically and the user sees the error in the next redraw.
    }
}
