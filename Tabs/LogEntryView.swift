//
//  LogEntryView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import SwiftUI

struct LogEntryView: View {
    let table: PokerTable
    let session: GameSession   // passed directly — never reads table.activeSessionId
    let player: TablePlayer

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var entryMode: EntryMode = .buyInOut
    @State private var buyInText: String = ""
    @State private var finalAmountText: String = ""
    @State private var netText: String = ""
    @State private var isLoading = false
    @State private var submitted = false
    @State private var submitFailed = false
    @State private var showOverrideConfirm = false

    enum EntryMode: String, CaseIterable {
        case buyInOut = "Buy-in / Final"
        case netOnly  = "Net Amount"
    }

    /// The player's existing entry for this session, if any.
    /// Derived from the real-time listener — always current.
    private var existingEntry: SessionEntry? {
        vm.sessionEntries.first(where: { $0.playerId == player.id })
    }

    private var netAmount: Double? {
        switch entryMode {
        case .buyInOut:
            guard let buy = Double(buyInText), let final_ = Double(finalAmountText) else { return nil }
            return final_ - buy
        case .netOnly:
            return Double(netText)
        }
    }

    private var canSubmit: Bool { netAmount != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Log Entry")
                        .font(.tabsTitle(28))
                        .foregroundColor(.tabsPrimary)
                    Text(player.name + " · " + table.name)
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                }
                Spacer()
                DismissButton()
            }
            .padding(.top, 4)

            if submitted {
                submittedState
            } else {
                entryForm
            }

            Spacer()
        }
        .padding(24)
        .background(Color.tabsBackground)
    }

    // MARK: - Entry Form

    private var entryForm: some View {
        VStack(spacing: 20) {
            // Existing-entry warning banner
            if let existing = existingEntry {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Entry already submitted")
                            .font(.tabsBody(13, weight: .semibold))
                            .foregroundColor(.tabsPrimary)
                        Text("Previous result: \(existing.netAmount.signedCurrencyString). Submitting again will override it.")
                            .font(.tabsBody(12))
                            .foregroundColor(.tabsSecondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.orange.opacity(0.10))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

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

            // Input fields
            if entryMode == .buyInOut {
                VStack(spacing: 12) {
                    CurrencyField(label: "Total Buy-in", text: $buyInText)
                    CurrencyField(label: "Final Amount (chips out)", text: $finalAmountText)

                    // Live net preview
                    if let net = netAmount {
                        HStack {
                            Text("Net result:")
                                .font(.tabsBody(14))
                                .foregroundColor(.tabsSecondary)
                            Spacer()
                            Text(net.signedCurrencyString)
                                .font(.tabsMono(18))
                                .foregroundColor(net.earningsColor)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(net >= 0
                            ? Color.tabsGreen.opacity(0.08)
                            : Color.tabsRed.opacity(0.08))
                        .cornerRadius(.tabsButtonRadius)
                        .animation(.tabsSnap, value: net)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    CurrencyField(
                        label: "Net amount (use - for a loss)",
                        text: $netText,
                        allowNegative: true
                    )
                    Text("Enter a positive number for a win (e.g. 120) or negative for a loss (e.g. -45)")
                        .font(.tabsBody(12))
                        .foregroundColor(.tabsSecondary)
                        .padding(.horizontal, 4)
                }
            }

            // Submit — routes through override confirmation when a prior entry exists
            Button {
                if existingEntry != nil {
                    showOverrideConfirm = true
                } else {
                    Task { await submitEntry() }
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(existingEntry != nil ? "Override Entry" : "Submit Entry")
                    }
                }
            }
            .buttonStyle(TabsPrimaryButtonStyle(color: existingEntry != nil ? .orange : .tabsGreen))
            .disabled(!canSubmit || isLoading)
            .opacity(canSubmit ? 1 : 0.45)
            .alert("Override Previous Entry?", isPresented: $showOverrideConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Override", role: .destructive) {
                    Task { await submitEntry() }
                }
            } message: {
                if let existing = existingEntry, let net = netAmount {
                    Text("Your previous result of \(existing.netAmount.signedCurrencyString) will be replaced with \(net.signedCurrencyString).")
                }
            }

            // Error banner — shown only when the Firestore write failed
            if submitFailed {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.tabsRed)
                    Text(vm.errorMessage ?? "Failed to submit. Please try again.")
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

    // MARK: - Submitted State

    private var submittedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.tabsGreen)

            Text("Entry Logged!")
                .font(.tabsTitle(26))
                .foregroundColor(.tabsPrimary)

            if let net = netAmount {
                VStack(spacing: 4) {
                    Text("Your result for this session:")
                        .font(.tabsBody(14))
                        .foregroundColor(.tabsSecondary)
                    Text(net.signedCurrencyString)
                        .font(.tabsMono(32))
                        .foregroundColor(net.earningsColor)
                }
            }

            Button("Done") { dismiss() }
                .buttonStyle(TabsPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Submit

    private func submitEntry() async {
        guard let net = netAmount else { return }
        isLoading = true
        submitFailed = false

        let buyIn: Double
        let finalAmount: Double
        let isManual: Bool

        switch entryMode {
        case .buyInOut:
            buyIn = Double(buyInText) ?? 0
            finalAmount = Double(finalAmountText) ?? 0
            isManual = false
        case .netOnly:
            buyIn = 0
            finalAmount = 0
            isManual = true
        }

        // Reuse the existing entry's document ID so Firestore's setData(from:)
        // overwrites that document rather than creating a duplicate.
        let entryId = existingEntry?.id ?? UUID().uuidString

        let entry = SessionEntry(
            id: entryId,
            sessionId: session.id,   // use session.id directly — never stale
            tableId: table.id,
            playerId: player.id,
            playerName: player.name,
            buyIn: buyIn,
            finalAmount: finalAmount,
            netAmount: net,
            isManualNet: isManual
        )

        // updateEntry and submitEntry both call service.submitEntry (setData),
        // but updateEntry signals intent clearly for future distinction.
        let success = existingEntry != nil
            ? await vm.updateEntry(entry)
            : await vm.submitEntry(entry)

        isLoading = false

        if success {
            withAnimation { submitted = true }
        } else {
            // vm.errorMessage is already set; surface a retry prompt
            withAnimation { submitFailed = true }
        }
    }
}
