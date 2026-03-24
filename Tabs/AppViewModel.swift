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
        let sessionCount = (try? await service.fetchSessions(tableId: table.id).count) ?? 0
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
        guard let sessionId = selectedTable?.activeSessionId else { return nil }
        return try? await service.fetchSessions(tableId: tableId)
            .first(where: { $0.id == sessionId })
    }

    // MARK: - Entries & Settlement

    func startEntryListener(tableId: String, sessionId: String) {
        entryListener?.remove()
        entryListener = service.listenToEntries(tableId: tableId, sessionId: sessionId) { [weak self] entries in
            self?.sessionEntries = entries
        }
    }

    func submitEntry(_ entry: SessionEntry) async {
        do {
            try await service.submitEntry(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func settleSession(
        session: GameSession,
        entries: [SessionEntry],
        resolution: DisputeResolution,
        disputeAmount: Double
    ) async {
        do {
            for entry in entries {
                var finalNet = entry.netAmount
                if resolution == .splitEvenly && disputeAmount != 0 {
                    let perPlayer = disputeAmount / Double(entries.count)
                    finalNet -= perPlayer
                }
                if let player = players.first(where: { $0.id == entry.playerId }) {
                    try await service.updatePlayerEarnings(
                        playerId: player.id,
                        tableId: session.tableId,
                        delta: finalNet
                    )
                }
            }

            if resolution == .disputeFund && disputeAmount != 0 {
                try await service.updateDisputedAmount(disputeAmount, tableId: session.tableId)
            }

            let status: GameSession.SessionStatus = disputeAmount != 0 ? .disputed : .completed
            try await service.closeSession(
                sessionId: session.id,
                tableId: session.tableId,
                status: status,
                disputedAmount: resolution == .disputeFund ? disputeAmount : 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Player History

    func fetchPlayerHistory(playerId: String, tableId: String) async -> [SessionEntry] {
        return (try? await service.fetchAllEntries(tableId: tableId, playerId: playerId)) ?? []
    }

    // MARK: - Helpers

    func isAdmin(of table: PokerTable) -> Bool {
        currentUser?.id == table.adminId
    }

    func currentPlayer(for tableId: String) -> TablePlayer? {
        guard let userId = currentUser?.id else { return nil }
        return players.first(where: { $0.userId == userId && $0.tableId == tableId })
    }
}
