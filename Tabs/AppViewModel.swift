//
//  AppViewModel.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AppViewModel: ObservableObject{

    static let shared = AppViewModel()

    // MARK: - Auth State

    @Published var currentUser: AppUser? = nil
    @Published var isLoggedIn: Bool = false
    @Published var authError: String? = nil

    // MARK: - Home State

    @Published var tables: [PokerTable] = []
    @Published var isLoadingTables: Bool = false

    // MARK: - Table Detail State

    @Published var selectedTable: PokerTable? = nil
    @Published var players: [TablePlayer] = []

    // MARK: - Session State

    @Published var sessionEntries: [SessionEntry] = []

    // MARK: - Appearance

    @Published var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "tabs_dark_mode") {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "tabs_dark_mode") }
    }

    // MARK: - General Error

    @Published var errorMessage: String? = nil

    private var tableListener: ListenerRegistration?
    private var playerListener: ListenerRegistration?
    private var entryListener: ListenerRegistration?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private let service = FirebaseService.shared

    init() {
        listenToAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task { @MainActor in
                if let firebaseUser {
                    await self.handleSignedInUser(firebaseUser)
                } else {
                    self.currentUser = nil
                    self.isLoggedIn = false
                    self.tables = []
                    self.stopListeners()
                }
            }
        }
    }

    private func handleSignedInUser(_ firebaseUser: FirebaseAuth.User) async {
        // Fetch stored profile from Firestore; fall back to Firebase Auth data
        let storedUser = try? await service.fetchUser(id: firebaseUser.uid)
        let appUser = storedUser ?? AppUser(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? "Player",
            email: firebaseUser.email ?? ""
        )
        currentUser = appUser
        isLoggedIn = true
        await loadTables()
    }

    // MARK: - Sign In with Apple

    func signInWithApple(credential: OAuthCredential, fullName: PersonNameComponents?) async {
        do {
            let result = try await Auth.auth().signIn(with: credential)
            let firebaseUser = result.user

            // Apple only sends the name on the very first sign-in — persist it immediately
            if result.additionalUserInfo?.isNewUser == true, let name = fullName {
                let displayName = [name.givenName, name.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)

                let changeRequest = firebaseUser.createProfileChangeRequest()
                changeRequest.displayName = displayName.isEmpty ? "Player" : displayName
                try? await changeRequest.commitChanges()

                let appUser = AppUser(
                    id: firebaseUser.uid,
                    name: changeRequest.displayName ?? "Player",
                    email: firebaseUser.email ?? ""
                )
                try await service.saveUser(appUser)
            }
            // Auth state listener will fire and call handleSignedInUser
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Sign In with Google

    func signInWithGoogle(credential: AuthCredential, name: String, email: String) async {
        do {
            let result = try await Auth.auth().signIn(with: credential)
            let firebaseUser = result.user

            if result.additionalUserInfo?.isNewUser == true {
                let appUser = AppUser(id: firebaseUser.uid, name: name, email: email)
                try await service.saveUser(appUser)
            }
            // Auth state listener fires automatically
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            // Auth state listener sets isLoggedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Tables

    func loadTables() async {
        guard let userId = currentUser?.id else { return }
        isLoadingTables = true
        do {
            tables = try await service.fetchTables(for: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingTables = false
    }

    func createTable(name: String) async -> PokerTable? {
        guard let user = currentUser else { return nil }
        let table = PokerTable(name: name, adminId: user.id, memberIds: [user.id])
        do {
            try await service.createTable(table)
            let player = TablePlayer(userId: user.id, name: user.name, tableId: table.id)
            try await service.addPlayer(player)
            tables.append(table)
            return table
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func joinTable(code: String) async -> PokerTable? {
        guard let user = currentUser else { return nil }
        do {
            guard var table = try await service.fetchTableByCode(code) else {
                errorMessage = "No table found with that code."
                return nil
            }
            guard !table.memberIds.contains(user.id) else {
                errorMessage = "You are already in this table."
                return nil
            }
            try await service.addMember(userId: user.id, to: table.id)
            table.memberIds.append(user.id)
            let player = TablePlayer(userId: user.id, name: user.name, tableId: table.id)
            try await service.addPlayer(player)
            if !tables.contains(where: { $0.id == table.id }) {
                tables.append(table)
            }
            return table
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Table Detail

    func selectTable(_ table: PokerTable) {
        stopListeners()
        selectedTable = table
        startTableListener(tableId: table.id)
        startPlayerListener(tableId: table.id)
    }

    private func startTableListener(tableId: String) {
        tableListener = service.listenToTable(tableId: tableId) { [weak self] updatedTable in
            guard let self, let updatedTable else { return }
            self.selectedTable = updatedTable
            if let idx = self.tables.firstIndex(where: { $0.id == tableId }) {
                self.tables[idx] = updatedTable
            }
        }
    }

    private func startPlayerListener(tableId: String) {
        playerListener = service.listenToPlayers(tableId: tableId) { [weak self] updatedPlayers in
            self?.players = updatedPlayers.sorted { $0.totalEarnings > $1.totalEarnings }
        }
    }

    func stopListeners() {
        tableListener?.remove()
        playerListener?.remove()
        entryListener?.remove()
        tableListener = nil
        playerListener = nil
        entryListener = nil
    }

    // MARK: - Sessions

    func startSession(for table: PokerTable) async {
        let sessionCount = (try? await service.countSessions(tableId: table.id)) ?? 0
        let session = GameSession(
            tableId: table.id,
            status: .active,
            sessionNumber: sessionCount + 1
        )
        do {
            try await service.createSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchActiveSession(tableId: String) async -> GameSession? {
        // Always fetch the table fresh from Firestore so we never read stale
        // selectedTable state.  This is critical: when an admin just started
        // a new session, selectedTable.activeSessionId hasn't been updated yet
        // (the listener fires async), so relying on it produces nil → no session
        // card, no entry listener, and a silently-broken flow.
        let freshTable = (try? await service.fetchTable(id: tableId))

        // Sync local copies so the rest of the UI reflects the fresh data
        if let freshTable {
            selectedTable = freshTable
            if let idx = tables.firstIndex(where: { $0.id == tableId }) {
                tables[idx] = freshTable
            }
        }

        guard let sessionId = (freshTable ?? selectedTable)?.activeSessionId else { return nil }
        // Fetch the session document directly — avoids loading every session.
        return try? await service.fetchSession(sessionId: sessionId, tableId: tableId)
    }

    // MARK: - Entries & Settlement

    func startEntryListener(tableId: String, sessionId: String) {
        entryListener?.remove()
        entryListener = service.listenToEntries(tableId: tableId, sessionId: sessionId) { [weak self] entries in
            Task { @MainActor [weak self] in
                withAnimation(.tabsSpring) {
                    self?.sessionEntries = entries
                }
            }
        }
    }

    func clearEntryListener() {
        entryListener?.remove()
        entryListener = nil
        sessionEntries = []
    }

    /// Writes the entry to Firestore.  Returns true on success; on failure
    /// sets errorMessage and returns false so callers can show an error state.
    @discardableResult
    func submitEntry(_ entry: SessionEntry) async -> Bool {
        do {
            try await service.submitEntry(entry)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Overwrites an existing entry document.  Admins use this to correct any
    /// player's submitted result during an active session.
    @discardableResult
    func updateEntry(_ entry: SessionEntry) async -> Bool {
        do {
            try await service.submitEntry(entry)   // setData(from:) replaces the doc
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Settles a session. Returns true on success, false (with errorMessage set) on failure.
    @discardableResult
    func settleSession(
        session: GameSession,
        entries: [SessionEntry],
        resolution: DisputeResolution,
        disputeAmount: Double
    ) async -> Bool {
        do {
            let loggedToFund = resolution == .disputeFund && disputeAmount != 0
            let status: GameSession.SessionStatus = loggedToFund ? .disputed : .completed

            // Build per-player earning deltas (split-evenly deducts equal share)
            let splitPerPlayer = (resolution == .splitEvenly && disputeAmount != 0)
                ? disputeAmount / Double(entries.count)
                : 0
            let earningDeltas: [(playerId: String, delta: Double)] = entries.map { entry in
                (entry.playerId, entry.netAmount - splitPerPlayer)
            }

            // One atomic batch: all player earnings + session close + table update
            try await service.settleSessionBatch(
                sessionId:             session.id,
                tableId:               session.tableId,
                status:                status,
                sessionDisputedAmount: loggedToFund ? disputeAmount : 0,
                earningDeltas:         earningDeltas,
                tableDisputeDelta:     loggedToFund ? disputeAmount : 0
            )

            // Force-refresh players so totalEarnings is up-to-date in the UI
            // immediately — the real-time listener may lag by a few hundred ms.
            let fresh = try await service.fetchPlayers(tableId: session.tableId)
            players = fresh.sorted { $0.totalEarnings > $1.totalEarnings }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Admin: Delete Table

    func deleteTable(_ table: PokerTable) async {
        do {
            try await service.deleteTable(tableId: table.id)
            tables.removeAll { $0.id == table.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Admin: Reset Session

    func resetSession(_ session: GameSession) async {
        do {
            try await service.resetSession(sessionId: session.id, tableId: session.tableId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Player History

    func fetchPlayerHistory(playerId: String, tableId: String) async -> [SessionEntry] {
        return (try? await service.fetchAllEntries(tableId: tableId, playerId: playerId)) ?? []
    }

    // MARK: - Cross-table analytics

    /// Fetches this user's player record + session history for every table they're in.
    /// Uses a TaskGroup so all tables are fetched in parallel — much faster when the
    /// user has joined several tables.
    func fetchMyStatsAcrossAllTables() async -> [TableAnalyticsStat] {
        guard let userId = currentUser?.id else { return [] }
        let snapshot = tables          // capture once to avoid races
        return await withTaskGroup(of: TableAnalyticsStat?.self) { group in
            for table in snapshot {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    guard let player = try? await self.service.fetchMyPlayer(tableId: table.id, userId: userId)
                    else { return nil }
                    let entries = await self.fetchPlayerHistory(playerId: player.id, tableId: table.id)
                    return TableAnalyticsStat(table: table, player: player, entries: entries)
                }
            }
            var results: [TableAnalyticsStat] = []
            for await stat in group { if let s = stat { results.append(s) } }
            return results.sorted { $0.table.name < $1.table.name }
        }
    }

    // MARK: - Dispute Fund History

    func fetchDisputedSessions(tableId: String) async -> [GameSession] {
        return (try? await service.fetchDisputedSessions(tableId: tableId)) ?? []
    }

    // MARK: - Helpers

    func isAdmin(of table: PokerTable) -> Bool {
        guard let userId = currentUser?.id else { return false }
        return table.isAdmin(userId)
    }

    // MARK: - Co-Admin Management

    func promoteToCoAdmin(userId: String, table: PokerTable) async {
        var updated = table.coAdminIds
        guard !updated.contains(userId) else { return }
        updated.append(userId)
        do {
            try await service.updateCoAdmins(tableId: table.id, coAdminIds: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func demoteCoAdmin(userId: String, table: PokerTable) async {
        let updated = table.coAdminIds.filter { $0 != userId }
        do {
            try await service.updateCoAdmins(tableId: table.id, coAdminIds: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Table Settlement

    func startTableSettlement(table: PokerTable) async {
        do { try await service.startTableSettlement(tableId: table.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func cancelTableSettlement(table: PokerTable) async {
        do { try await service.cancelTableSettlement(tableId: table.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func setPlayerSettled(playerId: String, table: PokerTable, isSettled: Bool) async {
        do { try await service.setPlayerSettled(playerId: playerId, tableId: table.id, isSettled: isSettled) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Closes the settlement: commits lifetimeEarnings accumulation + zero reset
    /// for every player in a single Firestore batch, then refreshes local state.
    @discardableResult
    func closeTableSettlement(table: PokerTable) async -> Bool {
        do {
            try await service.closeTableSettlement(tableId: table.id, players: players)
            let fresh = try await service.fetchPlayers(tableId: table.id)
            self.players = fresh.sorted { $0.totalEarnings > $1.totalEarnings }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Dispute Fund Settlement

    /// Splits the entire dispute fund evenly across all players, then resets it to 0.
    func settleDisputeSplit(table: PokerTable) async -> Bool {
        guard !players.isEmpty else { return false }
        let share = table.disputedAmount / Double(players.count)
        do {
            // Single batch commit instead of N sequential round trips
            try await service.batchUpdatePlayerEarnings(
                players.map { ($0.id, share) },
                tableId: table.id
            )
            try await service.setDisputedAmount(0, tableId: table.id)
            let fresh = try await service.fetchPlayers(tableId: table.id)
            self.players = fresh.sorted { $0.totalEarnings > $1.totalEarnings }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Resets the dispute fund to zero without adjusting any player earnings.
    func resetDisputeFund(tableId: String) async -> Bool {
        do {
            try await service.setDisputedAmount(0, tableId: tableId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func currentPlayer(for tableId: String) -> TablePlayer? {
        guard let userId = currentUser?.id else { return nil }
        return players.first(where: { $0.userId == userId && $0.tableId == tableId })
    }
}
